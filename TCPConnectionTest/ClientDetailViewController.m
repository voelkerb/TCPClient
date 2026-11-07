//
//  ClientDetailViewController.m
//  TCPClient
//

#import "ClientDetailViewController.h"

// One spacing scale for the whole pane keeps button padding consistent.
static const CGFloat kOuterMargin = 16;
static const CGFloat kCardSpacing = 12;
static const CGFloat kCardInset = 16;
static const CGFloat kItemSpacing = 12;
static const CGFloat kCardRadius = 22;

static NSView *MakeCard(NSView *content) {
    content.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(macOS 26.0, *)) {
        NSGlassEffectView *glass = [[NSGlassEffectView alloc] init];
        glass.cornerRadius = kCardRadius;
        glass.contentView = content;
        glass.translatesAutoresizingMaskIntoConstraints = NO;
        return glass;
    }
    NSVisualEffectView *effect = [[NSVisualEffectView alloc] init];
    effect.material = NSVisualEffectMaterialContentBackground;
    effect.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    effect.state = NSVisualEffectStateActive;
    effect.wantsLayer = YES;
    effect.layer.cornerRadius = kCardRadius;
    effect.layer.masksToBounds = YES;
    effect.translatesAutoresizingMaskIntoConstraints = NO;
    [effect addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:effect.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:effect.trailingAnchor],
        [content.topAnchor constraintEqualToAnchor:effect.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:effect.bottomAnchor],
    ]];
    return effect;
}

// Wraps a stack in a padded container so every card uses the same insets.
static NSView *PaddedContainer(NSView *stack) {
    NSView *container = [[NSView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:kCardInset],
        [stack.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-kCardInset],
        [stack.topAnchor constraintEqualToAnchor:container.topAnchor constant:kCardInset],
        [stack.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-kCardInset],
    ]];
    return container;
}

static NSButton *MakeButton(NSString *title, NSString *symbol, id target, SEL action) {
    NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
    if (symbol) {
        button.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title];
        button.imagePosition = NSImageLeading;
    }
    button.controlSize = NSControlSizeLarge;
    if (@available(macOS 26.0, *)) {
        button.bezelStyle = NSBezelStyleGlass;
    } else {
        button.bezelStyle = NSBezelStyleRounded;
    }
    [button setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    [button setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    return button;
}

static NSStackView *MakeRow(NSArray<NSView *> *views) {
    NSStackView *row = [NSStackView stackViewWithViews:views];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = kItemSpacing;
    return row;
}

@interface ClientDetailViewController () <NSTextFieldDelegate> {
    NSStackView *_content;
    NSTextField *_emptyLabel;

    NSTextField *_nameField;
    NSImageView *_statusDot;
    NSTextField *_statusLabel;
    NSTextField *_hostField;
    NSTextField *_portField;
    NSButton *_toggleButton;

    NSSwitch *_followSwitch;
    NSButton *_clearButton;
    NSScrollView *_scrollView;
    NSTextView *_textView;
    NSTextStorage *_emptyStorage;

    NSTextField *_messageField;
    NSButton *_sendButton;
}
@end

@implementation ClientDetailViewController

- (void)loadView {
    self.view = [[NSView alloc] init];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    NSView *header = [self buildHeaderCard];
    NSView *activity = [self buildActivityCard];
    NSView *composer = [self buildComposerCard];

    _content = [NSStackView stackViewWithViews:@[header, activity, composer]];
    _content.orientation = NSUserInterfaceLayoutOrientationVertical;
    _content.alignment = NSLayoutAttributeWidth;
    _content.spacing = kCardSpacing;
    _content.translatesAutoresizingMaskIntoConstraints = NO;
    // Activity absorbs all extra height so top and bottom margins stay equal.
    _content.distribution = NSStackViewDistributionFill;
    [header setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
    [composer setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationVertical];
    [activity setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
    [self.view addSubview:_content];
    for (NSView *card in @[header, activity, composer]) {
        [card.leadingAnchor constraintEqualToAnchor:_content.leadingAnchor].active = YES;
        [card.trailingAnchor constraintEqualToAnchor:_content.trailingAnchor].active = YES;
    }

    _emptyLabel = [NSTextField labelWithString:@"No client selected\nAdd one with the + button."];
    _emptyLabel.alignment = NSTextAlignmentCenter;
    _emptyLabel.font = [NSFont systemFontOfSize:15];
    _emptyLabel.textColor = NSColor.secondaryLabelColor;
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _emptyLabel.hidden = YES;
    [self.view addSubview:_emptyLabel];

    NSLayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_content.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kOuterMargin],
        [_content.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kOuterMargin],
        [_content.topAnchor constraintEqualToAnchor:safe.topAnchor constant:kOuterMargin],
        [_content.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-kOuterMargin],
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(sessionDidChange:)
                                               name:ClientSessionDidChangeNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(logDidUpdate:)
                                               name:ClientSessionDidUpdateLogNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(userDidScroll:)
                                               name:NSScrollViewDidLiveScrollNotification object:_scrollView];
    [self refresh];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - Building

- (NSView *)buildHeaderCard {
    _nameField = [NSTextField textFieldWithString:@""];
    _nameField.font = [NSFont systemFontOfSize:17 weight:NSFontWeightSemibold];
    _nameField.bezelStyle = NSTextFieldRoundedBezel;
    _nameField.controlSize = NSControlSizeLarge;
    _nameField.editable = YES;
    _nameField.placeholderString = @"Client name";
    [_nameField.widthAnchor constraintGreaterThanOrEqualToConstant:140].active = YES;
    [_nameField.widthAnchor constraintLessThanOrEqualToConstant:260].active = YES;
    _nameField.lineBreakMode = NSLineBreakByTruncatingTail;
    _nameField.delegate = self;
    [_nameField setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    _statusDot = [[NSImageView alloc] init];
    _statusDot.image = [NSImage imageWithSystemSymbolName:@"circle.fill" accessibilityDescription:nil];
    _statusDot.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:8 weight:NSFontWeightRegular];
    _statusLabel = [NSTextField labelWithString:@""];
    _statusLabel.textColor = NSColor.secondaryLabelColor;
    NSStackView *status = MakeRow(@[_statusDot, _statusLabel]);
    status.spacing = 6;

    _statusLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [_statusLabel setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSTextField *hostCaption = [NSTextField labelWithString:@"Host"];
    hostCaption.textColor = NSColor.secondaryLabelColor;
    [hostCaption setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

    _hostField = [NSTextField textFieldWithString:@""];
    _hostField.bezelStyle = NSTextFieldRoundedBezel;
    _hostField.controlSize = NSControlSizeLarge;
    _hostField.placeholderString = @"127.0.0.1";
    _hostField.delegate = self;
    _hostField.target = self;
    _hostField.action = @selector(toggleClient:);
    [_hostField.widthAnchor constraintGreaterThanOrEqualToConstant:120].active = YES;
    [_hostField.widthAnchor constraintLessThanOrEqualToConstant:220].active = YES;
    [_hostField setContentCompressionResistancePriority:NSLayoutPriorityDefaultHigh forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSTextField *portCaption = [NSTextField labelWithString:@"Port"];
    portCaption.textColor = NSColor.secondaryLabelColor;
    [portCaption setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterNoStyle;
    formatter.usesGroupingSeparator = NO;
    formatter.allowsFloats = NO;
    formatter.minimum = @1;
    formatter.maximum = @65535;
    _portField = [NSTextField textFieldWithString:@""];
    _portField.formatter = formatter;
    _portField.bezelStyle = NSTextFieldRoundedBezel;
    _portField.controlSize = NSControlSizeLarge;
    _portField.alignment = NSTextAlignmentCenter;
    _portField.placeholderString = @"54321";
    _portField.delegate = self;
    _portField.target = self;
    _portField.action = @selector(toggleClient:);
    [_portField.widthAnchor constraintEqualToConstant:88].active = YES;
    [_portField setContentCompressionResistancePriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];

    _toggleButton = MakeButton(@"Connect", @"bolt.fill", self, @selector(toggleClient:));
    [_toggleButton.widthAnchor constraintGreaterThanOrEqualToConstant:120].active = YES;

    NSView *spacer = [[NSView alloc] init];
    [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    [spacer setContentCompressionResistancePriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *row = MakeRow(@[_nameField, status, spacer, hostCaption, _hostField, portCaption, _portField, _toggleButton]);
    return MakeCard(PaddedContainer(row));
}

- (NSView *)buildActivityCard {
    NSTextField *title = [NSTextField labelWithString:@"Activity"];
    title.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];

    NSTextField *followCaption = [NSTextField labelWithString:@"Auto-scroll"];
    followCaption.textColor = NSColor.secondaryLabelColor;
    _followSwitch = [[NSSwitch alloc] init];
    _followSwitch.state = NSControlStateValueOn;
    _followSwitch.target = self;
    _followSwitch.action = @selector(followChanged:);

    _clearButton = MakeButton(@"Clear", @"trash", self, @selector(clearLog:));

    NSView *spacer = [[NSView alloc] init];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSStackView *toolbar = MakeRow(@[title, spacer, followCaption, _followSwitch, _clearButton]);

    // TextKit 1 stack so each session's storage can be swapped in without copying.
    _emptyStorage = [[NSTextStorage alloc] init];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [_emptyStorage addLayoutManager:layoutManager];
    NSTextContainer *container = [[NSTextContainer alloc] initWithSize:NSMakeSize(400, CGFLOAT_MAX)];
    container.widthTracksTextView = YES;
    [layoutManager addTextContainer:container];

    _textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200) textContainer:container];
    _textView.editable = NO;
    _textView.selectable = YES;
    _textView.drawsBackground = NO;
    _textView.textContainerInset = NSMakeSize(10, 10);
    _textView.minSize = NSMakeSize(0, 0);
    _textView.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    _textView.verticallyResizable = YES;
    _textView.horizontallyResizable = NO;
    _textView.autoresizingMask = NSViewWidthSizable;
    _textView.usesFindBar = YES;

    _scrollView = [[NSScrollView alloc] init];
    _scrollView.documentView = _textView;
    _scrollView.hasVerticalScroller = YES;
    _scrollView.drawsBackground = NO;
    _scrollView.borderType = NSNoBorder;

    // Inner well keeps log text readable on top of glass.
    NSBox *well = [[NSBox alloc] init];
    well.boxType = NSBoxCustom;
    well.titlePosition = NSNoTitle;
    well.borderWidth = 0;
    well.cornerRadius = 12;
    well.fillColor = [NSColor.textBackgroundColor colorWithAlphaComponent:0.45];
    well.contentViewMargins = NSZeroSize;
    well.contentView = _scrollView;
    [well setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationVertical];
    [well.heightAnchor constraintGreaterThanOrEqualToConstant:160].active = YES;

    NSStackView *column = [NSStackView stackViewWithViews:@[toolbar, well]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeWidth;
    column.spacing = kItemSpacing;
    return MakeCard(PaddedContainer(column));
}

- (NSView *)buildComposerCard {
    _messageField = [NSTextField textFieldWithString:@""];
    _messageField.bezelStyle = NSTextFieldRoundedBezel;
    _messageField.controlSize = NSControlSizeLarge;
    _messageField.placeholderString = @"Message to send";
    _messageField.target = self;
    _messageField.action = @selector(sendMessage:);
    [_messageField setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    _sendButton = MakeButton(@"Send", @"paperplane.fill", self, @selector(sendMessage:));
    [_sendButton.widthAnchor constraintGreaterThanOrEqualToConstant:104].active = YES;

    NSStackView *row = MakeRow(@[_messageField, _sendButton]);
    return MakeCard(PaddedContainer(row));
}

#pragma mark - State

- (void)setSession:(ClientSession *)session {
    _session = session;
    if (!self.isViewLoaded) return;
    [self refresh];
    [self attachLog];
}

- (void)refresh {
    ClientSession *session = _session;
    _content.hidden = session == nil;
    _emptyLabel.hidden = session != nil;
    if (!session) return;

    ClientConnectionState state = session.state;
    BOOL idle = state == ClientConnectionStateDisconnected;
    BOOL connected = state == ClientConnectionStateConnected;
    if (![_nameField.currentEditor isKindOfClass:NSText.class]) {
        _nameField.stringValue = session.name;
    }
    if (!_hostField.currentEditor) {
        _hostField.stringValue = session.host;
    }
    if (!_portField.currentEditor) {
        _portField.integerValue = session.port;
    }
    _hostField.enabled = idle;
    _portField.enabled = idle;

    _statusDot.contentTintColor = connected ? NSColor.systemGreenColor
        : (state == ClientConnectionStateConnecting ? NSColor.systemOrangeColor : NSColor.tertiaryLabelColor);
    _statusLabel.stringValue = connected ? @"Connected" : (idle ? @"Disconnected" : @"Connecting…");

    _toggleButton.title = idle ? @"Connect" : @"Disconnect";
    _toggleButton.image = [NSImage imageWithSystemSymbolName:(idle ? @"bolt.fill" : @"bolt.slash.fill") accessibilityDescription:nil];
    _toggleButton.bezelColor = idle ? NSColor.controlAccentColor : NSColor.systemRedColor;

    _messageField.enabled = connected;
    _sendButton.enabled = connected;
    _sendButton.bezelColor = connected ? NSColor.controlAccentColor : nil;
}

- (void)attachLog {
    NSTextStorage *storage = _session ? _session.log : _emptyStorage;
    if (_textView.layoutManager.textStorage != storage) {
        [_textView.layoutManager replaceTextStorage:storage];
    }
    if (_followSwitch.state == NSControlStateValueOn) [self scrollToBottom];
}

- (void)scrollToBottom {
    [_textView scrollRangeToVisible:NSMakeRange(_textView.string.length, 0)];
}

#pragma mark - Notifications

- (void)sessionDidChange:(NSNotification *)note {
    if (note.object == _session) [self refresh];
}

- (void)logDidUpdate:(NSNotification *)note {
    if (note.object == _session && _followSwitch.state == NSControlStateValueOn) {
        [self scrollToBottom];
    }
}

// Scrolling up pauses auto-scroll; returning to the bottom resumes it.
- (void)userDidScroll:(NSNotification *)note {
    CGFloat visibleMax = NSMaxY(_scrollView.contentView.bounds);
    BOOL atBottom = visibleMax >= NSHeight(_textView.frame) - 8;
    _followSwitch.state = atBottom ? NSControlStateValueOn : NSControlStateValueOff;
}

#pragma mark - Actions

- (void)followChanged:(id)sender {
    if (_followSwitch.state == NSControlStateValueOn) [self scrollToBottom];
}

- (void)clearLog:(id)sender {
    [_session clearLog];
}

- (void)toggleClient:(id)sender {
    ClientSession *session = _session;
    if (!session) return;
    if (session.state != ClientConnectionStateDisconnected) {
        [session disconnect];
        return;
    }

    NSString *host = [_hostField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (host.length == 0) {
        [self presentAlert:@"Invalid Host" text:@"Enter a host name or IP address."];
        return;
    }
    NSInteger port = _portField.integerValue;
    if (_portField.stringValue.length == 0 || port < 1 || port > 65535) {
        [self presentAlert:@"Invalid Port" text:@"Enter a port number between 1 and 65535."];
        return;
    }
    session.host = host;
    session.port = (uint16_t)port;

    NSError *error = nil;
    if (![session connectWithError:&error]) {
        [self presentAlert:@"Unable to Connect" text:error.localizedDescription ?: @"Unknown error."];
    }
}

- (void)sendMessage:(id)sender {
    NSString *text = _messageField.stringValue;
    if (_session.state != ClientConnectionStateConnected || text.length == 0) return;
    if ([_session sendLine:text]) {
        _messageField.stringValue = @"";
    }
    [self.view.window makeFirstResponder:_messageField];
}

- (void)presentAlert:(NSString *)title text:(NSString *)text {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = title;
    alert.informativeText = text;
    [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    ClientSession *session = _session;
    if (!session) return;

    if (obj.object == _nameField) {
        NSString *name = [_nameField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (name.length > 0) session.name = name;
        _nameField.stringValue = session.name;
    } else if (obj.object == _hostField && session.state == ClientConnectionStateDisconnected) {
        NSString *host = [_hostField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if (host.length > 0) session.host = host;
        _hostField.stringValue = session.host;
    } else if (obj.object == _portField && session.state == ClientConnectionStateDisconnected) {
        NSInteger port = _portField.integerValue;
        if (port >= 1 && port <= 65535) session.port = (uint16_t)port;
        _portField.integerValue = session.port;
    }
}

@end
