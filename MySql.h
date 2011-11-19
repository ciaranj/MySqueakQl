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

-(id) initWithHost:(NSString *)host port:(int)port user:(NSString *)user password:(NSString *)password;

-(NSData *) readPacketFromStream:(NSInputStream*)stream;
-(void) sendPacket:(NSData*)packet toStream:(NSOutputStream*)stream;
-(void) sendUint32:(UInt32)value toStream:(NSOutputStream*)stream;


-(void) handshakeForUserName:(NSString*)user password:(NSString*)password inputStream:(NSInputStream*)inputStream outputStream:(NSOutputStream*)outputStream;
@end
