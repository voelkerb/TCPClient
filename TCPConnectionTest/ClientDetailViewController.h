//
//  ClientDetailViewController.h
//  TCPClient
//

#import <Cocoa/Cocoa.h>
#import "ClientSession.h"

NS_ASSUME_NONNULL_BEGIN

@interface ClientDetailViewController : NSViewController

// Pass nil to show the empty state.
@property (nonatomic, strong, nullable) ClientSession *session;

@end

NS_ASSUME_NONNULL_END
