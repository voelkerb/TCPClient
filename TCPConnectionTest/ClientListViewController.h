//
//  ClientListViewController.h
//  TCPClient
//

#import <Cocoa/Cocoa.h>
#import "ClientSession.h"

NS_ASSUME_NONNULL_BEGIN

@class ClientListViewController;

@protocol ClientListViewControllerDelegate <NSObject>
- (void)clientList:(ClientListViewController *)list didSelectSession:(nullable ClientSession *)session;
@end

@interface ClientListViewController : NSViewController

@property (nonatomic, weak, nullable) id<ClientListViewControllerDelegate> delegate;
@property (nonatomic, readonly, nullable) ClientSession *selectedSession;
@property (nonatomic, readonly) NSArray<ClientSession *> *sessions;

- (void)addClient;
- (void)removeSelectedClient;
- (void)disconnectAll;

@end

NS_ASSUME_NONNULL_END
