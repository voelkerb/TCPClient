
#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"

extern NSString * const NetworkReceivedMsg;
extern NSString * const NetworkReceivedMsgError;
extern NSString * const NetworkConnected;
extern NSString * const NetworkDisconnected;

@class NetworkController;
@protocol NetworkControllerDelegate <NSObject>   //define delegate protocol
  - (void) receivedMsg: (NetworkController *) sender : (NSString *) msg;  //define delegate method to be implemented within another class
  - (void) receivedMsgError:(NetworkController *)sender;  //define delegate method to be implemented within another re
  - (void) connected: (NetworkController *) sender;  //define delegate method to be implemented within another class
  - (void) disconnected: (NetworkController *) sender;  //define delegate method to be implemented within another class
@end //end protocol

@interface NetworkController : NSObject<GCDAsyncSocketDelegate> {
  GCDAsyncSocket *socket;
  BOOL connected;
  NSString *host;
  int port;
}

@property NSString *host;
@property int port;
@property BOOL connected;

@property (assign) id <NetworkControllerDelegate> delegate;


// Methods
- (BOOL)connect:(NSString *)theHost :(int)thePort;
- (void)disconnect;
- (void)sendMessage:(NSString*)message;

@end
