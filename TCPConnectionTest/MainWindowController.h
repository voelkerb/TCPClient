//
//  MainWindowController.h
//  TCPClient
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MainWindowController : NSWindowController

- (void)addClient;
- (void)disconnectAll;

@end

NS_ASSUME_NONNULL_END
