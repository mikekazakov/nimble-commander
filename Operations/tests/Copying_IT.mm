// Copyright (C) 2019-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <Operations/Copying.h>
#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include <Habanero/algo.h>

using nc::utility::NativeFSManager;
using nc::ops::Copying;
using nc::ops::CopyingOptions;
using nc::ops::OperationState;

static std::vector<VFSListingItem> FetchItems(const std::string& _directory_path,
                                              const std::vector<std::string> &_filenames,
                                              VFSHost &_host)
{
    std::vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}

#define PREFIX "nc::ops::Copying "

static void RunOperationAndCheckSuccess(nc::ops::Operation &operation)
{
    operation.Start();
    operation.Wait();
    REQUIRE( operation.State() == OperationState::Completed );
}

TEST_CASE(PREFIX"Verify that /Applications/ and temp dir are on the same fs")
{
    const std::string target_dir = "/Applications/";
    TempTestDir test_dir;
    REQUIRE( TestEnv().native_fs_man->VolumeFromPath(test_dir.directory) ==
     TestEnv().native_fs_man->VolumeFromPath(target_dir) );
}

TEST_CASE(PREFIX"Can rename a regular file across firmlink injection points")
{
    const std::string filename = "__nc_rename_test__";
    const std::string target_dir = "/Applications/";
    auto rm_result = [&]{ unlink((target_dir + filename).c_str()); };
    rm_result();
    auto clean_afterward = at_scope_end([&]{ rm_result(); });        
    
    TempTestDir test_dir;
    
    REQUIRE( close( creat( (test_dir.directory + filename).c_str(), 0755 ) ) == 0 );

    struct stat orig_stat;
    REQUIRE( stat( (test_dir.directory + filename).c_str(), &orig_stat) == 0 );

    CopyingOptions opts;
    opts.docopy = false;
    
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename}, *host), target_dir, host, opts);
    RunOperationAndCheckSuccess(op);
    
    struct stat renamed_stat;
    REQUIRE( stat( (target_dir + filename).c_str(), &renamed_stat) == 0 );
    
    // Verify that the file was renamed instead of copied+deleted
    CHECK( renamed_stat.st_dev == orig_stat.st_dev );
    CHECK( renamed_stat.st_ino == orig_stat.st_ino );
}

TEST_CASE(PREFIX"Can rename a directory across firmlink injection points")
{
    const std::string filename = "__nc_rename_test__";
    const std::string target_dir = "/Applications/";
    auto rm_result = [&]{ rmdir((target_dir + filename).c_str()); };
    rm_result();
    auto clean_afterward = at_scope_end([&]{ rm_result(); });        
    
    TempTestDir test_dir;
    
    REQUIRE( mkdir( (test_dir.directory + filename).c_str(), 0755 ) == 0 );

    struct stat orig_stat;
    REQUIRE( stat( (test_dir.directory + filename).c_str(), &orig_stat) == 0 );

    CopyingOptions opts;
    opts.docopy = false;
    
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename}, *host), target_dir, host, opts);
    RunOperationAndCheckSuccess(op);
    
    struct stat renamed_stat;
    REQUIRE( stat( (target_dir + filename).c_str(), &renamed_stat) == 0 );
    
    // Verify that the directory was renamed instead of copied+deleted
    CHECK( renamed_stat.st_dev == orig_stat.st_dev );
    CHECK( renamed_stat.st_ino == orig_stat.st_ino );
}

TEST_CASE(PREFIX"Can rename a non-empty directory across firmlink injection points")
{
    const std::string filename = "__nc_rename_test__";
    const std::string filename_in_dir = "filename.txt";
    const std::string target_dir = "/Applications/";
    auto rm_result = [&]{
        unlink( (target_dir + filename + "/" + filename_in_dir).c_str() );   
        rmdir((target_dir + filename).c_str());        
    };
    rm_result();
    auto clean_afterward = at_scope_end([&]{ rm_result(); });        
    
    TempTestDir test_dir;
    
    REQUIRE( mkdir( (test_dir.directory + filename).c_str(), 0755 ) == 0 );
    REQUIRE( close( creat( (test_dir.directory + filename + "/" + filename_in_dir).c_str(), 0755 ) ) == 0 );    

    struct stat orig_stat;
    REQUIRE( stat( (test_dir.directory + filename).c_str(), &orig_stat) == 0 );

    CopyingOptions opts;
    opts.docopy = false;
    
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename}, *host), target_dir, host, opts);
    RunOperationAndCheckSuccess(op);
    
    struct stat renamed_stat;
    REQUIRE( stat( (target_dir + filename).c_str(), &renamed_stat) == 0 );
    
    // Verify that the directory was renamed instead of copied+deleted
    CHECK( renamed_stat.st_dev == orig_stat.st_dev );
    CHECK( renamed_stat.st_ino == orig_stat.st_ino );
}

TEST_CASE(PREFIX"Can rename a symlink across firmlink injection points")
{
    const std::string filename = "__nc_rename_test__";
    const std::string target_dir = "/Applications/";
    auto rm_result = [&]{ unlink((target_dir + filename).c_str()); };
    rm_result();
    auto clean_afterward = at_scope_end([&]{ rm_result(); });        
    
    TempTestDir test_dir;
    
    REQUIRE( symlink("/", (test_dir.directory + filename).c_str()) == 0 );

    struct stat orig_stat;
    REQUIRE( lstat( (test_dir.directory + filename).c_str(), &orig_stat) == 0 );

    CopyingOptions opts;
    opts.docopy = false;
    
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename}, *host), target_dir, host, opts);
    RunOperationAndCheckSuccess(op);
    
    struct stat renamed_stat;
    REQUIRE( lstat( (target_dir + filename).c_str(), &renamed_stat) == 0 );
    
    // Verify that the directory was renamed instead of copied+deleted
    CHECK( renamed_stat.st_dev == orig_stat.st_dev );
    CHECK( renamed_stat.st_ino == orig_stat.st_ino );
}

TEST_CASE(PREFIX"Can rename a regular file on injected data volume")
{
    const std::string filename_src = "__nc_rename_test__";
    const std::string filename_dst = "__nc_rename_test__2";
    const std::string target_dir = "/Applications/";
    auto rm_result = [&]{
        unlink((target_dir + filename_src).c_str());
        unlink((target_dir + filename_dst).c_str());        
    };
    rm_result();
    auto clean_afterward = at_scope_end([&]{ rm_result(); });        
    
    TempTestDir test_dir;
    
    REQUIRE( close( creat( (test_dir.directory + filename_src).c_str(), 0755 ) ) == 0 );

    struct stat orig_stat;
    REQUIRE( stat( (test_dir.directory + filename_src).c_str(), &orig_stat) == 0 );

    CopyingOptions opts;
    opts.docopy = false;
    
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename_src}, *host),
        target_dir + filename_dst, host, opts);
    RunOperationAndCheckSuccess(op);
    
    struct stat renamed_stat;
    REQUIRE( stat( (target_dir + filename_dst).c_str(), &renamed_stat) == 0 );
    
    // Verify that the file was renamed instead of copied+deleted
    CHECK( renamed_stat.st_dev == orig_stat.st_dev );
    CHECK( renamed_stat.st_ino == orig_stat.st_ino );
}

TEST_CASE(PREFIX"Correctly handles requests to rename into non-existing dir")
{
    const std::string filename = "__nc_rename_test__";
    const std::string target_dir = "a/b/c/d/";
    
    TempTestDir test_dir;
    
    REQUIRE( close( creat( (test_dir.directory + filename).c_str(), 0755 ) ) == 0 );

    struct stat orig_stat;
    REQUIRE( stat( (test_dir.directory + filename).c_str(), &orig_stat) == 0 );

    CopyingOptions opts;
    opts.docopy = false;
    
    auto host = TestEnv().vfs_native;
    Copying op(FetchItems(test_dir.directory, {filename}, *host),
        test_dir.directory + target_dir + filename, host, opts);
    RunOperationAndCheckSuccess(op);
    
    struct stat renamed_stat;
    REQUIRE( stat( (test_dir.directory + target_dir + filename).c_str(), &renamed_stat) == 0 );
    
    // Verify that the file was renamed instead of copied+deleted
    CHECK( renamed_stat.st_dev == orig_stat.st_dev );
    CHECK( renamed_stat.st_ino == orig_stat.st_ino );
}
