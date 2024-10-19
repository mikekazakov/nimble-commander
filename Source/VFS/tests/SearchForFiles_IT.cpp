// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include "SearchForFiles.h"
#include <Utility/PathManip.h>
#include <Native.h>
#include <set>
#include <fstream>
#include <sys/stat.h>

using nc::utility::FileMask;
using nc::vfs::SearchForFiles;

#define PREFIX "[nc::vfs::SearchForFiles] "

static void BuildTestData(const std::string &_root_path);
static bool Save(const std::string &_filepath, const std::string &_content);
static bool MkDir(const std::string &_dir_path);

TEST_CASE(PREFIX "Test basic searching")
{
    using Options = SearchForFiles::Options;
    TestDir test_dir;
    BuildTestData(test_dir.directory);
    auto &host = TestEnv().vfs_native;

    using set = std::set<std::string>;
    set filenames;
    auto callback = [&](const char *_filename, [[maybe_unused]] const char *_in_path, VFSHost &, CFRange) {
        filenames.emplace(_filename);
    };

    SearchForFiles search;
    auto do_search = [&](int _flags) {
        search.Go(test_dir.directory, host, _flags, callback, {});
        search.Wait();
    };

    SECTION("search for all entries, recursively")
    {
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames == set{"Dir", "filename1.txt", "filename2.txt", "filename3.txt"});
    }
    SECTION("search for all entries, non-recursively")
    {
        do_search(Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames == set{"Dir", "filename1.txt", "filename2.txt"});
    }
    SECTION("search for all files")
    {
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles);
        CHECK(filenames == set{"filename1.txt", "filename2.txt", "filename3.txt"});
    }
    SECTION("search for all directories")
    {
        do_search(Options::GoIntoSubDirs | Options::SearchForDirs);
        CHECK(filenames == set{"Dir"});
    }
    SECTION("search for all entries with mask='*.txt'")
    {
        search.SetFilterName(FileMask("*.txt"));
        do_search(Options::GoIntoSubDirs | Options::SearchForDirs | Options::SearchForFiles);
        CHECK(filenames == set{"filename1.txt", "filename2.txt", "filename3.txt"});
    }
    SECTION("search for all entries with mask='*.jpg'")
    {
        search.SetFilterName(FileMask("*.jpg"));
        do_search(Options::GoIntoSubDirs | Options::SearchForDirs | Options::SearchForFiles);
        CHECK(filenames.empty());
    }
    SECTION("search for all entries with mask='*filename*'")
    {
        search.SetFilterName(FileMask("*filename*"));
        do_search(Options::GoIntoSubDirs | Options::SearchForDirs | Options::SearchForFiles);
        CHECK(filenames == set{"filename1.txt", "filename2.txt", "filename3.txt"});
    }
    SECTION("search for all entries with regex='(filename1|filename3).*'")
    {
        search.SetFilterName(FileMask("(filename1|filename3).*", FileMask::Type::RegEx));
        do_search(Options::GoIntoSubDirs | Options::SearchForDirs | Options::SearchForFiles);
        CHECK(filenames == set{"filename1.txt", "filename3.txt"});
    }
    SECTION("search for all entries with mask='*dir*'")
    {
        search.SetFilterName(FileMask("*dir*"));
        do_search(Options::GoIntoSubDirs | Options::SearchForDirs | Options::SearchForFiles);
        CHECK(filenames == set{"Dir"});
    }
}

TEST_CASE(PREFIX "Test size filter")
{
    using Options = SearchForFiles::Options;
    TestDir test_dir;
    BuildTestData(test_dir.directory);
    auto &host = TestEnv().vfs_native;

    using set = std::set<std::string>;
    set filenames;
    auto callback = [&](const char *_filename, [[maybe_unused]] const char *_in_path, VFSHost &, CFRange) {
        filenames.emplace(_filename);
    };

    SearchForFiles search;
    auto do_search = [&](int _flags) {
        search.Go(test_dir.directory, host, _flags, callback, {});
        search.Wait();
    };

    SECTION("min = 25")
    {
        auto filter = SearchForFiles::FilterSize{};
        filter.min = 25;
        search.SetFilterSize(filter);
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames == set{"filename3.txt"});
    }
    SECTION("max = 15")
    {
        auto filter = SearchForFiles::FilterSize{};
        filter.max = 15;
        search.SetFilterSize(filter);
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames == set{"filename1.txt"});
    }
    SECTION("min = 15 && max = 25")
    {
        auto filter = SearchForFiles::FilterSize{};
        filter.min = 15;
        filter.max = 25;
        search.SetFilterSize(filter);
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames == set{"filename2.txt", "filename3.txt"});
    }
}

TEST_CASE(PREFIX "Test content filter")
{
    using Options = SearchForFiles::Options;
    TestDir test_dir;
    BuildTestData(test_dir.directory);
    auto &host = TestEnv().vfs_native;

    using set = std::set<std::string>;
    set filenames;
    auto callback = [&](const char *_filename, [[maybe_unused]] const char *_in_path, VFSHost &, CFRange) {
        filenames.emplace(_filename);
    };

    SearchForFiles search;
    auto do_search = [&](int _flags) {
        search.Go(test_dir.directory, host, _flags, callback, {});
        search.Wait();
    };

    SECTION("world")
    {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "world";
        search.SetFilterContent(filter);
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames == set{"filename1.txt", "filename3.txt"});
    }
    SECTION("hello")
    {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "hello";
        search.SetFilterContent(filter);
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames == set{"filename1.txt"});
    }
    SECTION("hello, case sensitive")
    {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "hello";
        filter.case_sensitive = true;
        search.SetFilterContent(filter);
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames.empty());
    }
    SECTION("hello, not containing")
    {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "hello";
        filter.not_containing = true;
        search.SetFilterContent(filter);
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames == set{"filename2.txt", "filename3.txt"});
    }
    SECTION("hello, whole phrase")
    {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "hello";
        filter.whole_phrase = true;
        search.SetFilterContent(filter);
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames == set{"filename1.txt"});
    }
    SECTION("ello, whole phrase")
    {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = "ello";
        filter.whole_phrase = true;
        search.SetFilterContent(filter);
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames.empty());
    }
    SECTION("мир, UTF8")
    {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = reinterpret_cast<const char *>(u8"мир");
        search.SetFilterContent(filter);
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames == set{"filename2.txt"});
    }
    SECTION("мир, MACOS_ROMAN_WESTERN")
    {
        auto filter = SearchForFiles::FilterContent{};
        filter.text = reinterpret_cast<const char *>(u8"мир");
        filter.encoding = nc::utility::Encoding::ENCODING_MACOS_ROMAN_WESTERN;
        search.SetFilterContent(filter);
        do_search(Options::GoIntoSubDirs | Options::SearchForFiles | Options::SearchForDirs);
        CHECK(filenames.empty());
    }
}

static void BuildTestData(const std::string &_root_path)
{
    Save(_root_path + "filename1.txt", "Hello, world!");
    Save(_root_path + "filename2.txt", reinterpret_cast<const char *>(u8"Привет, мир!"));
    MkDir(_root_path + "Dir");
    Save(_root_path + "Dir/filename3.txt", "Almost edge of the world!");
}

static bool Save(const std::string &_filepath, const std::string &_content)
{
    std::ofstream out(_filepath, std::ios::out | std::ios::binary);
    if( !out )
        return false;
    out << _content;
    out.close();
    return true;
}

static bool MkDir(const std::string &_dir_path)
{
    return mkdir(_dir_path.c_str(), S_IRWXU) != 0;
}
