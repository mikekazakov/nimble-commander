#include <XCTest/XCTest.h>
#include <Habanero/algo.h>
#include "../../vfs/vfs_native.h"
#include "FileSysAttrChangeOperation.h"
#include "FileSysAttrChangeOperationCommand.h"

static string MakeTmpDir()
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" "info.filesmanager.files" ".tmp.XXXXXX", NSTemporaryDirectory().fileSystemRepresentation);
    if( mkdtemp(dir) )
       return dir;
    return "";
}

static bool MakeTmpFile(const string& _path)
{
    int ret = open(_path.c_str(), O_CREAT | O_EXCL, S_IRUSR | S_IWUSR | S_IRGRP);
    if( ret == -1)
        return false;
    close(ret);
    return true;
}

static vector<VFSListingItem> FetchItems(const string& _directory_path,
                                         const vector<string> &_filenames)
{
    vector<VFSListingItem> items;
    VFSNativeHost::SharedHost()->FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}

static uint32_t GetMode(const string&_path)
{
    struct stat st;
    stat( _path.c_str(), &st );
    return st.st_mode;
}

static mode_t GetFlags(const string&_path)
{
    struct stat st;
    stat( _path.c_str(), &st );
    return st.st_flags;
}

static time_t GetMTime(const string&_path)
{
    struct stat st;
    stat( _path.c_str(), &st );
    return st.st_mtime;
}

static time_t GetBTime(const string&_path)
{
    struct stat st;
    stat( _path.c_str(), &st );
    return st.st_birthtime;
}

@interface FileSysAttrChangeOperation_Tests : XCTestCase
@end

@implementation FileSysAttrChangeOperation_Tests

- (void)testBasic
{
    const string filename = "filename.txt";
    const string directory = MakeTmpDir();
    const string path = directory + "/" + filename;
    MakeTmpFile( path );
    auto items = to_shared_ptr(FetchItems(directory, {filename}));
    auto mk_empty_cmd = [&items]{
        FileSysAttrAlterCommand command;
        command.items = items;
        return command;
    };
    
    { // check setting hidden flag
        auto command = mk_empty_cmd();
        command.flags[FileSysAttrAlterCommand::fsf_uf_hidden] = true;
        auto *op = [[FileSysAttrChangeOperation alloc] initWithCommand:command];
        [self runOperationUntilFinish:op];
        XCTAssert( GetFlags(path) == (items->at(0).UnixFlags() | UF_HIDDEN) );
    }
    
    { // check setting usr_x
        auto command = mk_empty_cmd();
        command.flags[FileSysAttrAlterCommand::fsf_unix_usr_x] = true;
        auto *op = [[FileSysAttrChangeOperation alloc] initWithCommand:command];
        [self runOperationUntilFinish:op];
        XCTAssert( GetMode(path) == (items->at(0).UnixMode() | S_IXUSR) );
    }

    { // check setting grp_x
        auto command = mk_empty_cmd();
        command.flags[FileSysAttrAlterCommand::fsf_unix_grp_x] = true;
        auto *op = [[FileSysAttrChangeOperation alloc] initWithCommand:command];
        [self runOperationUntilFinish:op];
        XCTAssert( GetMode(path) == (items->at(0).UnixMode() | S_IXUSR | S_IXGRP) );
    }

    { // check setting oth_x
        auto command = mk_empty_cmd();
        command.flags[FileSysAttrAlterCommand::fsf_unix_oth_x] = true;
        auto *op = [[FileSysAttrChangeOperation alloc] initWithCommand:command];
        [self runOperationUntilFinish:op];
        XCTAssert( GetMode(path) == (items->at(0).UnixMode() | S_IXUSR | S_IXGRP | S_IXOTH) );
    }
    
    auto mtime = [NSDate dateWithTimeIntervalSinceNow:-1000];
    auto btime = [NSDate dateWithTimeIntervalSinceNow:-10000];
    
    { // check setting mtime
        auto command = mk_empty_cmd();
        command.mtime = mtime.timeIntervalSince1970;
        auto *op = [[FileSysAttrChangeOperation alloc] initWithCommand:command];
        [self runOperationUntilFinish:op];
        XCTAssert( GetMode(path) == (items->at(0).UnixMode() | S_IXUSR | S_IXGRP | S_IXOTH) );
        XCTAssert( GetMTime(path) == (time_t)mtime.timeIntervalSince1970 );
    }

    { // check setting btime
        auto command = mk_empty_cmd();
        command.btime = btime.timeIntervalSince1970;
        auto *op = [[FileSysAttrChangeOperation alloc] initWithCommand:command];
        [self runOperationUntilFinish:op];
        XCTAssert( GetMode(path) == (items->at(0).UnixMode() | S_IXUSR | S_IXGRP | S_IXOTH) );
        XCTAssert( GetMTime(path) == (time_t)mtime.timeIntervalSince1970 );
        XCTAssert( GetBTime(path) == (time_t)btime.timeIntervalSince1970 );
    }
    
    XCTAssert( VFSEasyDelete(directory.c_str(), VFSNativeHost::SharedHost()) == 0 );
}

- (void) runOperationUntilFinish:(Operation*)_op
{
    __block bool finished = false;
    [_op AddOnFinishHandler:^{ finished = true; }];
    [_op Start];
    [self waitUntilFinish:finished];
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
