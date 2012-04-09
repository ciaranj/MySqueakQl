// MySqueakQl - MySqlProtocol.h
//
// Copyright (C) 2012 Ciaran Jessup
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software 
// and associated documentation files (the "Software"), to deal in the Software without restriction, 
// including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, 
// subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT 
// NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. 
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  Created by Ciaran on 11/02/2012.
//
#ifndef MySqlProtocol_h
#define MySqlProtocol_h

#import <Foundation/Foundation.h>

@interface MySqlProtocol : NSObject {
@private
UInt8 packetNumber;
@private
NSInputStream* input;
@private
NSOutputStream* output;
@private
dispatch_queue_t queue;
}
@property (retain) NSString* host;
@property UInt16 port;

-(id) initWithHost:(NSString *)host port:(UInt16)port;

// These methods could be over-ridden if you require a non-standard
// connection to the mysql server (for example via a proxy server
// or over an SSH tunnel)
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len;
- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len;
- (int) connect;


-(NSData *) readPacket __attribute((ns_returns_retained));
-(int) sendPacket:(NSData*)packet;
-(int) sendUint32:(UInt32)value;
-(NSNumber*) readLengthCodedLength:(UInt8**) byteData;
-(NSString*) readLengthCodedString:(UInt8**) byteData __attribute((ns_returns_retained));

-(bool) isEOFPacket:(NSData*)data;

-(void) sendCommand:(UInt8)command data:(NSData*)data continueWithBlock:(void (^)(int))block;

-(int) handshakeForUserName:(NSString*)user password:(NSString*)password;
@end
#endif