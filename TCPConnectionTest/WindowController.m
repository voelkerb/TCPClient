//
//  AppController.m
//  TCPConnectionTest
//
//  Created by Benjamin Völker on 05/08/15.
//  Copyright © 2015 Benjamin Völker. All rights reserved.
//

#import "WindowController.h"
#define CONNECT_TEXT @"Connect"
#define DISCONNECT_TEXT @"Disconnect"


@interface WindowController ()

@end

@implementation WindowController

@synthesize ipTextField, portTextField, sendTextField, receiveTextView, sendButton, connectButton, autoScroll, tcpConnection;

- (void)windowDidLoad {
    [super windowDidLoad];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (id)init {
  if (self = [super init]) {
    NSLog(@"Heurika");
    self.tcpConnection = [[NetworkController alloc] init];
    self.tcpConnection.delegate = self;
    
    [self.receiveTextView setTextColor:NSColor.textColor];
//    [self.receiveTextView setTypingAttributes:<#(NSDictionary<NSAttributedStringKey,id> * _Nonnull)#>]
    [self performSelector:@selector(initializeGUI) withObject:nil afterDelay:1];
  }
  return self;
}


- (void)initializeGUI {
  [self.connectButton setTitle:CONNECT_TEXT];
  self.sendButton.enabled = false;
}


- (IBAction)sendAction:(id)sender {
  if ([[self.sendTextField stringValue] length] > 0) {
    [self.tcpConnection sendMessage:[sendTextField stringValue]];
  }
}

- (IBAction)clearAction:(id)sender {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSAttributedString* attr = [[NSAttributedString alloc] initWithString:@""];
      
    [[self.receiveTextView textStorage] setAttributedString:attr];
  });
}


- (IBAction)connectAction:(id)sender {
  if (sender != self.connectButton && self.tcpConnection.connected)  {
    return;
  }
  if ( self.tcpConnection.connected ) {
    [self.tcpConnection disconnect];
  } else {
    [self.tcpConnection connect:[ipTextField stringValue] :[portTextField intValue]];
  }
}


- (void)appendToMyTextView:(NSString*)text {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSAttributedString* attr = [[NSAttributedString alloc] initWithString:text];
      
    [[self.receiveTextView textStorage] appendAttributedString:attr];
    [self.receiveTextView setTextColor:NSColor.textColor];
//      [self.receiveTextView setFont:[NSFont fontWithName:@"Monaco" size:12]];
      [self.receiveTextView setFont:[NSFont fontWithName:@"Menlo" size:12]];
      if ( [self.autoScroll state] == NSOnState ) {
        [self.receiveTextView scrollRangeToVisible:NSMakeRange([[self.receiveTextView string] length], 0)];
      }
  });
}


- (void)connected:(NetworkController *)sender {
  [self.ipTextField setEnabled:NO];
  [self.portTextField setEnabled:NO];
  self.sendButton.enabled = true;
  [self.connectButton setTitle:DISCONNECT_TEXT];
  [self appendToMyTextView:[NSString stringWithFormat:@"********** Connected to %@ **********\n", [tcpConnection host]]];
}

- (void)disconnected:(NetworkController *)sender {
  [self.ipTextField setEnabled:YES];
  [self.portTextField setEnabled:YES];
  self.sendButton.enabled = false;
  [self.connectButton setTitle:CONNECT_TEXT];
  [self appendToMyTextView:[NSString stringWithFormat:@"********** Disconnected **********\n"]];
}

- (void)receivedMsg:(NetworkController *)sender :(NSString *)msg {
  [self appendToMyTextView:msg];
}

- (void)receivedMsgError:(NetworkController *)sender {
}


@end
