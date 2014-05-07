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

static int VFSCompareEntries(const path& _file1_full_path,
                             const VFSHostPtr& _file1_host,
                             const path& _file2_full_path,
                             const VFSHostPtr& _file2_host,
                             int &_result)
{
    // not comparing flags, perm, times, xattrs, acls etc now
    
    VFSStat st1, st2;
    int ret;
    if((ret =_file1_host->Stat(_file1_full_path.c_str(), st1, 0, 0)) != 0)
        return ret;

    if((ret =_file2_host->Stat(_file2_full_path.c_str(), st2, 0, 0)) != 0)
        return ret;
    
    if((st1.mode & S_IFMT) != (st2.mode & S_IFMT))
    {
        _result = -1;
        return 0;
    }
    
    if( S_ISREG(st1.mode) )
    {
        _result = int(int64_t(st1.size) - int64_t(st2.size));
        return 0;
    }
    else if ( S_ISDIR(st1.mode) )
    {
        _file1_host->IterateDirectoryListing(_file1_full_path.c_str(), ^bool(const VFSDirEnt &_dirent) {
            int ret = VFSCompareEntries( _file1_full_path / _dirent.name,
                                        _file1_host,
                                        _file2_full_path / _dirent.name,
                                        _file2_host,
                                        _result);
            if(ret != 0)
                return false;
            return true;
        });
    }
    return 0;
}

@interface Operation_VFStoVFSCopy_Tests : XCTestCase

@end

@implementation Operation_VFStoVFSCopy_Tests

- (void) EnsureClean:(const string&)_fn at:(const VFSHostPtr&)_h
{
    VFSStat stat;
    if( _h->Stat(_fn.c_str(), stat, 0, 0) == 0)
        XCTAssert( VFSEasyDelete(_fn.c_str(), _h) == 0);
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
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
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
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];

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

- (void)testCopyToFTP_192_168_2_5_____3
{
    auto host = make_shared<VFSNetFTPHost>("192.168.2.5");
    XCTAssert( host->Open("/", nullptr) == 0 );
    
    [self EnsureClean:"/Public/!FilesTesting/bin" at:host];
    
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:chained_strings("bin")
                      root:"/"
                    srcvfs:VFSNativeHost::SharedHost()
                      dest:"/Public/!FilesTesting/"
                    dstvfs:host
                   options:FileCopyOperationOptions()];
    
    __block bool finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    int result = 0;
    XCTAssert( VFSCompareEntries("/bin",
                                 VFSNativeHost::SharedHost(),
                                 "/Public/!FilesTesting/bin",
                                 host,
                                 result) == 0);
    XCTAssert( result == 0 );
    
    [self EnsureClean:"/Public/!FilesTesting/bin" at:host];
}

- (void)testCopyGenericToGeneric______1
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%sinfo.filesmanager.tmp.XXXXXX", NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );

    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:chained_strings("Mail.app")
                      root:"/Applications/"
                    srcvfs:VFSNativeHost::SharedHost()
                      dest:dir
                    dstvfs:VFSNativeHost::SharedHost()
                   options:FileCopyOperationOptions()];
    
    __block bool finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    int result = 0;
    XCTAssert( VFSCompareEntries(path("/Applications") / "Mail.app",
                                 VFSNativeHost::SharedHost(),
                                 path(dir) / "Mail.app",
                                 VFSNativeHost::SharedHost(),
                                 result) == 0);
    XCTAssert( result == 0 );

    XCTAssert( VFSEasyDelete(dir, VFSNativeHost::SharedHost()) == 0);
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
