// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "SearchInFile.h"
#include "VFSGenericMemReadOnlyFile.h"
#include <Utility/Encodings.h>
#include <Utility/StringExtras.h>
#include <Base/CFString.h>

using namespace nc::base;
using nc::utility::Encoding;
using nc::vfs::FileWindow;
using nc::vfs::GenericMemReadOnlyFile;
using nc::vfs::SearchInFile;
#define PREFIX "[nc::vfs::SearchInFile] "

static FileWindow MakeFileWindow(std::string_view _data);

TEST_CASE(PREFIX "Throws if FileWindow is not open")
{
    FileWindow fw;
    CHECK_THROWS(SearchInFile{fw});
}

TEST_CASE(PREFIX "Doesn't search for empty strings")
{
    auto fw = MakeFileWindow("some string data");
    auto search = SearchInFile{fw};
    search.ToggleTextSearch(CFSTR(""), Encoding::ENCODING_UTF8);
    const auto result = search.Search();
    CHECK(result.response != SearchInFile::Response::Found);
}

TEST_CASE(PREFIX "Does simple search")
{
    auto fw = MakeFileWindow("0123456789hello56789");
    auto search = SearchInFile{fw};

    SECTION("Search for 0123")
    {
        search.ToggleTextSearch(CFSTR("0123"), Encoding::ENCODING_UTF8);

        const auto result = search.Search();
        REQUIRE(result.response == SearchInFile::Response::Found);
        CHECK(result.location->offset == 0);
        CHECK(result.location->bytes_len == 4);
    }
    SECTION("Search for hello")
    {
        search.ToggleTextSearch(CFSTR("hello"), Encoding::ENCODING_UTF8);

        const auto result = search.Search();
        REQUIRE(result.response == SearchInFile::Response::Found);
        CHECK(result.location->offset == 10);
        CHECK(result.location->bytes_len == 5);
    }
    SECTION("Search for HELLO")
    {
        search.ToggleTextSearch(CFSTR("HELLO"), Encoding::ENCODING_UTF8);

        const auto result = search.Search();
        REQUIRE(result.response == SearchInFile::Response::Found);
        CHECK(result.location->offset == 10);
        CHECK(result.location->bytes_len == 5);
    }
    SECTION("Search for 56789 twice")
    {
        search.ToggleTextSearch(CFSTR("56789"), Encoding::ENCODING_UTF8);

        const auto result1 = search.Search();
        REQUIRE(result1.response == SearchInFile::Response::Found);
        CHECK(result1.location->offset == 5);
        CHECK(result1.location->bytes_len == 5);

        const auto result2 = search.Search();
        REQUIRE(result2.response == SearchInFile::Response::Found);
        CHECK(result2.location->offset == 15);
        CHECK(result2.location->bytes_len == 5);
    }
    SECTION("Search for 9 twice")
    {
        search.ToggleTextSearch(CFSTR("9"), Encoding::ENCODING_UTF8);

        const auto result1 = search.Search();
        REQUIRE(result1.response == SearchInFile::Response::Found);
        CHECK(result1.location->offset == 9);
        CHECK(result1.location->bytes_len == 1);

        const auto result2 = search.Search();
        REQUIRE(result2.response == SearchInFile::Response::Found);
        CHECK(result2.location->offset == 19);
        CHECK(result2.location->bytes_len == 1);
    }
}

TEST_CASE(PREFIX "Does search for text which is outside of file window size")
{
    const auto window_size = FileWindow::DefaultWindowSize;
    const auto hello_offset = 10 * window_size;
    std::string memory;
    memory.resize(hello_offset, ' ');
    memory += "hello";

    auto fw = MakeFileWindow(memory);
    auto search = SearchInFile{fw};
    search.ToggleTextSearch(CFSTR("hello"), Encoding::ENCODING_UTF8);

    const auto result = search.Search();
    REQUIRE(result.response == SearchInFile::Response::Found);
    CHECK(result.location->offset == hello_offset);
    CHECK(result.location->bytes_len == 5);
}

TEST_CASE(PREFIX "Can search for non-ANSI characters")
{
    SECTION("Aligned (even) position")
    {
        auto fw = MakeFileWindow(reinterpret_cast<const char *>(u8"0123456789привет"));
        auto search = SearchInFile{fw};
        const auto cf_string = CFString(reinterpret_cast<const char *>(u8"привет"));
        search.ToggleTextSearch(*cf_string, Encoding::ENCODING_UTF8);
        const auto result = search.Search();
        REQUIRE(result.response == SearchInFile::Response::Found);
        CHECK(result.location->offset == 10);
        CHECK(result.location->bytes_len == 12);
    }
    SECTION("Random (non-even) position")
    {
        auto fw = MakeFileWindow(reinterpret_cast<const char *>(u8"01234567890привет"));
        auto search = SearchInFile{fw};
        const auto cf_string = CFString(reinterpret_cast<const char *>(u8"привет"));
        search.ToggleTextSearch(*cf_string, Encoding::ENCODING_UTF8);
        const auto result = search.Search();
        REQUIRE(result.response == SearchInFile::Response::Found);
        CHECK(result.location->offset == 11);
        CHECK(result.location->bytes_len == 12);
    }
}

// TODO: mock a vfs file instead?
TEST_CASE(PREFIX "Can search for text located beyond 32bit boundary")
{
    const auto hello_offset = uint64_t{std::numeric_limits<int>::max()} + 4242;
    const auto memory = std::string(hello_offset, ' ') + "hello";
    auto fw = MakeFileWindow(memory);
    auto search = SearchInFile{fw};
    search.MoveCurrentPosition(hello_offset - 100);
    search.ToggleTextSearch(CFSTR("hello"), Encoding::ENCODING_MACOS_ROMAN_WESTERN);
    const auto result = search.Search();
    REQUIRE(result.response == SearchInFile::Response::Found);
    CHECK(result.location->offset == hello_offset);
    CHECK(result.location->bytes_len == 5);
}

TEST_CASE(PREFIX "Handles case the sensitivity flag")
{
    auto fw = MakeFileWindow(reinterpret_cast<const char *>(u8"0123456789привет"));
    auto search = SearchInFile{fw};

    SECTION("case insensitive - match")
    { // default option
        const auto cf_string = CFString(reinterpret_cast<const char *>(u8"привет"));
        search.ToggleTextSearch(*cf_string, Encoding::ENCODING_UTF8);
        const auto result = search.Search();
        REQUIRE(result.response == SearchInFile::Response::Found);
    }
    SECTION("case insensitive - match")
    { // default option
        const auto cf_string = CFString(reinterpret_cast<const char *>(u8"ПРИВЕТ"));
        search.ToggleTextSearch(*cf_string, Encoding::ENCODING_UTF8);
        const auto result = search.Search();
        REQUIRE(result.response == SearchInFile::Response::Found);
    }
    SECTION("case sensitive - match")
    {
        const auto cf_string = CFString(reinterpret_cast<const char *>(u8"привет"));
        search.ToggleTextSearch(*cf_string, Encoding::ENCODING_UTF8);
        search.SetSearchOptions(SearchInFile::Options::CaseSensitive);
        const auto result = search.Search();
        REQUIRE(result.response == SearchInFile::Response::Found);
    }
    SECTION("case sensitive - no match")
    {
        const auto cf_string = CFString(reinterpret_cast<const char *>(u8"ПРИВЕТ"));
        search.ToggleTextSearch(*cf_string, Encoding::ENCODING_UTF8);
        search.SetSearchOptions(SearchInFile::Options::CaseSensitive);
        const auto result = search.Search();
        REQUIRE(result.response == SearchInFile::Response::NotFound);
    }
}

TEST_CASE(PREFIX "Handles case the whole phrase flag")
{
    auto fw = MakeFileWindow(reinterpret_cast<const char *>(u8"0123456789hello, hello"));
    auto search = SearchInFile{fw};
    SECTION("regardless")
    { // default option
        const auto cf_string = CFString(reinterpret_cast<const char *>(u8"hello"));
        search.ToggleTextSearch(*cf_string, Encoding::ENCODING_UTF8);
        const auto result = search.Search();
        REQUIRE(result.response == SearchInFile::Response::Found);
        CHECK(result.location->offset == 10);
        CHECK(result.location->bytes_len == 5);
    }
    SECTION("whole phrase")
    {
        const auto cf_string = CFString(reinterpret_cast<const char *>(u8"hello"));
        search.ToggleTextSearch(*cf_string, Encoding::ENCODING_UTF8);
        search.SetSearchOptions(SearchInFile::Options::FindWholePhrase);
        const auto result = search.Search();
        REQUIRE(result.response == SearchInFile::Response::Found);
        CHECK(result.location->offset == 17);
        CHECK(result.location->bytes_len == 5);
    }
}

static FileWindow MakeFileWindow(std::string_view _data)
{
    assert(_data.data() != nullptr);
    auto mem_file = std::make_shared<GenericMemReadOnlyFile>("", nullptr, _data);
    mem_file->Open(VFSFlags::OF_Read);
    return FileWindow{mem_file};
}
