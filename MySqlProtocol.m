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

@interface MySqlProtocol()
// Declare private methods here.
@end

@implementation MySqlProtocol

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
    return [input read:buffer maxLength:len];
}

- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len {
    return [output write:buffer maxLength:len];
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

-(NSData *) readPacket {
    NSMutableData* packet= [[NSMutableData alloc] initWithCapacity:4096];
    uint8_t buffer[4096];
    long rc1;
    rc1= [self read:buffer maxLength:4];
    assert(rc1 == 4);
    uint32_t packet_size= buffer[0] + (buffer[1]<<8) + (buffer[2] << 16);
    packetNumber= buffer[3]+1;
    NSLog(@"RECVD Packet Number : %d of size %ul", packetNumber, packet_size);
    
    uint32_t readSoFar= 0;
    do {
        rc1= [self read:buffer maxLength:( readSoFar+4096>packet_size?(packet_size-readSoFar):4096)];
        readSoFar+= rc1;
        
        if( rc1 > 0 ) {
            [packet appendBytes:buffer length:rc1];
        }
    }
    while( rc1 > 0 && readSoFar<packet_size );  
    
    assert( readSoFar == packet_size);
    
    return packet;
    
}

-(void) sendUint32: (UInt32)value{
    uint8_t val= value & 0xFF;
    long rc1;
    rc1= [self write: &val maxLength:1];
    assert(rc1 == 1);
    val= (value & 0xFF00)>>8;
    rc1= [self write: &val maxLength:1];
    assert(rc1 == 1);
    val= (value & 0xFF0000)>>16;
    rc1=[self write: &val maxLength:1];
    assert(rc1 == 1);
}

-(NSNumber*) readLengthCodedLength:(UInt8**) byteDataPtr {
    //This is a length encoded binary.. for now pretend it isn't.
    UInt8 firstByte= **byteDataPtr;
    (*byteDataPtr)++;
    if( firstByte == 251 ) {
        return NULL;
    }
    else {
        UInt64 length= 0;
        if( firstByte <=250 ) {
            length= firstByte;
        }
        else {
            // I imagine this logic is bobbins..had no test data...
            switch( firstByte ) {
                case 252:
                    length= **byteDataPtr;
                    length= length + ((UInt64)(*((*byteDataPtr)+1)) << 8);
                    (*byteDataPtr)+=2;
                    break;
                case 253:
                    length= **byteDataPtr;
                    length= length + ((UInt64)(*((*byteDataPtr)+1)) << 8);
                    length= length + ((UInt64)(*((*byteDataPtr)+2)) << 16);
                    (*byteDataPtr)+=3;
                case 254:
                    length= **byteDataPtr;
                    length= length + ((UInt64)(*((*byteDataPtr)+1)) << 8);
                    length= length + ((UInt64)(*((*byteDataPtr)+2)) << 16);
                    length= length + ((UInt64)(*((*byteDataPtr)+3)) << 24);
                    length= length + ((UInt64)(*((*byteDataPtr)+4)) << 32);
                    length= length + ((UInt64)(*((*byteDataPtr)+5)) << 40);
                    length= length + ((UInt64)(*((*byteDataPtr)+6)) << 48);
                    length= length + ((UInt64)(*((*byteDataPtr)+7)) << 56);
                    (*byteDataPtr)+=8;
                    break;
            }
        }
        return [NSNumber numberWithUnsignedLong:length];
    }
}

-(NSString*) readLengthCodedString:(UInt8**) byteDataPtr {
    NSNumber* stringLength= [self readLengthCodedLength:byteDataPtr];
    if( stringLength != NULL ) {
        NSString* value= [[NSString alloc]initWithBytes:*byteDataPtr length:[stringLength unsignedIntValue] encoding:NSASCIIStringEncoding];
        (*byteDataPtr)+=[stringLength unsignedIntValue];
        return value;
    } else {
        return NULL;
    }
}


-(void) sendPacket:(NSData*)packet {
    //todo ensure not bigger than 16M (I suspect we'll have overflows in the next line : )
    
    [self sendUint32:(UInt32)[packet length]];
    
    int rc1= [self write:&packetNumber maxLength:1];
    assert( rc1 == 1 );
    rc1= [self write:[packet bytes] maxLength:[packet length]];
    assert( rc1 == [packet length] );
    
    NSLog(@"Sent Packet Number : %d of size %ul", packetNumber,[packet length]);
}

-(void) handshakeForUserName:(NSString*)user password:(NSString*)password {
    NSData* handshakeInitialisationPacket= [self readPacket];
    NSMutableData *scrambleBuffer= [[NSMutableData alloc] initWithCapacity:100];
    
    UInt8* byteData= (UInt8*)[handshakeInitialisationPacket bytes];
    UInt8 protcol_version= *(byteData++);
    NSString* server_version= [NSString stringWithCString: (const char*)byteData
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
    [scrambleBuffer release];
    
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
        NSString* errorMessage= [NSString stringWithCString: (const char*)(resultPacketData+9) encoding:NSASCIIStringEncoding];
        
        NSLog(@"ERROR: %@ (%u)", errorMessage, errorNumber);
        for(int i=0;i< [okOrErrorPacket length]; i++ ) {
            fprintf(stderr, "%x ", resultPacketData[i]);
        }
    }
    else {
        NSLog(@"HAPPPY PACKET");
        
    }
    [okOrErrorPacket release];
}

-(void) sendCommand:(UInt8)command data:(NSData*)data continueWithBlock:(void (^)(void))block {
    [data retain];
    // Dispatch onto our FIFO queue, only one sendCommand (and its continuation block) can occur at a time
    dispatch_async( queue, ^{
        packetNumber= 0; // Reset the packet number
        NSMutableData* dataToSend= [[NSMutableData alloc] initWithBytes:&command length:1];
        if ( data != NULL ) {
            [dataToSend appendData:data];
        }
        [self sendPacket:dataToSend];
        [dataToSend release];
        if ( data != NULL ) { [data release]; }
        if( block != NULL ) {
            block();
        }
   });
}

-(bool) isEOFPacket:(NSData*)data {
    return *((unsigned char*)[data bytes]) == 0xFE && [data length] < 9;
}

- (id)init {
    self = [super init];
    if (self) {
        queue = dispatch_queue_create("me.ciaranj.mysqueakql", NULL);
    }
    return self;
}

-(void)dealloc {
    if( input != NULL ) {
            [input close];
            [output close];
            [input release];
            [output release];
            input= NULL;
            output= NULL;
    }
    dispatch_release(queue);
    [super dealloc];
}
@end
