//
//  MySqlResults.m
//  myControlR
//
//  Created by Ciaran on 11/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MySqlResults.h"

@implementation MySqlResults

@synthesize rows, fields, affectedRows;

- (void)dealloc {
    [rows release];
    [fields release];
    [affectedRows release];
    [super dealloc];
}
@end
