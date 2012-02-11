// MySqueakQl - MySql.m
//
// Copyright (C) 2012 Ciaran Jessup
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  Created by Ciaran on 01/02/2012.
//
#import "MySql.h"

@implementation MySql

-(id) initWithHost:(NSString *)host port:(UInt16)port user:(NSString *)user password:(NSString *)password {
    self = [super init];
    if (self) {
        protocolImpl= [[MySqlProtocol alloc] init];
        [protocolImpl connectToHost:host 
                               port:port];
        [protocolImpl handshakeForUserName:user
                          password:password];
    }
    return self;
}

-(void)dealloc {
    [protocolImpl dealloc];
    [super dealloc];
}

-(void) selectDatabase:(NSString*)database {
    volatile __block bool blockCalled= false;
    
    NSLog(@"Select Database");    
    NSData* data=[database dataUsingEncoding:NSUTF8StringEncoding];
    [protocolImpl sendCommand:2 
                         data:data
            continueWithBlock:^(){
                NSData* okOrErrorPacket= [protocolImpl readPacket];
                UInt8* resultPacketData= (UInt8*)[okOrErrorPacket bytes];
                if( resultPacketData[0] == 0xFF ) {
                    uint16_t errorNumber= resultPacketData[1] + (resultPacketData[2]<<8);
                    // sqlstate is chars 3-> 8
                    
                    NSString* errorMessage= [[NSString alloc] initWithCString: (const char*)(resultPacketData+9) encoding:NSASCIIStringEncoding];
                    
                    NSLog(@"ERROR: %@ (%u)", errorMessage, errorNumber);
                    for(int i=0;i< [okOrErrorPacket length]; i++ ) {
                        fprintf(stderr, "%x ", resultPacketData[i]);
                    }
                    [errorMessage release];
                }
                else {
                    NSLog(@"HAPPPY PACKET");
                }
                [okOrErrorPacket release];
                blockCalled= true;
            }];
    // As an attempt to simplify the external API, we
    // simulate a blocking API by blocking the calling thread, until
    // the command's callback block has executed.
    while(!blockCalled) {
        [NSThread sleepForTimeInterval:0.01];
    }
}

-(void) performQuery:(NSString*)query continueWithBlock:(void (^)(void))block {
    NSLog(@"Execute Query");
    NSData* data=[query dataUsingEncoding:NSUTF8StringEncoding];
    [protocolImpl sendCommand:3 
                         data:data
            continueWithBlock:^(){
                NSData* okOrErrorPacket= [protocolImpl readPacket];
                UInt8* resultPacketData= (UInt8*)[okOrErrorPacket bytes];
                if( resultPacketData[0] == 0xFF ) {
                    uint16_t errorNumber= resultPacketData[1] + (resultPacketData[2]<<8);
                    // sqlstate is chars 3-> 8
                    
                    NSString* errorMessage= [NSString stringWithCString: (const char*)(resultPacketData+9) encoding:NSASCIIStringEncoding];
                    
                    NSLog(@"ERROR: %@ (%u)", errorMessage, errorNumber);
                    [okOrErrorPacket release]; // We release this on the happy path when we release 'resultSetHeaderPacket'
                }
                else {
                    NSLog(@"HAPPPY PACKET");
                    NSData *resultSetHeaderPacket= okOrErrorPacket;
                    UInt8 fieldCount= *((unsigned char*)[resultSetHeaderPacket bytes]);
                    NSLog(@"Found %d fields...",fieldCount);
                    NSData* fieldDescriptor= [protocolImpl readPacket];
                    
                    while( ![protocolImpl isEOFPacket: fieldDescriptor ] ) {
                        //         NSLog(@"Read a field."); 
                        [fieldDescriptor release];
                        fieldDescriptor= [protocolImpl readPacket];
                    }
                    [fieldDescriptor release];
                    
                    NSData* rowDataPacket= [protocolImpl readPacket];
                    while( ![protocolImpl isEOFPacket: rowDataPacket ] ) {
                        //        NSLog(@"Read a RowPacket."); 
                        [rowDataPacket release];
                        rowDataPacket= [protocolImpl readPacket];
                    }
                    [rowDataPacket release];
                    [resultSetHeaderPacket release];
                    
                }
                block();
            }];
}
@end
