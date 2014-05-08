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
    auto host = make_shared<VFSNetFTPHost>("192.168.2.5");
    XCTAssert( host->Open("/", nullptr) == 0 );
    
    const char *fn1 = "/mach_kernel", *fn2 = "/Public/!FilesTesting/mach_kernel";
    VFSStat stat;
    
    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2, stat, 0, 0) == 0)
        XCTAssert( host->Unlink(fn2, 0) == 0);
    
    XCTAssert( VFSEasyCopyFile(fn1, VFSNativeHost::SharedHost(), fn2, host) == 0);
    
    FileDeletionOperation *op = [FileDeletionOperation alloc];
    op = [op initWithFiles:chained_strings("mach_kernel")
                  rootpath:"/Public/!FilesTesting"
                        at:host];
    
    __block bool finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    XCTAssert( host->Stat(fn2, stat, 0, 0) != 0); // check that file has gone
}

- (void)testDeleteFromFTPASimpleDir
{
    auto host = make_shared<VFSNetFTPHost>("192.168.2.5");
    XCTAssert( host->Open("/", nullptr) == 0 );
    
    const char *fn1 = "/bin", *fn2 = "/Public/!FilesTesting/bin";
    VFSStat stat;
    
    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2, stat, 0, 0) == 0)
        XCTAssert(VFSEasyDelete(fn2, host) == 0);
    
    XCTAssert( VFSEasyCopyNode(fn1, VFSNativeHost::SharedHost(), fn2, host) == 0);
    
    FileDeletionOperation *op = [FileDeletionOperation alloc];
    op = [op initWithFiles:chained_strings("bin")
                  rootpath:"/Public/!FilesTesting"
                        at:host];
    
    __block bool finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    XCTAssert( host->Stat(fn2, stat, 0, 0) != 0); // check that file has gone
}

- (void) waitUntilFinish:(volatile bool&)_finished
{
    int sleeped = 0, sleep_tresh = 60000;
    while (!_finished)
    {
        sleeped += usleep(100);
        XCTAssert( sleeped < sleep_tresh);
        if(sleeped > sleep_tresh)
            break;
    }
}
@end
