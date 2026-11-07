//
//  ClientSession.h
//  TCP Client
//
//  One outgoing TCP connection with its activity log.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// Posted on the main thread when name, host, port or connection state changes.
extern NSNotificationName const ClientSessionDidChangeNotification;
// Posted on the main thread after a line is appended to or cleared from the log.
extern NSNotificationName const ClientSessionDidUpdateLogNotification;

typedef NS_ENUM(NSInteger, ClientLogKind) {
    ClientLogKindInfo,
    ClientLogKindReceived,
    ClientLogKindSent,
    ClientLogKindError,
};

typedef NS_ENUM(NSInteger, ClientConnectionState) {
    ClientConnectionStateDisconnected,
    ClientConnectionStateConnecting,
    ClientConnectionStateConnected,
};

@interface ClientSession : NSObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *host;
@property (nonatomic) uint16_t port;
@property (nonatomic, readonly) ClientConnectionState state;
// Main-thread only. Safe to attach to a layout manager.
@property (nonatomic, readonly) NSTextStorage *log;

- (instancetype)initWithName:(NSString *)name host:(NSString *)host port:(uint16_t)port NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;

// Asynchronous; progress and failures are reported through the log and change notification.
- (BOOL)connectWithError:(NSError **)error;
- (void)disconnect;
// Returns NO if not connected.
- (BOOL)sendLine:(NSString *)line;
- (void)clearLog;

@end

NS_ASSUME_NONNULL_END
