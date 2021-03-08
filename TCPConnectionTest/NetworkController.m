//
//  NetworkController.m
//
//  Copyright (c) 2012 Peter Bakhirev <peter@byteclub.com>
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.

#import "NetworkController.h"

#pragma mark - Private properties and methods

NSString * const NetworkReceivedMsg = @"NetworkReceivedMsg";
NSString * const NetworkReceivedMsgError = @"NetworkReceivedMsgError";
NSString * const NetworkConnected = @"NetworkConnected";
NSString * const NetworkDisconnected = @"NetworkDisconnected";


@implementation NetworkController

@synthesize connected, host, port, delegate;


-(id)init {
  if (self = [super init]) {
    socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    [socket setDelegate:self];
    connected = false;
  }
  return self;
}


#pragma mark - Public methods

- (BOOL)connect:(NSString *)theHost :(int)thePort {
  NSError *err = nil;
  if (![socket connectToHost:theHost onPort:thePort error:&err]) // Asynchronous!
  {
    // If there was an error, it's likely something like "already connected" or "no delegate set"
    NSLog(@"I goofed: %@", err);
    connected = false;
    return false;
  } else {
    self.host = theHost;
    self.port = thePort;
    NSLog(@"Connected to: %@ on Port: %i", theHost, thePort);
    return true;
  }
}

- (void)disconnect {
  [socket disconnect];
  connected = false;
}

- (void)sendMessage:(NSString*)message {
  NSString *msg = [NSString stringWithFormat:@"%@\r\n", message];
  NSData *data = [msg dataUsingEncoding:NSUTF8StringEncoding];
  // Send the decoded string as data to the socket
  [socket writeData:data withTimeout:-1 tag:0];
}


- (void)socket:(GCDAsyncSocket *)sender didConnectToHost:(NSString *)host port:(UInt16)port {
  connected = true;
  [socket readDataWithTimeout:-1 tag:0];
  [[NSNotificationCenter defaultCenter] postNotificationName:NetworkConnected object:nil];
  [delegate connected:self];
}

/*
 * Is called if data from a socket is read.
 */
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
  // This method is executed on the socketQueue (not the main thread)
  dispatch_async(dispatch_get_main_queue(), ^{
    @autoreleasepool {
      NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length])];
      NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
      if (msg) {
        NSLog(@"Socket Data: %@", msg);
        [[NSNotificationCenter defaultCenter] postNotificationName:NetworkReceivedMsg object:msg];
        [delegate receivedMsg:self :msg];
        // TODO
      } else {
        NSLog(@"Error converting received Display data into UTF-8 String");
        [[NSNotificationCenter defaultCenter] postNotificationName:NetworkReceivedMsgError object:nil];
        [delegate receivedMsgError:self];
      }
    }
  });
  [socket readDataWithTimeout:-1 tag:0];
}


/*
 * If a socket disconnected, remove it from the list of sockets.
 */
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
  // If the socket is not equal to the listening sockets
  if (sock == socket) {
    NSLog(@"Socket Disconnected: %@", err);
    connected = false;
    [[NSNotificationCenter defaultCenter] postNotificationName:NetworkDisconnected object:nil];
    [delegate disconnected:self];
  }
  dispatch_async(dispatch_get_main_queue(), ^{
    @autoreleasepool {
      NSLog(@"Socket Disconnected");
    }
  });
}



@end
