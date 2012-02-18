//
//  MySqlResults.h
//  myControlR
//
//  Created by Ciaran on 11/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//
#ifndef MySqlResults_h
#define MySqlResults_h
#import <Foundation/Foundation.h>

@interface MySqlResults : NSObject
@property (retain) NSArray* rows;
@property (retain) NSArray* fields;
@property (retain) NSNumber* affectedRows;
@property (retain) NSNumber* insertId;
@end
#endif