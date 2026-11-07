//
//  ClientSession.m
//  TCP Client
//

#import "ClientSession.h"
#import "GCDAsyncSocket.h"

NSNotificationName const ClientSessionDidChangeNotification = @"ClientSessionDidChangeNotification";
NSNotificationName const ClientSessionDidUpdateLogNotification = @"ClientSessionDidUpdateLogNotification";

static const NSUInteger kMaxLogLength = 500000;
static const NSTimeInterval kConnectTimeout = 10;
static const NSTimeInterval kPartialLineFlushDelay = 0.25;

@interface ClientSession () <GCDAsyncSocketDelegate> {
    dispatch_queue_t _queue;
    GCDAsyncSocket *_socket;
    NSDateFormatter *_timeFormatter;
    NSMutableString *_pending;
    NSUInteger _pendingGeneration;
}
@property (nonatomic, readwrite) ClientConnectionState state;
@end

@implementation ClientSession

- (instancetype)initWithName:(NSString *)name host:(NSString *)host port:(uint16_t)port {
    self = [super init];
    if (self) {
        _name = [name copy];
        _host = [host copy];
        _port = port;
        _queue = dispatch_queue_create("com.voelkerb.TCPClient.session", DISPATCH_QUEUE_SERIAL);
        _log = [[NSTextStorage alloc] init];
        _pending = [[NSMutableString alloc] init];
        _timeFormatter = [[NSDateFormatter alloc] init];
        _timeFormatter.dateFormat = @"HH:mm:ss";
    }
    return self;
}

- (nullable instancetype)initWithDictionary:(NSDictionary *)dictionary {
    NSString *name = dictionary[@"name"];
    NSString *host = dictionary[@"host"];
    NSNumber *port = dictionary[@"port"];
    if (![name isKindOfClass:NSString.class] || ![host isKindOfClass:NSString.class] ||
        ![port isKindOfClass:NSNumber.class]) {
        return nil;
    }
    return [self initWithName:name host:host port:(uint16_t)port.unsignedIntegerValue];
}

- (NSDictionary *)dictionaryRepresentation {
    return @{ @"name": self.name, @"host": self.host, @"port": @(self.port) };
}

- (void)setName:(NSString *)name {
    _name = [name copy];
    [self postChange];
}

- (void)setHost:(NSString *)host {
    if ([_host isEqualToString:host]) return;
    _host = [host copy];
    [self postChange];
}

- (void)setPort:(uint16_t)port {
    if (_port == port) return;
    _port = port;
    [self postChange];
}

#pragma mark - Lifecycle

- (BOOL)connectWithError:(NSError **)error {
    if (self.state != ClientConnectionStateDisconnected) return YES;

    GCDAsyncSocket *socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:_queue];
    if (![socket connectToHost:self.host onPort:self.port withTimeout:kConnectTimeout error:error]) {
        [self appendLine:[NSString stringWithFormat:@"Could not connect to %@:%hu: %@", self.host, self.port,
                          (error && *error) ? (*error).localizedDescription : @"unknown error"]
                    kind:ClientLogKindError];
        return NO;
    }
    _socket = socket;
    _pending = [[NSMutableString alloc] init];
    self.state = ClientConnectionStateConnecting;
    [self appendLine:[NSString stringWithFormat:@"Connecting to %@:%hu…", self.host, self.port] kind:ClientLogKindInfo];
    [self postChange];
    return YES;
}

- (void)disconnect {
    if (self.state == ClientConnectionStateDisconnected) return;

    GCDAsyncSocket *socket = _socket;
    BOOL wasConnected = self.state == ClientConnectionStateConnected;
    _socket = nil;
    self.state = ClientConnectionStateDisconnected;
    [socket setDelegate:nil delegateQueue:NULL];
    [socket disconnect];

    [self flushPending];
    [self appendLine:(wasConnected ? @"Disconnected" : @"Connection attempt cancelled") kind:ClientLogKindInfo];
    [self postChange];
}

#pragma mark - Sending

- (BOOL)sendLine:(NSString *)line {
    GCDAsyncSocket *socket = _socket;
    if (self.state != ClientConnectionStateConnected || !socket) {
        [self appendLine:@"Not connected, message not sent" kind:ClientLogKindError];
        return NO;
    }
    NSData *data = [[line stringByAppendingString:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding];
    [socket writeData:data withTimeout:-1 tag:0];
    [self appendLine:line kind:ClientLogKindSent];
    return YES;
}

#pragma mark - Log

- (void)clearLog {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->_log replaceCharactersInRange:NSMakeRange(0, self->_log.length) withString:@""];
        [NSNotificationCenter.defaultCenter postNotificationName:ClientSessionDidUpdateLogNotification object:self];
    });
}

- (void)appendLine:(NSString *)text kind:(ClientLogKind)kind {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSFont *font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
        NSColor *color;
        switch (kind) {
            case ClientLogKindReceived: color = NSColor.labelColor; break;
            case ClientLogKindSent: color = NSColor.controlAccentColor; break;
            case ClientLogKindError: color = NSColor.systemRedColor; break;
            default: color = NSColor.secondaryLabelColor; break;
        }

        NSMutableAttributedString *line = [[NSMutableAttributedString alloc] init];
        NSString *stamp = [[self->_timeFormatter stringFromDate:NSDate.date] stringByAppendingString:@"  "];
        [line appendAttributedString:[[NSAttributedString alloc] initWithString:stamp attributes:@{
            NSFontAttributeName: font, NSForegroundColorAttributeName: NSColor.tertiaryLabelColor }]];
        [line appendAttributedString:[[NSAttributedString alloc] initWithString:[text stringByAppendingString:@"\n"] attributes:@{
            NSFontAttributeName: font, NSForegroundColorAttributeName: color }]];

        [self->_log beginEditing];
        [self->_log appendAttributedString:line];
        if (self->_log.length > kMaxLogLength) {
            NSUInteger cut = self->_log.length - (kMaxLogLength * 8 / 10);
            NSRange newline = [self->_log.string rangeOfString:@"\n" options:0
                                                         range:NSMakeRange(cut, self->_log.length - cut)];
            if (newline.location != NSNotFound) cut = NSMaxRange(newline);
            [self->_log deleteCharactersInRange:NSMakeRange(0, cut)];
        }
        [self->_log endEditing];
        [NSNotificationCenter.defaultCenter postNotificationName:ClientSessionDidUpdateLogNotification object:self];
    });
}

- (void)postChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:ClientSessionDidChangeNotification object:self];
    });
}

#pragma mark - Incoming text

// Called on the session queue or the main queue; guarded by hopping to the session queue.
- (void)flushPending {
    dispatch_async(_queue, ^{
        if (self->_pending.length == 0) return;
        NSString *rest = [self->_pending copy];
        [self->_pending setString:@""];
        [self appendLine:rest kind:ClientLogKindReceived];
    });
}

- (void)consumeText:(NSString *)text {
    [_pending appendString:text];
    NSArray<NSString *> *parts = [_pending componentsSeparatedByString:@"\n"];
    for (NSUInteger i = 0; i + 1 < parts.count; i++) {
        NSString *line = [parts[i] stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
        [self appendLine:line kind:ClientLogKindReceived];
    }
    [_pending setString:parts.lastObject];

    // Text without a trailing newline is shown after a short pause.
    if (_pending.length > 0) {
        NSUInteger generation = ++_pendingGeneration;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPartialLineFlushDelay * NSEC_PER_SEC)), _queue, ^{
            if (generation != self->_pendingGeneration || self->_pending.length == 0) return;
            NSString *rest = [self->_pending stringByTrimmingCharactersInSet:NSCharacterSet.newlineCharacterSet];
            [self->_pending setString:@""];
            if (rest.length > 0) [self appendLine:rest kind:ClientLogKindReceived];
        });
    }
}

#pragma mark - GCDAsyncSocketDelegate (serial queue)

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port {
    if (sock != _socket) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_socket == sock) self.state = ClientConnectionStateConnected;
    });
    [self appendLine:[NSString stringWithFormat:@"Connected to %@:%hu", host, port] kind:ClientLogKindInfo];
    [self postChange];
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    if (sock != _socket) return;
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!text) {
        text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    }
    [self consumeText:text ?: @""];
    [sock readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_socket != sock) return;
        BOOL wasConnected = self.state == ClientConnectionStateConnected;
        self->_socket = nil;
        self.state = ClientConnectionStateDisconnected;
        [self flushPending];
        if (err) {
            [self appendLine:[NSString stringWithFormat:@"%@: %@",
                              wasConnected ? @"Connection lost" : @"Connection failed", err.localizedDescription]
                        kind:ClientLogKindError];
        } else {
            [self appendLine:@"Disconnected by server" kind:ClientLogKindInfo];
        }
        [self postChange];
    });
}

@end
