// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include "TemporaryFileStorageImpl.h"
#include "PathManip.h"
#include <Habanero/algo.h>
#include <ftw.h>
#include <fstream>

using nc::utility::TemporaryFileStorageImpl;

static auto g_TestDirPrefix = "_nc__utility__temporary_file_storage__test_";
static int RMRF(const std::string& _path);
static std::string MakeTempFilesStorage();
static std::optional<std::string> Load(const std::string &_filepath);

#define PREFIX "[nc::utility::TemporaryFileStorageImpl] "

TEST_CASE(PREFIX "Checks that base directory is accessible")
{
    const auto base_dir = MakeTempFilesStorage();
    const auto remove_base_dir = at_scope_end([&]{ RMRF(base_dir); });
    SECTION("Valid directory") {
        CHECK_NOTHROW( TemporaryFileStorageImpl{base_dir, "some_prefix"} );
    }
    SECTION("Invalid directoy") {
        CHECK_THROWS( TemporaryFileStorageImpl{base_dir+"12345", "some_prefix"} );
    }
}

TEST_CASE(PREFIX "Checks that temp subdirectories prefix is not empty")
{
    const auto base_dir = MakeTempFilesStorage();
    const auto remove_base_dir = at_scope_end([&]{ RMRF(base_dir); });
    SECTION("Non-empty") {
        CHECK_NOTHROW( TemporaryFileStorageImpl{base_dir, "some_prefix"} );
    }
    SECTION("Empty") {
        CHECK_THROWS( TemporaryFileStorageImpl{base_dir, ""} );
    }
}

TEST_CASE(PREFIX "Creates a temp directory ")
{
    const auto base_dir = MakeTempFilesStorage();
    const auto remove_base_dir = at_scope_end([&]{ RMRF(base_dir); });
    const auto prefix = "some_prefix";
    const auto full_path_prefix = base_dir + prefix;
    auto storage = TemporaryFileStorageImpl{base_dir, prefix};
    
    SECTION("With a provided name") {
        const auto filename = std::string{"dir_name"};
        const auto tmp_dir = storage.MakeDirectory(filename);
        
        struct stat st;
        REQUIRE( tmp_dir != std::nullopt );
        CHECK( tmp_dir->back() == '/' );
        CHECK( lstat(tmp_dir->c_str(), &st) == 0 );
        CHECK( S_ISDIR(st.st_mode) != 0 );
        CHECK( tmp_dir->substr(0, full_path_prefix.length()) == full_path_prefix );
        CHECK( tmp_dir->substr(tmp_dir->length() - filename.length() - 1) == filename + '/' );
    }
    SECTION("Without a provided name") {
        const auto tmp_dir = storage.MakeDirectory();
        
        struct stat st;
        REQUIRE( tmp_dir != std::nullopt );
        CHECK( tmp_dir->back() == '/' );
        CHECK( lstat(tmp_dir->c_str(), &st) == 0 );
        CHECK( S_ISDIR(st.st_mode) != 0 );
        CHECK( tmp_dir->substr(0, full_path_prefix.length()) == full_path_prefix );
    }
}

TEST_CASE(PREFIX "Creates a new path on filenames collision ")
{
    const auto base_dir = MakeTempFilesStorage();
    const auto remove_base_dir = at_scope_end([&]{ RMRF(base_dir); });
    const auto prefix = "some_prefix";
    auto storage = TemporaryFileStorageImpl{base_dir, prefix};
    const auto filename = std::string{"dir_name"};
    
    const auto tmp_dir1 = storage.MakeDirectory(filename);
    const auto tmp_dir2 = storage.MakeDirectory(filename);
    
    REQUIRE( tmp_dir1 != std::nullopt );
    REQUIRE( tmp_dir2 != std::nullopt );
    CHECK( *tmp_dir1 != *tmp_dir2 );
    
    struct stat st;
    CHECK( lstat(tmp_dir1->c_str(), &st) == 0 );
    CHECK( S_ISDIR(st.st_mode) != 0 );
    CHECK( lstat(tmp_dir2->c_str(), &st) == 0 );
    CHECK( S_ISDIR(st.st_mode) != 0 );
}


TEST_CASE(PREFIX "Creates a temp file with a provided data")
{
    const auto base_dir = MakeTempFilesStorage();
    const auto remove_base_dir = at_scope_end([&]{ RMRF(base_dir); });
    const auto prefix = "some_prefix";
    const auto full_path_prefix = base_dir + prefix;
    auto storage = TemporaryFileStorageImpl{base_dir, prefix};
    const auto memory = std::string(1000000, 'Z');
    
    SECTION("Without a filename") {
        const auto tmp_file = storage.MakeFileFromMemory(memory);
        
        REQUIRE( tmp_file != std::nullopt );
        CHECK( Load(*tmp_file) == memory );
    }
    SECTION("With a filename") {
        const auto filename = std::string{"some filename.txt"};
        const auto tmp_file = storage.MakeFileFromMemory(memory, filename);
        
        REQUIRE( tmp_file != std::nullopt );
        CHECK( tmp_file->substr(tmp_file->length() - filename.length()) == filename );
        CHECK( Load(*tmp_file) == memory );
    }
}

static std::string MakeTempFilesStorage()
{
    const auto base_path = EnsureTrailingSlash( NSTemporaryDirectory().fileSystemRepresentation );
    const auto tmp_path = base_path + g_TestDirPrefix + "/";
    if( access(tmp_path.c_str(), F_OK) == 0 )
        RMRF(tmp_path);
    if( mkdir(tmp_path.c_str(), S_IRWXU) != 0 )
        throw std::runtime_error("mkdir failed");
    return tmp_path;
}

static int RMRF(const std::string& _path)
{
    auto unlink_cb = [](const char *fpath,
                        const struct stat *sb,
                        int typeflag,
                        struct FTW *ftwbuf) {
        if( typeflag == FTW_F)
            unlink(fpath);
        else if( typeflag == FTW_D   ||
                 typeflag == FTW_DNR ||
                 typeflag == FTW_DP   )
            rmdir(fpath);
        return 0;
    };
    return nftw(_path.c_str(), unlink_cb, 64, FTW_DEPTH | FTW_PHYS | FTW_MOUNT);
}

static std::optional<std::string> Load(const std::string &_filepath)
{
    std::ifstream in( _filepath, std::ios::in | std::ios::binary );
    if( !in )
        return std::nullopt;
    
    std::string contents;
    in.seekg( 0, std::ios::end );
    contents.resize( in.tellg() );
    in.seekg( 0, std::ios::beg );
    in.read( &contents[0], contents.size() );
    in.close();
    return contents;
}