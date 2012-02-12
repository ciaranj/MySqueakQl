//
//  MySqlResults.m
//  myControlR
//
//  Created by Ciaran on 11/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MySqlResults.h"

@implementation MySqlResults

@synthesize rows, fields;

- (void)dealloc {
    if( rows != NULL ) {
        [rows release];
    }
    if( fields != NULL ) {
        [fields release];
    }
    [super dealloc];
}
@end
