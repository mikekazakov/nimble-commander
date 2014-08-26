//
//  VFSSFTP_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 25/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "tests_common.h"
#import "VFS.h"

@interface VFSSFTP_Tests : XCTestCase

@end

@implementation VFSSFTP_Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
//    XCTAssert(YES, @"Pass");
    auto host = make_shared<VFSNetSFTPHost>("192.168.2.5");
    VFSNetSFTPOptions opts;
    opts.user = "admin";
    opts.passwd = "iddqd";
    opts.port = 22;
    host->Open("/", opts);
    
    
    shared_ptr<VFSListing> listing;
    host->FetchDirectoryListing("/", &listing, 0, 0);
    
 
    int a = 10;
}


@end
