//
//  MySql.m
//  Test
//
//  Created by Ciaran on 01/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MySql.h"
#include "sha.h"

@implementation MySql
@synthesize packetNumber;

-(NSData *) readPacketFromStream:(NSInputStream*) stream {
    NSMutableData* packet= [[NSMutableData alloc] initWithCapacity:30000];
    [packet retain];
    
    uint8_t buffer[4096];
    long rc1;
    rc1= [stream read:buffer maxLength:4];
    assert(rc1 == 4);
    uint32_t packet_size= buffer[0] + (buffer[1]<<8) + (buffer[2] << 16);
    packetNumber= buffer[3];
    NSLog(@"RECVD Packet Number : %d of size %ul", packetNumber, packet_size);

    uint32_t readSoFar= 0;
    do {
        rc1= [stream read:buffer maxLength:( readSoFar+4096>packet_size?(packet_size-readSoFar):4096)];
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

-(void) sendPacket:(NSData*)packet toStream:(NSOutputStream*)stream {
    //todo ensure not bigger than 16M (I suspect we'll have overflows in the next line : )
    
    [self sendUint32:(UInt32)[packet length] toStream:stream];
    
    packetNumber++;
    int rc1= [stream write:&packetNumber maxLength:1];
    assert( rc1 == 1 );
    rc1= [stream write:[packet bytes] maxLength:[packet length]];
    NSLog(@"Written : %d bytes", rc1);
    assert( rc1 == [packet length] );
 //   NSLog(@"SENT Packet Number : %d of size %@", packetNumber, [packet length]);

}

-(void) handshakeForUserName:(NSString*)user password:(NSString*)password inputStream:(NSInputStream*)inputStream outputStream:(NSOutputStream*)outputStream {
    NSData* handshakeInitialisationPacket= [self readPacketFromStream:inputStream];
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
    byteData+=2;
    UInt8 scramble_length= *(byteData++);
    byteData++;
    byteData+=10; // Skip the fller.
    
    fprintf(stderr, "CurrentBuffer: \n");
    const uint8_t* tokin= [scrambleBuffer bytes];
    for(int i=0;i< 8; i++ ) {
        fprintf(stderr, "%c", *tokin);
        tokin++;
    }
    fprintf(stderr, "\n");
    [scrambleBuffer appendBytes:byteData length:12];

    fprintf(stderr, "CurrentBuffer2: \n");
    tokin= [scrambleBuffer bytes];
    for(int i=0;i< 20; i++ ) {
        fprintf(stderr, "%c", *tokin);
        tokin++;
    }
    fprintf(stderr, "\n");

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
//    client_capabilities= client_capabilities | 1; // new long passwords
    client_capabilities= client_capabilities | 32768; // New 4.1 authentication
    
    
     uint8_t val= client_capabilities & 0xFF;
     [client_auth_packet appendBytes:&val length:1];
     val= (client_capabilities & 0xFF00)>>8;
     [client_auth_packet appendBytes:&val length:1];
     val= (client_capabilities & 0xFF0000)>>16;
     [client_auth_packet appendBytes:&val length:1];
     val= (client_capabilities & 0xFF000000)>>24;
     [client_auth_packet appendBytes:&val length:1];
     
     UInt32 max_packet_size= 4096;
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
     //    const char* user_c_str= [user cStringUsingEncoding:NSASCIIStringEncoding];
         uint8_t username[5]= {'x','b','m','c'};
         [client_auth_packet appendBytes:&username length:4];
         [client_auth_packet appendBytes:&val length:1];        

    SHA_CTX context;
    unsigned char stage1[SHA_DIGEST_LENGTH];
    unsigned char stage2[SHA_DIGEST_LENGTH];
    unsigned char stage3[SHA_DIGEST_LENGTH];
    memset(stage1, 0, SHA_DIGEST_LENGTH);
    memset(stage2, 0, SHA_DIGEST_LENGTH);
    memset(stage3, 0, SHA_DIGEST_LENGTH);
//    const unsigned char* cstr_password= (const unsigned char*)[password cStringUsingEncoding:NSASCIIStringEncoding]; // No idea if mysql alows non ascii passwords *sob*
    const unsigned char cstr_password[]= {'g','i','b','s','o','n'};
    
    SHA1_Init(&context);
    SHA1_Update(&context, cstr_password, 6);
    SHA1_Final(stage1, &context);

    SHA1_Init(&context);
    SHA1_Update(&context, stage1, SHA_DIGEST_LENGTH);
    SHA1_Final(stage2, &context);

    
    
//    NSMutableData* combined= [[NSMutableData alloc]initWithData:scrambleBuffer];
  //  [combined appendBytes:stage2 length:SHA_DIGEST_LENGTH];
    
    SHA1_Init(&context);
//    const unsigned char cstr_scramble_buffer[]= {'\'','H','t','0','0','A','6','*','n','m','X','O','f','3','g','/','U','<','k','('};
//    SHA1_Update(&context,cstr_scramble_buffer, 20);

    fprintf(stderr, "TOKIN: \n");
  tokin= [scrambleBuffer bytes];
    for(int i=0;i< 20; i++ ) {
        fprintf(stderr, "%c", *tokin);
        tokin++;
    }
    fprintf(stderr, "\n");
    
    
    
    SHA1_Update(&context,[scrambleBuffer bytes], [scrambleBuffer length]);
    SHA1_Update(&context, stage2, SHA_DIGEST_LENGTH);
    SHA1_Final(stage3, &context);
    
//    token= stage3 xor stage1
    
    unsigned char token[SHA_DIGEST_LENGTH];
    for(i= 0;i< SHA_DIGEST_LENGTH;i++) {
        token[i]= stage3[i]^stage1[i];
    }
    
    val=SHA_DIGEST_LENGTH;
    [client_auth_packet appendBytes:&val length:1];
    [client_auth_packet appendBytes:&token length:SHA_DIGEST_LENGTH];

    
/*    unsigned char* token_ptr= &token[0];
    for(int i= SHA_DIGEST_LENGTH-1;i>=0;i--) {
        [client_auth_packet appendBytes:(token_ptr+i) length:1];
    }
  */  
    
    
   /* 
    stage1_hash = SHA1(password), using the password that the user has entered.
    token = SHA1(scramble + SHA1(stage1_hash)) XOR stage1_hash
    */
    
    
    fprintf(stderr, "TOKEN: \n");
    for(int i=0;i< 20; i++ ) {
        fprintf(stderr, "%x", token[i]);
    }
    fprintf(stderr, "\n");
   
    
    [self sendPacket:client_auth_packet 
            toStream:outputStream];
    [client_auth_packet release];
    NSData* okOrErrorPacket= [self readPacketFromStream:inputStream];
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

    /*
    4                            client_flags
    4                            max_packet_size
    1                            charset_number
    23                           (filler) always 0x00...
    n (Null-Terminated String)   user
    n (Length Coded Binary)      scramble_buff (1 + x bytes)
    n (Null-Terminated String)   databasename (optional) */
    
    
    /*
       Understanding length encoded binary types
     
     Value Of     # Of Bytes  Description
     First Byte   Following
     ----------   ----------- -----------
     0-250        0           = value of first byte
     251          0           column value = NULL
     only appropriate in a Row Data Packet
     252          2           = value of following 16-bit word
     253          3           = value of following 24-bit word
     254          8           = value of following 64-bit word
    
    */
    
}

-(id) initWithHost:(NSString *)host port:(int)port user:(NSString *)user password:(NSString *)password {
    self = [super init];
    if (self) {
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        CFStreamCreatePairWithSocketToHost(NULL, (CFStringRef)host, port, &readStream, &writeStream);
        //TODO: assert that both readStream + writeSTream are non-null
        
        NSInputStream* input= (NSInputStream*)readStream;
        NSOutputStream* output=(NSOutputStream*)writeStream;
        [input open];
        [output open]; 

        [self handshakeForUserName:user
                          password:password
                       inputStream:input
                          outputStream:output];
        
    }
    return self;
}

@end
