//
//  Operation_NativeCopy_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 21/03/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "tests_common.h"
#include "VFS.h"
#include "FileCopyOperation.h"

@interface Operation_NativeCopy_Tests : XCTestCase
@end

@implementation Operation_NativeCopy_Tests

- (void)testOverwriteBugRegression
{
    // ensures no-return of a bug introduced 30/01/15
    auto dir = self.makeTmpDir;
    auto dst = dir / "dest.zzz";
    auto host = VFSNativeHost::SharedHost();
    int result;

    __block bool finished = false;
    
    {
        FileCopyOperationOptions opts;
        opts.docopy = true;
        FileCopyOperation *op = [FileCopyOperation alloc];
        op = [op initWithFiles:vector<string>(1, "overwrite_test_big.zzz")
                          root:(g_DataPref / "operations/copying/").c_str()
                          dest:dst.c_str()
                       options:opts];
    
        [op AddOnFinishHandler:^{ finished = true; }];
        [op Start];
        [self waitUntilFinish:finished];
    }
    
    XCTAssert( VFSEasyCompareFiles((g_DataPref / "operations/copying/overwrite_test_big.zzz").c_str(), host, dst.c_str(), host, result) == 0 );
    XCTAssert( result == 0);
    
    finished = false;    
    {
        FileCopyOperationOptions opts;
        opts.docopy = true;
        opts.force_overwrite = true;
        FileCopyOperation *op = [FileCopyOperation alloc];
        op = [op initWithFiles:vector<string>(1, "overwrite_test_small.zzz")
                          root:(g_DataPref / "operations/copying/").c_str()
                          dest:dst.c_str()
                       options:opts];
        
        [op AddOnFinishHandler:^{ finished = true; }];
        [op Start];
        [self waitUntilFinish:finished];
    }
    
    XCTAssert( VFSEasyCompareFiles((g_DataPref / "operations/copying/overwrite_test_small.zzz").c_str(), host, dst.c_str(), host, result) == 0 );
    XCTAssert( result == 0);
    
    XCTAssert( VFSEasyDelete(dir.c_str(), host) == 0);
}

- (void)testOverwriteBugRegressionReversion
{
    // reversion of testOverwriteBugRegression
    auto dir = self.makeTmpDir;
    auto dst = dir / "dest.zzz";
    auto host = VFSNativeHost::SharedHost();
    int result;
    
    __block bool finished = false;
    
    {
        FileCopyOperationOptions opts;
        opts.docopy = true;
        FileCopyOperation *op = [FileCopyOperation alloc];
        op = [op initWithFiles:vector<string>(1, "overwrite_test_small.zzz")
                          root:(g_DataPref / "operations/copying/").c_str()
                          dest:dst.c_str()
                       options:opts];
        
        [op AddOnFinishHandler:^{ finished = true; }];
        [op Start];
        [self waitUntilFinish:finished];
    }
    
    XCTAssert( VFSEasyCompareFiles((g_DataPref / "operations/copying/overwrite_test_small.zzz").c_str(), host, dst.c_str(), host, result) == 0 );
    XCTAssert( result == 0);
    
    finished = false;
    {
        FileCopyOperationOptions opts;
        opts.docopy = true;
        opts.force_overwrite = true;
        FileCopyOperation *op = [FileCopyOperation alloc];
        op = [op initWithFiles:vector<string>(1, "overwrite_test_big.zzz")
                          root:(g_DataPref / "operations/copying/").c_str()
                          dest:dst.c_str()
                       options:opts];
        
        [op AddOnFinishHandler:^{ finished = true; }];
        [op Start];
        [self waitUntilFinish:finished];
    }
    
    XCTAssert( VFSEasyCompareFiles((g_DataPref / "operations/copying/overwrite_test_big.zzz").c_str(), host, dst.c_str(), host, result) == 0 );
    XCTAssert( result == 0);
    
    XCTAssert( VFSEasyDelete(dir.c_str(), host) == 0);
}

- (path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" __FILES_IDENTIFIER__ ".tmp.XXXXXX", NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

- (void) waitUntilFinish:(volatile bool&)_finished
{
    microseconds sleeped = 0us, sleep_tresh = 60s;
    while (!_finished) {
        this_thread::sleep_for(100us);
        sleeped += 100us;
        XCTAssert( sleeped < sleep_tresh);
        if(sleeped > sleep_tresh)
            break;
    }
}

@end
