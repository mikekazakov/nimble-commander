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
        _file1_host->IterateDirectoryListing(_file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
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
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("192.168.2.5", "", "", "/");
    } catch( VFSErrorException &e ) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    const char *fn1 = "/System/Library/Kernels/kernel",
               *fn2 = "/Public/!FilesTesting/kernel";

    [self EnsureClean:fn2 at:host];
    
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:vector<string>(1, "kernel")
                      root:"/System/Library/Kernels/"
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
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("192.168.2.5", "", "", "/");
    } catch( VFSErrorException &e ) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    auto files = {"Info.plist", "PkgInfo", "version.plist"};
    
    for(auto &i: files)
      [self EnsureClean:"/Public/!FilesTesting/"s + i at:host];
    
    
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:vector<string>(begin(files), end(files))
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
        XCTAssert( VFSEasyCompareFiles(("/Applications/Mail.app/Contents/"s + i).c_str(),
                                       VFSNativeHost::SharedHost(),
                                       ("/Public/!FilesTesting/"s + i).c_str(),
                                       host,
                                       compare) == 0);
        XCTAssert( compare == 0);
        XCTAssert( host->Unlink(("/Public/!FilesTesting/"s + i).c_str(), 0) == 0);
    }
}

- (void)testCopyToFTP_192_168_2_5_____3
{
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("192.168.2.5", "", "", "/");
    } catch( VFSErrorException &e ) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    [self EnsureClean:"/Public/!FilesTesting/bin" at:host];
    
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:vector<string>(1, "bin")
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

- (void)testCopyGenericToGeneric_Modes_CopyToPrefix
{
    auto dir = self.makeTmpDir;
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:vector<string>(1, "Mail.app")
                      root:"/Applications/"
                    srcvfs:VFSNativeHost::SharedHost()
                      dest:dir.c_str()
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
    
    XCTAssert( VFSEasyDelete(dir.c_str(), VFSNativeHost::SharedHost()) == 0);
}

- (void)testCopyGenericToGeneric_Modes_CopyToPrefix_WithAbsentDirectoriesInPath
{
    // just like testCopyGenericToGeneric_Modes_CopyToPrefix but file copy operation should build a destination path
    auto dir = self.makeTmpDir;
    path dst_dir = path(dir) / "Some" / "Absent" / "Dir" / "Is" / "Here";
    
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:vector<string>(1, "Mail.app")
                      root:"/Applications/"
                    srcvfs:VFSNativeHost::SharedHost()
                      dest:dst_dir.c_str()
                    dstvfs:VFSNativeHost::SharedHost()
                   options:FileCopyOperationOptions()];
    
    __block bool finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    int result = 0;
    XCTAssert( VFSCompareEntries(path("/Applications") / "Mail.app",
                                 VFSNativeHost::SharedHost(),
                                 dst_dir / "Mail.app",
                                 VFSNativeHost::SharedHost(),
                                 result) == 0);
    XCTAssert( result == 0 );
    
    XCTAssert( VFSEasyDelete(dir.c_str(), VFSNativeHost::SharedHost()) == 0);
}

- (void)testCopyGenericToGeneric_Modes_CopyToPrefix_WithLocalDir
{
    // works on single host - In and Out same as where source files are
    auto dir = self.makeTmpDir;
    auto host = VFSNativeHost::SharedHost();
    
    XCTAssert( VFSEasyCopyNode("/Applications/Mail.app",
                               host,
                               (path(dir) / "Mail.app").c_str(),
                               host) == 0);
    
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:vector<string>(1, "Mail.app")
                      root:dir.c_str()
                    srcvfs:host
                      dest:"SomeDirectoryName/"
                    dstvfs:host
                   options:FileCopyOperationOptions()];
    
    __block bool finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    int result = 0;
    XCTAssert( VFSCompareEntries("/Applications/Mail.app", host, dir / "SomeDirectoryName" / "Mail.app", host, result) == 0);
    XCTAssert( result == 0 );
    XCTAssert( VFSEasyDelete(dir.c_str(), host) == 0);
}

- (void)testCopyGenericToGeneric_Modes_CopyToPathName_WithLocalDir
{
    // works on single host - In and Out same as where source files are
    // Copies "Mail.app" to "Mail2.app" in the same dir
    auto dir = self.makeTmpDir;
    auto host = VFSNativeHost::SharedHost();
    
    XCTAssert( VFSEasyCopyNode("/Applications/Mail.app",
                               host,
                               (path(dir) / "Mail.app").c_str(),
                               host) == 0);
    
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:vector<string>(1, "Mail.app")
                      root:dir.c_str()
                    srcvfs:host
                      dest:"Mail2.app"
                    dstvfs:host
                   options:FileCopyOperationOptions()];
    
    __block bool finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    int result = 0;
    XCTAssert( VFSCompareEntries("/Applications/Mail.app", host, dir / "Mail2.app", host, result) == 0);
    XCTAssert( result == 0 );
    XCTAssert( VFSEasyDelete(dir.c_str(), host) == 0);
}

- (void)testCopyGenericToGeneric_Modes_CopyToPathName_SingleFile
{
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("192.168.2.5", "", "", "/");
    } catch( VFSErrorException &e ) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    const char *fn1 = "/System/Library/Kernels/kernel",
    *fn2 = "/Public/!FilesTesting/kernel",
    *fn3 = "/Public/!FilesTesting/kernel copy";
    
    [self EnsureClean:fn2 at:host];
    [self EnsureClean:fn3 at:host];
    
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:vector<string>(1, "kernel")
                      root:"/System/Library/Kernels/"
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
    
    
    op = [FileCopyOperation alloc];
    op = [op initWithFiles:vector<string>(1, "kernel")
                      root:"/Public/!FilesTesting/"
                    srcvfs:host
                      dest:fn3
                    dstvfs:host
                   options:FileCopyOperationOptions()];
    
    finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    XCTAssert( VFSEasyCompareFiles(fn2, host, fn3, host, compare) == 0);
    XCTAssert( compare == 0);
    
    XCTAssert( host->Unlink(fn2, 0) == 0);
    XCTAssert( host->Unlink(fn3, 0) == 0);
}

- (void)testCopyGenericToGeneric_Modes_RenameToPathPreffix
{
    // works on single host - In and Out same as where source files are
    // Copies "Mail.app" to "Mail2.app" in the same dir
    auto dir = self.makeTmpDir;
    auto dir2 = dir / "Some" / "Dir" / "Where" / "Files" / "Should" / "Be" / "Renamed";
    auto host = VFSNativeHost::SharedHost();
    
    XCTAssert( VFSEasyCopyNode("/Applications/Mail.app", host, (path(dir) / "Mail.app").c_str(), host) == 0);
    
    FileCopyOperationOptions opts;
    opts.docopy = false;
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:vector<string>(1, "Mail.app")
                      root:dir.c_str()
                    srcvfs:host
                      dest:dir2.c_str()
                    dstvfs:host
                   options:opts];
    
    __block bool finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    int result = 0;
    XCTAssert( VFSCompareEntries("/Applications/Mail.app", host, dir2 / "Mail.app", host, result) == 0);
    XCTAssert( result == 0 );
    XCTAssert( VFSEasyDelete(dir.c_str(), host) == 0);
}

- (void)testCopyGenericToGeneric_Modes_RenameToPathName
{
    // works on single host - In and Out same as where source files are
    // Copies "Mail.app" to "Mail2.app" in the same dir
    auto dir = self.makeTmpDir;
    auto host = VFSNativeHost::SharedHost();
    
    XCTAssert( VFSEasyCopyNode("/Applications/Mail.app", host, (path(dir) / "Mail.app").c_str(), host) == 0);
    
    FileCopyOperationOptions opts;
    opts.docopy = false;
    FileCopyOperation *op = [FileCopyOperation alloc];
    op = [op initWithFiles:vector<string>(1, "Mail.app")
                      root:dir.c_str()
                    srcvfs:host
                      dest:"Mail2.app"
                    dstvfs:host
                   options:opts];
    
    __block bool finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    int result = 0;
    XCTAssert( VFSCompareEntries("/Applications/Mail.app", host, dir / "Mail2.app", host, result) == 0);
    XCTAssert( result == 0 );
    XCTAssert( VFSEasyDelete(dir.c_str(), host) == 0);
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

- (path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" __FILES_IDENTIFIER__ ".tmp.XXXXXX", NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

@end
