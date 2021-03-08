//
//  AppController.h
//  TCPConnectionTest
//
//  Created by Benjamin Völker on 05/08/15.
//  Copyright © 2015 Benjamin Völker. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "NetworkController.h"

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface WindowController : NSWindowController<NetworkControllerDelegate> {
}


@property (weak) IBOutlet NSTextField *ipTextField;
@property (weak) IBOutlet NSTextField *portTextField;
@property (weak) IBOutlet NSTextField *sendTextField;
@property (unsafe_unretained) IBOutlet NSTextView *receiveTextView;
@property (weak) IBOutlet NSButton *connectButton;
@property (weak) IBOutlet NSButton *sendButton;
@property (weak) IBOutlet NSButton *autoScroll;


@property (strong) NetworkController *tcpConnection;

- (IBAction)sendAction:(id)sender;
- (IBAction)connectAction:(id)sender;
- (IBAction)clearAction:(id)sender;

@end


NS_ASSUME_NONNULL_END
