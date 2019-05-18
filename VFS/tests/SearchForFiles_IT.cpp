// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "SearchForFiles.h"
#include <Habanero/CommonPaths.h>
#include <Utility/PathManip.h>
#include <Native.h>
#include <set>

using nc::vfs::SearchForFiles;

static auto g_TestDirPrefix = "_nc__vfs__search_for_files__test_";

#define PREFIX "[nc::vfs::SearchForFiles] "

struct TestDir
{
    TestDir();
    ~TestDir();
    std::string directory;
    static std::string MakeTempFilesStorage();
    static int RMRF(const std::string& _path);
};

static void BuildTestData(const std::string &_root_path);
static bool Save(const std::string &_filepath, const std::string &_content);
static bool MkDir(const std::string &_dir_path);

TEST_CASE(PREFIX "Test basic searching")
{
    using Options = SearchForFiles::Options;
    TestDir test_dir;
    BuildTestData(test_dir.directory);
    auto &host = nc::vfs::NativeHost::SharedHost();
    
    using set = std::set<std::string>; 
    set filenames;
    auto callback = [&](const char *_filename, const char *_in_path, VFSHost&, CFRange) {
        filenames.emplace(_filename);
    };
    
    SearchForFiles search;
    auto do_search = [&](int _flags) {
        search.Go(test_dir.directory, host, _flags, callback, {});
        search.Wait();
    };

    SECTION("search for all entries, recursively") {
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{"Dir", "filename1.txt", "filename2.txt", "filename3.txt"} );    
    }
    SECTION("search for all entries, non-recursively") {
        do_search( Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{"Dir", "filename1.txt", "filename2.txt"} );    
    }
    SECTION("search for all files") {
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles );
        CHECK( filenames == set{"filename1.txt", "filename2.txt", "filename3.txt"} );    
    }
    SECTION("search for all directories") {
        do_search( Options::GoIntoSubDirs | Options::SearchForDirs );
        CHECK( filenames == set{"Dir"} );    
    }
    SECTION("search for all entries with mask='*.txt'") {
        auto filter = SearchForFiles::FilterName{};
        filter.mask = "*.txt";
        search.SetFilterName(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForDirs | Options::SearchForFiles );
        CHECK( filenames == set{"filename1.txt", "filename2.txt", "filename3.txt"} );
    }
    SECTION("search for all entries with mask='*.jpg'") {
        auto filter = SearchForFiles::FilterName{};
        filter.mask = "*.jpg";
        search.SetFilterName(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForDirs | Options::SearchForFiles );
        CHECK( filenames == set{} );
    }
    SECTION("search for all entries with mask='filename'") {
        auto filter = SearchForFiles::FilterName{};
        filter.mask = "filename";
        search.SetFilterName(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForDirs | Options::SearchForFiles );
        CHECK( filenames == set{"filename1.txt", "filename2.txt", "filename3.txt"} );
    }
    SECTION("search for all entries with mask='dir'") {
        auto filter = SearchForFiles::FilterName{};
        filter.mask = "dir";
        search.SetFilterName(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForDirs | Options::SearchForFiles );
        CHECK( filenames == set{"Dir"} );
    }
}

TEST_CASE(PREFIX "Test size filter")
{
    using Options = SearchForFiles::Options;
    TestDir test_dir;
    BuildTestData(test_dir.directory);
    auto &host = nc::vfs::NativeHost::SharedHost();
    
    using set = std::set<std::string>; 
    set filenames;
    auto callback = [&](const char *_filename, const char *_in_path, VFSHost&, CFRange) {
        filenames.emplace(_filename);
    };
    
    SearchForFiles search;
    auto do_search = [&](int _flags) {
        search.Go(test_dir.directory, host, _flags, callback, {});
        search.Wait();
    };
    
    SECTION("min = 25") {
        auto filter = SearchForFiles::FilterSize{};
        filter.min = 25;
        search.SetFilterSize(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{"filename3.txt"} );    
    }
    SECTION("max = 15") {
        auto filter = SearchForFiles::FilterSize{};
        filter.max = 15;
        search.SetFilterSize(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{"filename1.txt"} );    
    }
    SECTION("min = 15 && max = 25") {
        auto filter = SearchForFiles::FilterSize{};
        filter.min = 15;
        filter.max = 25;        
        search.SetFilterSize(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{"filename2.txt", "filename3.txt"} );    
    }    
}

TEST_CASE(PREFIX "Test content filter")
{
    using Options = SearchForFiles::Options;
    TestDir test_dir;
    BuildTestData(test_dir.directory);
    auto &host = nc::vfs::NativeHost::SharedHost();
    
    using set = std::set<std::string>; 
    set filenames;
    auto callback = [&](const char *_filename, const char *_in_path, VFSHost&, CFRange) {
        filenames.emplace(_filename);
    };
    
    SearchForFiles search;
    auto do_search = [&](int _flags) {
        search.Go(test_dir.directory, host, _flags, callback, {});
        search.Wait();        
    };
    
    SECTION("world") {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "world";
        search.SetFilterContent(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{"filename1.txt", "filename3.txt"} );    
    }
    SECTION("hello") {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "hello";
        search.SetFilterContent(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{"filename1.txt"} );    
    }
    SECTION("hello, case sensitive") {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "hello";
        filter.case_sensitive = true;
        search.SetFilterContent(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{} );    
    }
    SECTION("hello, not containing") {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "hello";
        filter.not_containing = true;
        search.SetFilterContent(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{"filename2.txt", "filename3.txt"} );    
    }
    SECTION("hello, whole phrase") {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "hello";
        filter.whole_phrase = true;
        search.SetFilterContent(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{"filename1.txt"} );    
    }    
    SECTION("ello, whole phrase") {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "ello";
        filter.whole_phrase = true;
        search.SetFilterContent(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{} );
    }
    SECTION("мир, UTF8") {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = u8"мир"; 
        search.SetFilterContent(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{"filename2.txt"} );
    }
    SECTION("мир, MACOS_ROMAN_WESTERN") {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = u8"мир";
        filter.encoding = encodings::ENCODING_MACOS_ROMAN_WESTERN;
        search.SetFilterContent(filter);
        do_search( Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs );
        CHECK( filenames == set{} );
    }    
}

static void BuildTestData(const std::string &_root_path)
{
    Save( _root_path + "filename1.txt", "Hello, world!");
    Save( _root_path + "filename2.txt", u8"Привет, мир!");
    MkDir( _root_path + "Dir" );
    Save( _root_path + "Dir/filename3.txt", "Almost edge of the world!");
}

TestDir::TestDir()
{
    directory = MakeTempFilesStorage();
}

TestDir::~TestDir()
{
    RMRF(directory);
}

int TestDir::RMRF(const std::string& _path)
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

std::string TestDir::MakeTempFilesStorage()
{
    const auto base_path = CommonPaths::AppTemporaryDirectory();
    const auto tmp_path = base_path + g_TestDirPrefix + "/";
    if( access(tmp_path.c_str(), F_OK) == 0 )
        RMRF(tmp_path);
    if( mkdir(tmp_path.c_str(), S_IRWXU) != 0 )
        throw std::runtime_error("mkdir failed");
    return tmp_path;
}

static bool Save(const std::string &_filepath, const std::string &_content)
{
    std::ofstream out( _filepath, std::ios::out | std::ios::binary );
    if( !out )
        return false;        
    out << _content;    
    out.close();
    return true;        
}

static bool MkDir(const std::string &_dir_path)
{
    return  mkdir(_dir_path.c_str(), S_IRWXU) != 0;
}
