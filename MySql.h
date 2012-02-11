//
//  MySql.h
//  Test
//
//  Created by Ciaran on 01/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MySql : NSObject

@property UInt8 packetNumber;
@property (assign) NSInputStream* input;
@property (assign) NSOutputStream* output;


-(NSData *) readPacket;
-(void) sendPacket:(NSData*)packet;
-(void) sendUint32:(UInt32)value toStream:(NSOutputStream*)stream;

-(void) sendCommand:(UInt8)command data:(NSData*)data;
-(bool) isEOFPacket:(NSData*)data;

-(void) handshakeForUserName:(NSString*)user password:(NSString*)password;

// Public API.
-(id) initWithHost:(NSString *)host port:(int)port user:(NSString *)user password:(NSString *)password;
-(void) quit;
-(void) selectDatabase:(NSString*)database;
-(void) performQuery:(NSString*)query;
@end
