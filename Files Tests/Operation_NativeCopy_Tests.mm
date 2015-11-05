//
//  Operation_NativeCopy_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 21/03/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "tests_common.h"
#include "../Files/VFS/VFS.h"
#include "../Files/VFS/vfs_native.h"
#include "../Files/Operations/Copy/FileCopyOperation.h"


static vector<VFSFListingItem> FetchItems(const string& _directory_path,
                                                 const vector<string> &_filenames,
                                                 VFSHost &_host)
{
    vector<VFSFListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}


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
        op = [op initWithItems:FetchItems((g_DataPref / "operations/copying/").native(), {"overwrite_test_big.zzz"}, *host)
               destinationPath:dst.native()
               destinationHost:host
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
        op = [op initWithItems:FetchItems((g_DataPref / "operations/copying/").native(), {"overwrite_test_small.zzz"}, *host)
               destinationPath:dst.native()
               destinationHost:host
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
        op = [op initWithItems:FetchItems((g_DataPref / "operations/copying/").native(), {"overwrite_test_small.zzz"}, *host)
               destinationPath:dst.native()
               destinationHost:host
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
        op = [op initWithItems:FetchItems((g_DataPref / "operations/copying/").native(), {"overwrite_test_big.zzz"}, *host)
               destinationPath:dst.native()
               destinationHost:host
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
