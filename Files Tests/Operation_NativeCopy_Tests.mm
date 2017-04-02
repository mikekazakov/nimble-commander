//
//  Operation_NativeCopy_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 21/03/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include <sys/stat.h>
#include "tests_common.h"
#include <VFS/Native.h>
#include <NimbleCommander/Operations/Copy/FileCopyOperation.h>


static vector<VFSListingItem> FetchItems(const string& _directory_path,
                                                 const vector<string> &_filenames,
                                                 VFSHost &_host)
{
    vector<VFSListingItem> items;
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
        opts.exist_behavior = FileCopyOperationOptions::ExistBehavior::OverwriteAll;
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
        opts.exist_behavior = FileCopyOperationOptions::ExistBehavior::OverwriteAll;
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

- (void)testCaseRenaming
{
    auto dir = self.makeTmpDir;
    auto host = VFSNativeHost::SharedHost();
    
    {
        __block bool finished = false;
        auto src = dir / "directory";
        mkdir(src.c_str(), S_IWUSR | S_IXUSR | S_IRUSR);
        
        FileCopyOperationOptions opts;
        opts.docopy = false;
        FileCopyOperation *op = [FileCopyOperation alloc];
        op = [op initWithItems:FetchItems(dir.native(), {"directory"}, *host)
               destinationPath:(dir / "DIRECTORY").native()
               destinationHost:host
                       options:opts];
        
        [op AddOnFinishHandler:^{ finished = true; }];
        [op Start];
        [self waitUntilFinish:finished];
        
        XCTAssert( host->IsDirectory((dir / "DIRECTORY").c_str(), 0, nullptr) == true );
        XCTAssert( FetchItems(dir.native(), {"DIRECTORY"}, *host).front().Filename() == "DIRECTORY" );
    }
    
    {
        __block bool finished = false;
        auto src = dir / "filename";
        close(open(src.c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR));
        
        FileCopyOperationOptions opts;
        opts.docopy = false;
        FileCopyOperation *op = [FileCopyOperation alloc];
        op = [op initWithItems:FetchItems(dir.native(), {"filename"}, *host)
               destinationPath:(dir / "FILENAME").native()
               destinationHost:host
                       options:opts];
        
        [op AddOnFinishHandler:^{ finished = true; }];
        [op Start];
        [self waitUntilFinish:finished];
        
        XCTAssert( host->Exists((dir / "FILENAME").c_str()) == true );
        XCTAssert( FetchItems(dir.native(), {"FILENAME"}, *host).front().Filename() == "FILENAME" );
    }
    
    XCTAssert( VFSEasyDelete(dir.c_str(), host) == 0);
}

- (path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" "info.filesmanager.files" ".tmp.XXXXXX", NSTemporaryDirectory().fileSystemRepresentation);
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
