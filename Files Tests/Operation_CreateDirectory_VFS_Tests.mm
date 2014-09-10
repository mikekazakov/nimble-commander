//
//  Operation_CreateDirectory_VFS_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 09.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "tests_common.h"
#include "VFS.h"
#include "CreateDirectoryOperation.h"

@interface Operation_CreateDirectory_VFS_Tests : XCTestCase

@end

@implementation Operation_CreateDirectory_VFS_Tests

- (void)testFTP_LocalNAS
{
    auto host = make_shared<VFSNetFTPHost>("192.168.2.5");
    XCTAssert( host->Open("/") == 0 );
    
    CreateDirectoryOperation *op = [CreateDirectoryOperation alloc];
    op = [op initWithPath:"/Public/!FilesTesting/Dir/Other/Dir/And/Many/other fancy dirs/" rootpath:"/" at:host];
    
    __block bool finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    
    VFSStat st;
    XCTAssert( host->Stat("/Public/!FilesTesting/Dir/Other/Dir/And/Many/other fancy dirs/", st, 0, 0) == 0);
    XCTAssert( VFSEasyDelete("/Public/!FilesTesting/Dir", host) == 0);
    
    op = [CreateDirectoryOperation alloc];
    op = [op initWithPath:"AnotherDir/AndSecondOne" rootpath:"/Public/!FilesTesting" at:host];

    finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];

    XCTAssert( host->Stat("/Public/!FilesTesting/AnotherDir/AndSecondOne", st, 0, 0) == 0);
    XCTAssert( VFSEasyDelete("/Public/!FilesTesting/AnotherDir", host) == 0);
}

- (void) waitUntilFinish:(volatile bool&)_finished
{
    microseconds sleeped = 0us, sleep_tresh = 60s;
    while (!_finished)
    {
        this_thread::sleep_for(100us);
        sleeped += 100us;
        XCTAssert( sleeped < sleep_tresh);
        if(sleeped > sleep_tresh)
            break;
    }
}

@end
