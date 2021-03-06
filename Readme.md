MySqueakQl
=============

History
-------
This project is more of a 'demonstration of the possible' rather than an actively supported project.  I had need to access a MySQL server from an iOS device, but discovered that Oracle's dual licence requirements of their client driver (libmysql) effectively precluded the sale of any app that linked to their client libraries (unless you purchased a commercial license, a request that oracle did not respond to.) or the GPL'ing of my code :(

So this is a *VERY* basic and *VERY* rough minimal Objective-C implementation of a mysql client driver that does the minimum I need to solve my requirements.

As such I have no intention to support this code, but have licensed it as MiT so that others could use it or build upon it.  

It was developed in a clean room fashion based solely on the documentation found at http://forge.mysql.com/wiki/MySQL_Internals_ClientServer_Protocol and from diagnostic information gleaned with WireShark which means there should be no GPL infected code present.

As a side note, ObjectiveC is not a language I'm overly familiar with, so this code is of pretty poor quality but may help others access MySQL effectively from their devices.

Usage
-----
Add the class files to your XCode project, and use like this: 

    MySql* mySql= [[MySql alloc] initWithHost:@"127.0.0.1" 
                           port:3306 
                           user:@"my_mysql_user" 
                       password:@"my_top_secret_password"];
    [mySql selectDatabase:@"mysql"];
    [mySql performQuery:@"SELECT * FROM user;" continueWithBlock:^(MySqlResults* results){
        NSLog(@"Received %d results", [results.rows count]);
        for(NSString* field in [results fields]) {
            fprintf(stderr, "%s, ", [(NSString*)[field valueForKey:@"name"] cStringUsingEncoding:NSASCIIStringEncoding]);
        }
        fprintf(stderr, "\n---------------\n");
        for( NSDictionary* row in [results rows]) {
            for(NSString* field in [results fields]) {
                fprintf(stderr, "%s, ", [(NSString*) [row valueForKey: [field valueForKey:@"name"] ] cStringUsingEncoding:NSASCIIStringEncoding]);
            }
            fprintf(stderr, "\n");
        }   
    }];
    [mySql performQuery:@"UPDATE user SET Host='xxxx' WHERE user='SpongeBobSquarePants'" continueWithBlock:^(MySqlResults* results){
        if( [results affectedRows] > 0 ) {
            NSLog(@"Affected %@ rows", [results affectedRows]);
        }
    }];

    [mySql performQuery:@"INSERT INTO user (user,host) VALUES ('bob','localhost')" continueWithBlock:^(MySqlResults* results){
        if( [results affectedRows] > 0 ) {
            NSLog(@"Affected %@ rows (Insert id: %@)", [results affectedRows], [results insertId]);
        }
    }];

insertId
    [mySql quit];
    [mySql release];

Dependencies
------------
Standard iOS libraries, nothing exotic required.

License
-------
MIT licensed, but be aware this code is *not* production ready, probably has memory leaks and should be considered to be purely a 'safe' (non GPL'd) example to base your own implementation on :)