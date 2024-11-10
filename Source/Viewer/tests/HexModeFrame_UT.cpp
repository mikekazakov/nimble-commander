// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TextModeWorkingSet.h"
#include "HexModeProcessing.h"
#include "HexModeFrame.h"
#include <Utility/Encodings.h>
#include <Base/algo.h>

#include <algorithm>

using namespace nc::viewer;

static std::shared_ptr<const TextModeWorkingSet>
ProduceWorkingSet(const char16_t *_chars, int _chars_number, long _ws_offset = 0);

static std::shared_ptr<const TextModeWorkingSet>
ProduceWorkingSet(const char *_chars, int _chars_number, long _ws_offset = 0);

static bool Equal(CFStringRef _lhs, CFStringRef _rhs);

#define PREFIX "HexModeFrame "

TEST_CASE(PREFIX "Verify RowsBuilder against Hello, World!")
{
    const auto string = std::string{reinterpret_cast<const char *>(u8"Hello, World!")};
    const auto ws = ProduceWorkingSet(string.data(), static_cast<int>(string.length()));
    const auto font = CTFontCreateWithName(CFSTR("Menlo-Regular"), 13., nullptr);
    const auto release_font = at_scope_end([&] { CFRelease(font); });
    HexModeFrame::Source source;
    source.working_set = ws;
    source.raw_bytes_begin = reinterpret_cast<const std::byte *>(string.data());
    source.raw_bytes_end = reinterpret_cast<const std::byte *>(string.data()) + string.size();
    source.font = font;
    source.font_info = nc::utility::FontGeometryInfo{font};
    source.foreground_color = CGColorGetConstantColor(kCGColorBlack);
    source.digits_in_address = 6;
    SECTION("8 bytes per column, 2 columns")
    {
        source.bytes_per_column = 8;
        source.number_of_columns = 2;
        const HexModeFrame::RowsBuilder builder(source);
        const auto row = builder.Build(std::make_pair(0, 13), std::make_pair(0, 13), std::make_pair(0, 13));
        REQUIRE(row.ColumnsNumber() == 2);
        CHECK(Equal(row.AddressString(), CFSTR("000000")));
        CHECK(Equal(row.SnippetString(), CFSTR("Hello, World!")));
        CHECK(Equal(row.ColumnString(0), CFSTR("48 65 6C 6C 6F 2C 20 57")));
        CHECK(Equal(row.ColumnString(1), CFSTR("6F 72 6C 64 21")));
    }
    SECTION("4 bytes per column, 4 columns")
    {
        source.bytes_per_column = 4;
        source.number_of_columns = 4;
        const HexModeFrame::RowsBuilder builder(source);
        const auto row = builder.Build(std::make_pair(0, 13), std::make_pair(0, 13), std::make_pair(0, 13));
        REQUIRE(row.ColumnsNumber() == 4);
        CHECK(Equal(row.AddressString(), CFSTR("000000")));
        CHECK(Equal(row.SnippetString(), CFSTR("Hello, World!")));
        CHECK(Equal(row.ColumnString(0), CFSTR("48 65 6C 6C")));
        CHECK(Equal(row.ColumnString(1), CFSTR("6F 2C 20 57")));
        CHECK(Equal(row.ColumnString(2), CFSTR("6F 72 6C 64")));
        CHECK(Equal(row.ColumnString(3), CFSTR("21")));
    }
    SECTION("4 bytes per column, 2 columns, 1st row")
    {
        source.bytes_per_column = 4;
        source.number_of_columns = 2;
        const HexModeFrame::RowsBuilder builder(source);
        const auto row = builder.Build(std::make_pair(0, 8), std::make_pair(0, 8), std::make_pair(0, 8));
        REQUIRE(row.ColumnsNumber() == 2);
        CHECK(Equal(row.AddressString(), CFSTR("000000")));
        CHECK(Equal(row.SnippetString(), CFSTR("Hello, W")));
        CHECK(Equal(row.ColumnString(0), CFSTR("48 65 6C 6C")));
        CHECK(Equal(row.ColumnString(1), CFSTR("6F 2C 20 57")));
    }
    SECTION("4 bytes per column, 2 columns, 2nd row")
    {
        source.bytes_per_column = 4;
        source.number_of_columns = 2;
        const HexModeFrame::RowsBuilder builder(source);
        const auto row = builder.Build(std::make_pair(8, 5), std::make_pair(8, 5), std::make_pair(8, 5));
        REQUIRE(row.ColumnsNumber() == 2);
        CHECK(Equal(row.AddressString(), CFSTR("000008")));
        CHECK(Equal(row.SnippetString(), CFSTR("orld!")));
        CHECK(Equal(row.ColumnString(0), CFSTR("6F 72 6C 64")));
        CHECK(Equal(row.ColumnString(1), CFSTR("21")));
    }
}

[[maybe_unused]] static std::shared_ptr<const TextModeWorkingSet>
ProduceWorkingSet(const char16_t *_chars, const int _chars_number, long _ws_offset)
{
    std::vector<int> offsets(_chars_number, 0);
    std::ranges::generate(offsets, [offset = -2]() mutable { return offset += 2; });
    TextModeWorkingSet::Source source;
    source.unprocessed_characters = _chars;
    source.mapping_to_byte_offsets = offsets.data();
    source.characters_number = _chars_number;
    source.bytes_offset = _ws_offset;
    source.bytes_offset = static_cast<long>(_chars_number) * 2l;
    return std::make_shared<TextModeWorkingSet>(source);
}

static std::shared_ptr<const TextModeWorkingSet>
ProduceWorkingSet(const char *_chars, const int _chars_number, long _ws_offset)
{
    auto utf16_chars = std::make_unique<unsigned short[]>(_chars_number);
    auto utf16_chars_offsets = std::make_unique<unsigned[]>(_chars_number);
    size_t utf16_length = 0;
    nc::utility::InterpretAsUnichar(nc::utility::Encoding::ENCODING_UTF8,
                                    reinterpret_cast<const unsigned char *>(_chars),
                                    _chars_number,
                                    utf16_chars.get(),
                                    utf16_chars_offsets.get(),
                                    &utf16_length);
    auto source = TextModeWorkingSet::Source{};
    source.unprocessed_characters = reinterpret_cast<const char16_t *>(utf16_chars.get());
    source.mapping_to_byte_offsets = reinterpret_cast<const int *>(utf16_chars_offsets.get());
    source.characters_number = static_cast<int>(utf16_length);
    source.bytes_offset = _ws_offset;
    source.bytes_length = static_cast<int>(_chars_number);
    return std::make_shared<TextModeWorkingSet>(source);
}

static bool Equal(CFStringRef _lhs, CFStringRef _rhs)
{
    return CFStringCompare(_lhs, _rhs, 0) == kCFCompareEqualTo;
}
