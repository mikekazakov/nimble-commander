//
//  Operation_VFSDelete_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 08.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "tests_common.h"
#include "VFS.h"
#include "FileDeletionOperation.h"

@interface Operation_VFSDelete_Tests : XCTestCase
@end

@implementation Operation_VFSDelete_Tests

- (void)testSimpleDeleteFromFTP
{
    try {
        auto host = make_shared<VFSNetFTPHost>("192.168.2.5", "", "", "/");
        
        const char *fn1 = "/System/Library/Kernels/kernel", *fn2 = "/Public/!FilesTesting/mach_kernel";
        VFSStat stat;
        
        // if there's a trash from previous runs - remove it
        if( host->Stat(fn2, stat, 0, 0) == 0)
            XCTAssert( host->Unlink(fn2, 0) == 0);
        
        XCTAssert( VFSEasyCopyFile(fn1, VFSNativeHost::SharedHost(), fn2, host) == 0);
        
        FileDeletionOperation *op = [FileDeletionOperation alloc];
        op = [op initWithFiles:vector<string>{"mach_kernel"}
                           dir:"/Public/!FilesTesting"
                            at:host];
        
        __block bool finished = false;
        [op AddOnFinishHandler:^{ finished = true; }];
        [op Start];
        [self waitUntilFinish:finished];
        
        XCTAssert( host->Stat(fn2, stat, 0, 0) != 0); // check that file has gone
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testDeleteFromFTPASimpleDir
{
    try {
        auto host = make_shared<VFSNetFTPHost>("192.168.2.5", "", "", "/");
        
        const char *fn1 = "/bin", *fn2 = "/Public/!FilesTesting/bin";
        VFSStat stat;
        
        // if there's a trash from previous runs - remove it
        if( host->Stat(fn2, stat, 0, 0) == 0)
            XCTAssert(VFSEasyDelete(fn2, host) == 0);
        
        XCTAssert( VFSEasyCopyNode(fn1, VFSNativeHost::SharedHost(), fn2, host) == 0);
        
        FileDeletionOperation *op = [FileDeletionOperation alloc];
        op = [op initWithFiles:vector<string>{"bin"}
                           dir:"/Public/!FilesTesting"
                            at:host];
        
        __block bool finished = false;
        [op AddOnFinishHandler:^{ finished = true; }];
        [op Start];
        [self waitUntilFinish:finished];
        
        XCTAssert( host->Stat(fn2, stat, 0, 0) != 0); // check that file has gone
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
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
