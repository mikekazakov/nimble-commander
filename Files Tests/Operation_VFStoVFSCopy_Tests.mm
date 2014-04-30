//
//  Operation_VFStoVFSCopy_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 30.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "tests_common.h"
#include "VFS.h"
#include "FileCopyOperation.h"


static int microsleep(int _ms)
{
    struct timespec tm, tm2;
    tm.tv_sec  = 0;
    tm.tv_nsec = 1000000L * _ms;
    nanosleep(&tm, &tm2);
    return _ms;
}

@interface Operation_VFStoVFSCopy_Tests : XCTestCase

@end

@implementation Operation_VFStoVFSCopy_Tests

- (void) EnsureClean:(const string&)_fn at:(const VFSHostPtr&)_h
{
    VFSStat stat;
    if( _h->Stat(_fn.c_str(), stat, 0, 0) == 0)
        XCTAssert( _h->Unlink(_fn.c_str(), 0) == 0);
}

- (void)testCopyToFTP_192_168_2_5_____1
{
    auto host = make_shared<VFSNetFTPHost>("192.168.2.5");
    XCTAssert( host->Open("/", nullptr) == 0 );
    
    const char *fn1 = "/mach_kernel",
               *fn2 = "/Public/!FilesTesting/mach_kernel";

    [self EnsureClean:fn2 at:host];
    
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:chained_strings("mach_kernel")
                      root:"/"
                    srcvfs:VFSNativeHost::SharedHost()
                      dest:"/Public/!FilesTesting/"
                    dstvfs:host
                   options:FileCopyOperationOptions()];
    
    __block bool finished = false;
    
    [op AddOnFinishHandler:^{
        finished = true;
    }];
    
    [op Start];
    
    int sleeped = 0, sleep_tresh = 60000;
    while (!finished)
    {
        sleeped += microsleep(100);
        XCTAssert( sleeped < sleep_tresh);
        if(sleeped > sleep_tresh)
            break;
    }
    
    int compare;
    XCTAssert( VFSEasyCompareFiles(fn1, VFSNativeHost::SharedHost(), fn2, host, compare) == 0);
    XCTAssert( compare == 0);
    
    XCTAssert( host->Unlink(fn2, 0) == 0);
}

- (void)testCopyToFTP_192_168_2_5_____2
{
    auto host = make_shared<VFSNetFTPHost>("192.168.2.5");
    XCTAssert( host->Open("/", nullptr) == 0 );
    
    auto files = {"Info.plist", "PkgInfo", "version.plist"};
    
    for(auto &i: files)
      [self EnsureClean:string("/Public/!FilesTesting/") + i at:host];
    
    
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:chained_strings(files)
                      root:"/Applications/Mail.app/Contents"
                    srcvfs:VFSNativeHost::SharedHost()
                      dest:"/Public/!FilesTesting/"
                    dstvfs:host
                   options:FileCopyOperationOptions()];
    
    __block bool finished = false;
    
    [op AddOnFinishHandler:^{
        finished = true;
    }];
    
    [op Start];
    
    int sleeped = 0, sleep_tresh = 60000;
    while (!finished)
    {
        sleeped += microsleep(100);
        XCTAssert( sleeped < sleep_tresh);
        if(sleeped > sleep_tresh)
            break;
    }

    for(auto &i: files)
    {
        int compare;
        XCTAssert( VFSEasyCompareFiles((string("/Applications/Mail.app/Contents/") + i).c_str(),
                                       VFSNativeHost::SharedHost(),
                                       (string("/Public/!FilesTesting/") + i).c_str(),
                                       host,
                                       compare) == 0);
        XCTAssert( compare == 0);
        XCTAssert( host->Unlink((string("/Public/!FilesTesting/") + i).c_str(), 0) == 0);
    }
}

@end
