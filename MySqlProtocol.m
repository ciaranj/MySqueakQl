// MySqueakQl - MySqlProtocol.m
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


#import "MySqlProtocol.h"
#import <CommonCrypto/CommonDigest.h>

@implementation MySqlProtocol
-(NSData *) readPacket {
    NSMutableData* packet= [[NSMutableData alloc] initWithCapacity:30000];
    [packet retain];
    
    uint8_t buffer[4096];
    long rc1;
    rc1= [input read:buffer maxLength:4];
    assert(rc1 == 4);
    uint32_t packet_size= buffer[0] + (buffer[1]<<8) + (buffer[2] << 16);
    packetNumber= buffer[3]+1;
    NSLog(@"RECVD Packet Number : %d of size %ul", packetNumber, packet_size);
    
    uint32_t readSoFar= 0;
    do {
        rc1= [input read:buffer maxLength:( readSoFar+4096>packet_size?(packet_size-readSoFar):4096)];
        readSoFar+= rc1;
        
        if( rc1 > 0 ) {
            [packet appendBytes:buffer length:rc1];
        }
    }
    while( rc1 > 0 && readSoFar<packet_size );  
    
    assert( readSoFar == packet_size);
    
    return packet;
    
}

-(void) sendUint32: (UInt32)value toStream:(NSOutputStream*)stream {
    uint8_t val= value & 0xFF;
    long rc1;
    rc1= [stream write: &val maxLength:1];
    assert(rc1 == 1);
    val= (value & 0xFF00)>>8;
    rc1= [stream write: &val maxLength:1];
    assert(rc1 == 1);
    val= (value & 0xFF0000)>>16;
    rc1=[stream write: &val maxLength:1];
    assert(rc1 == 1);
}

-(void) sendPacket:(NSData*)packet {
    //todo ensure not bigger than 16M (I suspect we'll have overflows in the next line : )
    
    [self sendUint32:(UInt32)[packet length] toStream:output];
    
    int rc1= [output write:&packetNumber maxLength:1];
    assert( rc1 == 1 );
    rc1= [output write:[packet bytes] maxLength:[packet length]];
    assert( rc1 == [packet length] );
    
    NSLog(@"Sent Packet Number : %d of size %ul", packetNumber,[packet length]);
}

-(void) handshakeForUserName:(NSString*)user password:(NSString*)password {
    NSData* handshakeInitialisationPacket= [self readPacket];
    NSMutableData *scrambleBuffer= [[NSMutableData alloc] initWithCapacity:100];
    
    UInt8* byteData= (UInt8*)[handshakeInitialisationPacket bytes];
    UInt8 protcol_version= *(byteData++);
    NSString* server_version= [[NSString alloc] initWithCString: (const char*)byteData
                                                       encoding:NSASCIIStringEncoding];
    byteData+=[server_version length]+1; // assumes 1byteperchar [ascii]
    byteData+=4; // Skip the thread_id
    [scrambleBuffer appendBytes:byteData length:8];
    byteData+=8;
    assert(*byteData++ == 0 ); //filler check.
    
    UInt32 server_capabilities= ( ((*byteData)<<8) + *(byteData+1));
    byteData+=2;
    UInt8 server_language= *byteData;
    byteData+=2; // Skip  server_status;
    server_capabilities= server_capabilities + ( ((*byteData)<<16) + ((*(byteData+1))<<24));
    byteData+=14; // Skip the fller, scramble length etc.
    
    // hard-coded 12 here is wrong, should scan upto the null pointer end.
    [scrambleBuffer appendBytes:byteData length:12];
    byteData+=12;
    assert( *byteData == 0 );
    
    [handshakeInitialisationPacket release];
    NSLog(@"Handshaking to Server Version '%@' using Protocol version: %d Language: %d", server_version, protcol_version, server_language);
    
    NSMutableData *client_auth_packet= [[NSMutableData alloc] initWithCapacity:100];
    [client_auth_packet retain];
    UInt32 client_capabilities= server_capabilities;
    client_capabilities= client_capabilities &~ 8; // Not specifying database on connection.
    client_capabilities= client_capabilities &~ 32; // Do not use compression
    client_capabilities= client_capabilities &~ 64; // this is not an odbc client
    client_capabilities= client_capabilities &~ 1024; // this is not an interactive session
    client_capabilities= client_capabilities &~ 2048; // do not switch to ssl    
    client_capabilities= client_capabilities | 512; // new 4.1 protocol
    client_capabilities= client_capabilities | 32768; // New 4.1 authentication
    
    
    uint8_t val= client_capabilities & 0xFF;
    [client_auth_packet appendBytes:&val length:1];
    val= (client_capabilities & 0xFF00)>>8;
    [client_auth_packet appendBytes:&val length:1];
    val= (client_capabilities & 0xFF0000)>>16;
    [client_auth_packet appendBytes:&val length:1];
    val= (client_capabilities & 0xFF000000)>>24;
    [client_auth_packet appendBytes:&val length:1];
    
    UInt32 max_packet_size= 65536;
    val= max_packet_size & 0xFF;
    [client_auth_packet appendBytes:&val length:1];
    val= (max_packet_size & 0xFF00)>>8;
    [client_auth_packet appendBytes:&val length:1];
    val= (max_packet_size & 0xFF0000)>>16;
    [client_auth_packet appendBytes:&val length:1];
    val= (max_packet_size & 0xFF000000)>>24;
    [client_auth_packet appendBytes:&val length:1];    
    
    [client_auth_packet appendBytes:&server_language length:1];    
    val=0;
    int i=0;
    for(i=0;i<23;i++) {
        [client_auth_packet appendBytes:&val length:1];        
    } 
    const char* user_c_str= [user cStringUsingEncoding:NSASCIIStringEncoding];
    [client_auth_packet appendBytes:user_c_str length:strlen(user_c_str)];
    [client_auth_packet appendBytes:&val length:1];        
    
    CC_SHA1_CTX context;
    unsigned char stage1[CC_SHA1_DIGEST_LENGTH];
    unsigned char stage2[CC_SHA1_DIGEST_LENGTH];
    unsigned char stage3[CC_SHA1_DIGEST_LENGTH];
    memset(stage1, 0, CC_SHA1_DIGEST_LENGTH);
    memset(stage2, 0, CC_SHA1_DIGEST_LENGTH);
    memset(stage3, 0, CC_SHA1_DIGEST_LENGTH);
    const char* cstr_password=[password cStringUsingEncoding:NSASCIIStringEncoding]; // No idea if mysql alows non ascii passwords *sob*
    
    CC_SHA1_Init(&context);
    CC_SHA1_Update(&context, cstr_password, strlen(cstr_password));
    CC_SHA1_Final(stage1, &context);
    
    CC_SHA1_Init(&context);
    CC_SHA1_Update(&context, stage1, CC_SHA1_DIGEST_LENGTH);
    CC_SHA1_Final(stage2, &context);
    
    CC_SHA1_Init(&context);    
    CC_SHA1_Update(&context,[scrambleBuffer bytes], [scrambleBuffer length]);
    CC_SHA1_Update(&context, stage2, CC_SHA1_DIGEST_LENGTH);
    CC_SHA1_Final(stage3, &context);
    
    unsigned char token[CC_SHA1_DIGEST_LENGTH];
    for(i= 0;i< CC_SHA1_DIGEST_LENGTH;i++) {
        token[i]= stage3[i]^stage1[i];
    }
    
    val=CC_SHA1_DIGEST_LENGTH;
    [client_auth_packet appendBytes:&val length:1];
    [client_auth_packet appendBytes:&token length:CC_SHA1_DIGEST_LENGTH];
    
    [self sendPacket:client_auth_packet];
    [client_auth_packet release];
    NSData* okOrErrorPacket= [self readPacket];
    UInt8* resultPacketData= (UInt8*)[okOrErrorPacket bytes];
    if( resultPacketData[0] == 0xFF ) {
        uint16_t errorNumber= resultPacketData[1] + (resultPacketData[2]<<8);
        // sqlstate is chars 3-> 8
        
        NSString* errorMessage= [[NSString alloc] initWithCString: (const char*)(resultPacketData+9) encoding:NSASCIIStringEncoding];
        
        NSLog(@"ERROR: %@ (%u)", errorMessage, errorNumber);
        for(int i=0;i< [okOrErrorPacket length]; i++ ) {
            fprintf(stderr, "%x ", resultPacketData[i]);
        }
    }
    else {
        NSLog(@"HAPPPY PACKET");
        
    }
    
    NSString* meh= [[NSString alloc] initWithData:okOrErrorPacket encoding:NSASCIIStringEncoding];
    NSLog(@"%@", meh);
    [okOrErrorPacket release];
}

-(void) sendCommand:(UInt8)command data:(NSData*)data {
    packetNumber= 0; // Reset the packet number
    NSMutableData* dataToSend= [[NSMutableData alloc] initWithBytes:&command length:1];
    if ( data != NULL ) {
        [dataToSend appendData:data];
    }
    [self sendPacket:dataToSend];
}

-(bool) isEOFPacket:(NSData*)data {
    return *((unsigned char*)[data bytes]) == 0xFE && [data length] < 9;
}
-(void) connectToHost:(NSString*)host port:(UInt16)port {
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)host, port, &readStream, &writeStream);
    //TODO: assert that both readStream + writeSTream are non-null

    input= (NSInputStream*)readStream;
    output=(NSOutputStream*)writeStream;
    [input open];
    [output open]; 
}

-(void)dealloc {
    if( input != NULL ) {
        [self sendCommand:1 data:NULL];
        [input close];
        [output close];
        [input release];
        [output release];
        input= NULL;
        output= NULL;
    }
    
    [super dealloc];
}
@end
