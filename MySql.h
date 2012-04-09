// MySqueakQl - MySql.h
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
#ifndef MySql_h
#define MySql_h

#import <Foundation/Foundation.h>
#import "MySqlProtocol.h"
#import "MySqlResults.h"

@interface MySql : NSObject
@property(retain) MySqlProtocol* protocolImpl;

-(id) initWithHost:(NSString *)host port:(UInt16)port user:(NSString *)user password:(NSString *)password;
-(id) initWithProtocol:(MySqlProtocol*) __attribute__((ns_consumed)) protocol user:(NSString *)user password:(NSString *)password;

// 'Non-Blocking' functions.
-(void) performQuery:(NSString*)query continueWithBlock:(void (^)(MySqlResults *))block;

// 'Blocking' functions.
-(int) selectDatabase:(NSString*)database;
-(int) quit;
@end
#endif