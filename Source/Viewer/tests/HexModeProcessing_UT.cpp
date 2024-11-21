// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TextModeWorkingSet.h"
#include "HexModeProcessing.h"
#include <Utility/Encodings.h>

#include <algorithm>

using namespace nc::viewer;

static std::shared_ptr<const TextModeWorkingSet>
ProduceWorkingSet(const char16_t *_chars, int _chars_number, long _ws_offset = 0);

static std::shared_ptr<const TextModeWorkingSet>
ProduceWorkingSet(const char *_chars, int _chars_number, long _ws_offset = 0);

static bool Equal(CFStringRef _lhs, CFStringRef _rhs);

#define PREFIX "HexModeSplitter "

TEST_CASE(PREFIX "Verify a layout of a primitive 1-byte encoded string")
{
    const auto string = std::string{"Hello"};
    const auto ws = ProduceWorkingSet(string.data(), static_cast<int>(string.length()));
    HexModeSplitter::Source source;
    source.working_set = ws.get();
    SECTION("16-bytes columns")
    {
        source.bytes_per_row = 16;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE(lines.size() == 1);
        CHECK(lines[0].chars_start == 0);
        CHECK(lines[0].chars_num == 5);
        CHECK(lines[0].row_bytes_start == 0);
        CHECK(lines[0].row_bytes_num == 5);
        CHECK(lines[0].string_bytes_start == 0);
        CHECK(lines[0].string_bytes_num == 5);
    }
    SECTION("0-byte columns")
    {
        source.bytes_per_row = 0;
        CHECK_THROWS(HexModeSplitter::Split(source));
    }
    SECTION("1-byte columns")
    {
        source.bytes_per_row = 1;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE(lines.size() == 5);
        CHECK(lines[0].chars_start == 0);
        CHECK(lines[0].chars_num == 1);
        CHECK(lines[0].row_bytes_start == 0);
        CHECK(lines[0].row_bytes_num == 1);
        CHECK(lines[0].string_bytes_start == 0);
        CHECK(lines[0].string_bytes_num == 1);
        CHECK(lines[1].chars_start == 1);
        CHECK(lines[1].chars_num == 1);
        CHECK(lines[1].row_bytes_start == 1);
        CHECK(lines[1].row_bytes_num == 1);
        CHECK(lines[1].string_bytes_start == 1);
        CHECK(lines[1].string_bytes_num == 1);
        CHECK(lines[2].chars_start == 2);
        CHECK(lines[2].chars_num == 1);
        CHECK(lines[2].row_bytes_start == 2);
        CHECK(lines[2].row_bytes_num == 1);
        CHECK(lines[2].string_bytes_start == 2);
        CHECK(lines[2].string_bytes_num == 1);
        CHECK(lines[3].chars_start == 3);
        CHECK(lines[3].chars_num == 1);
        CHECK(lines[3].row_bytes_start == 3);
        CHECK(lines[3].row_bytes_num == 1);
        CHECK(lines[3].string_bytes_start == 3);
        CHECK(lines[3].string_bytes_num == 1);
        CHECK(lines[4].chars_start == 4);
        CHECK(lines[4].chars_num == 1);
        CHECK(lines[4].row_bytes_start == 4);
        CHECK(lines[4].row_bytes_num == 1);
        CHECK(lines[4].string_bytes_start == 4);
        CHECK(lines[4].string_bytes_num == 1);
    }
    SECTION("2-byte columns")
    {
        source.bytes_per_row = 2;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE(lines.size() == 3);
        CHECK(lines[0].chars_start == 0);
        CHECK(lines[0].chars_num == 2);
        CHECK(lines[0].row_bytes_start == 0);
        CHECK(lines[0].row_bytes_num == 2);
        CHECK(lines[0].string_bytes_start == 0);
        CHECK(lines[0].string_bytes_num == 2);
        CHECK(lines[1].chars_start == 2);
        CHECK(lines[1].chars_num == 2);
        CHECK(lines[1].row_bytes_start == 2);
        CHECK(lines[1].row_bytes_num == 2);
        CHECK(lines[1].string_bytes_start == 2);
        CHECK(lines[1].string_bytes_num == 2);
        CHECK(lines[2].chars_start == 4);
        CHECK(lines[2].chars_num == 1);
        CHECK(lines[2].row_bytes_start == 4);
        CHECK(lines[2].row_bytes_num == 1);
        CHECK(lines[2].string_bytes_start == 4);
        CHECK(lines[2].string_bytes_num == 1);
    }
}

TEST_CASE(PREFIX "Verify a layout of a primitive 1-byte encoded string in a shifted working set")
{
    const auto string = std::string{"Hello"};
    const auto ws = ProduceWorkingSet(string.data(), static_cast<int>(string.length()), 14);
    HexModeSplitter::Source source;
    source.working_set = ws.get();
    SECTION("16-bytes columns")
    {
        source.bytes_per_row = 16;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE(lines.size() == 2);
        CHECK(lines[0].chars_start == 0);
        CHECK(lines[0].chars_num == 2);
        CHECK(lines[0].row_bytes_start == 0);
        CHECK(lines[0].row_bytes_num == 2);
        CHECK(lines[0].string_bytes_start == 0);
        CHECK(lines[0].string_bytes_num == 2);
        CHECK(lines[1].chars_start == 2);
        CHECK(lines[1].chars_num == 3);
        CHECK(lines[1].row_bytes_start == 2);
        CHECK(lines[1].row_bytes_num == 3);
        CHECK(lines[1].string_bytes_start == 2);
        CHECK(lines[1].string_bytes_num == 3);
    }
    SECTION("5-bytes columns")
    {
        source.bytes_per_row = 2;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE(lines.size() == 3);
        CHECK(lines[0].chars_start == 0);
        CHECK(lines[0].chars_num == 2);
        CHECK(lines[0].row_bytes_start == 0);
        CHECK(lines[0].row_bytes_num == 2);
        CHECK(lines[0].string_bytes_start == 0);
        CHECK(lines[0].string_bytes_num == 2);
        CHECK(lines[1].chars_start == 2);
        CHECK(lines[1].chars_num == 2);
        CHECK(lines[1].row_bytes_start == 2);
        CHECK(lines[1].row_bytes_num == 2);
        CHECK(lines[1].string_bytes_start == 2);
        CHECK(lines[1].string_bytes_num == 2);
        CHECK(lines[2].chars_start == 4);
        CHECK(lines[2].chars_num == 1);
        CHECK(lines[2].row_bytes_start == 4);
        CHECK(lines[2].row_bytes_num == 1);
        CHECK(lines[2].string_bytes_start == 4);
        CHECK(lines[2].string_bytes_num == 1);
    }
}

TEST_CASE(PREFIX "Verify a layout of a primitive utf8 encoded string")
{
    const auto string = std::string{reinterpret_cast<const char *>(u8"Привет")};
    const auto ws = ProduceWorkingSet(string.data(), static_cast<int>(string.length()));
    HexModeSplitter::Source source;
    source.working_set = ws.get();
    SECTION("16-bytes rows")
    {
        source.bytes_per_row = 16;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE(lines.size() == 1);
        CHECK(lines[0].chars_start == 0);
        CHECK(lines[0].chars_num == 6);
        CHECK(lines[0].row_bytes_start == 0);
        CHECK(lines[0].row_bytes_num == 12);
        CHECK(lines[0].string_bytes_start == 0);
        CHECK(lines[0].string_bytes_num == 12);
    }
    SECTION("6-bytes rows")
    {
        source.bytes_per_row = 6;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE(lines.size() == 2);
        CHECK(lines[0].chars_start == 0);
        CHECK(lines[0].chars_num == 3);
        CHECK(lines[0].row_bytes_start == 0);
        CHECK(lines[0].row_bytes_num == 6);
        CHECK(lines[0].string_bytes_start == 0);
        CHECK(lines[0].string_bytes_num == 6);
        CHECK(lines[1].chars_start == 3);
        CHECK(lines[1].chars_num == 3);
        CHECK(lines[1].row_bytes_start == 6);
        CHECK(lines[1].row_bytes_num == 6);
        CHECK(lines[1].string_bytes_start == 6);
        CHECK(lines[1].string_bytes_num == 6);
    }
    SECTION("7-bytes rows")
    {
        source.bytes_per_row = 7;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE(lines.size() == 2);
        CHECK(lines[0].chars_start == 0);
        CHECK(lines[0].chars_num == 4);
        CHECK(lines[0].row_bytes_start == 0);
        CHECK(lines[0].row_bytes_num == 7);
        CHECK(lines[0].string_bytes_start == 0);
        CHECK(lines[0].string_bytes_num == 8);
        CHECK(lines[1].chars_start == 4);
        CHECK(lines[1].chars_num == 2);
        CHECK(lines[1].row_bytes_start == 7);
        CHECK(lines[1].row_bytes_num == 5);
        CHECK(lines[1].string_bytes_start == 8);
        CHECK(lines[1].string_bytes_num == 4);
    }
}

TEST_CASE(PREFIX "Verify a layout of a utf8 encoded string with mixed lengths")
{
    const auto string = std::string{reinterpret_cast<const char *>(u8"NцQф")};
    const auto ws = ProduceWorkingSet(string.data(), static_cast<int>(string.length()));
    HexModeSplitter::Source source;
    source.working_set = ws.get();
    SECTION("2-byte rows")
    {
        source.bytes_per_row = 2;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE(lines.size() == 3);
        CHECK(lines[0].chars_start == 0); // "Nц"
        CHECK(lines[0].chars_num == 2);
        CHECK(lines[0].row_bytes_start == 0);
        CHECK(lines[0].row_bytes_num == 2);
        CHECK(lines[0].string_bytes_start == 0);
        CHECK(lines[0].string_bytes_num == 3);
        CHECK(lines[1].chars_start == 2); // "Q"
        CHECK(lines[1].chars_num == 1);
        CHECK(lines[1].row_bytes_start == 2);
        CHECK(lines[1].row_bytes_num == 2);
        CHECK(lines[1].string_bytes_start == 3);
        CHECK(lines[1].string_bytes_num == 1);
        CHECK(lines[2].chars_start == 3); // ф
        CHECK(lines[2].chars_num == 1);
        CHECK(lines[2].row_bytes_start == 4);
        CHECK(lines[2].row_bytes_num == 2);
        CHECK(lines[2].string_bytes_start == 4);
        CHECK(lines[2].string_bytes_num == 2);
    }
}

TEST_CASE(PREFIX "Check address conversion: no offsets")
{
    const int row_bytes_start = 0;
    const long working_set_offset = 0;
    SECTION("8 digits, 16 bytes per row")
    {
        const auto string = HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 16, 8);
        CHECK(Equal(string.get(), CFSTR("00000000")));
    }
    SECTION("1 digit, 16 bytes per row")
    {
        const auto string = HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 16, 1);
        CHECK(Equal(string.get(), CFSTR("0")));
    }
    SECTION("0 digits, 16 bytes per row")
    {
        const auto string = HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 16, 0);
        CHECK(Equal(string.get(), CFSTR("")));
    }
    SECTION("-1 digits, 16 bytes per row")
    {
        CHECK_THROWS(HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 16, -1));
    }
}

TEST_CASE(PREFIX "Check address conversion: row_offset=123456")
{
    const int row_bytes_start = 123456;
    const long working_set_offset = 0;
    SECTION("8 digits, 16 bytes per row")
    {
        const auto string = HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 16, 8);
        CHECK(Equal(string.get(), CFSTR("0001E240")));
    }
    SECTION("3 digits, 16 bytes per row")
    {
        const auto string = HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 16, 3);
        CHECK(Equal(string.get(), CFSTR("240")));
    }

    SECTION("1 digit, 16 bytes per row")
    {
        const auto string = HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 16, 1);
        CHECK(Equal(string.get(), CFSTR("0")));
    }
}

TEST_CASE(PREFIX "Check address conversion: row_offset=123450")
{
    const int row_bytes_start = 123450;
    const long working_set_offset = 0;
    const auto string = HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 16, 8);
    CHECK(Equal(string.get(), CFSTR("0001E230")));
}

TEST_CASE(PREFIX "Check address conversion: row_offset=50, ws_offset=50")
{
    const int row_bytes_start = 50;
    const long working_set_offset = 50;
    SECTION("4 digits, 16 bytes per row")
    {
        const auto string = HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 16, 4);
        CHECK(Equal(string.get(), CFSTR("0060")));
    }
    SECTION("4 digits, 10 bytes per row")
    {
        const auto string = HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 10, 4);
        CHECK(Equal(string.get(), CFSTR("0064")));
    }
    SECTION("4 digits, 8 bytes per row")
    {
        const auto string = HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 8, 4);
        CHECK(Equal(string.get(), CFSTR("0060")));
    }
    SECTION("4 digits, 24 bytes per row")
    {
        const auto string = HexModeSplitter::MakeAddressString(row_bytes_start, working_set_offset, 24, 4);
        CHECK(Equal(string.get(), CFSTR("0060")));
    }
}

TEST_CASE(PREFIX "Check hex conversions")
{
    SECTION("Hello, World!")
    {
        const auto data = std::string("Hello, World!");
        const auto hex =
            HexModeSplitter::MakeBytesHexString(reinterpret_cast<const std::byte *>(data.data()),
                                                reinterpret_cast<const std::byte *>(data.data()) + data.size());
        CHECK(Equal(hex.get(), CFSTR("48 65 6C 6C 6F 2C 20 57 6F 72 6C 64 21")));
    }
    SECTION("Hello, World!, . separator")
    {
        const auto data = std::string("Hello, World!");
        const auto hex =
            HexModeSplitter::MakeBytesHexString(reinterpret_cast<const std::byte *>(data.data()),
                                                reinterpret_cast<const std::byte *>(data.data()) + data.size(),
                                                '.');
        CHECK(Equal(hex.get(), CFSTR("48.65.6C.6C.6F.2C.20.57.6F.72.6C.64.21")));
    }
    SECTION("Empty data")
    {
        const auto data = std::byte{};
        const auto hex = HexModeSplitter::MakeBytesHexString(&data, &data);
        CHECK(Equal(hex.get(), CFSTR("")));
    }
    SECTION("Single byte")
    {
        const auto data = std::byte{255};
        const auto hex = HexModeSplitter::MakeBytesHexString(&data, &data + 1);
        CHECK(Equal(hex.get(), CFSTR("FF")));
    }
    SECTION("Doesn't crash on 16 megabytes")
    {
        // NOLINTBEGIN(bugprone-string-constructor)
        const auto data = std::string(16'000'000, ' ');
        // NOLINTEND(bugprone-string-constructor)
        const auto hex =
            HexModeSplitter::MakeBytesHexString(reinterpret_cast<const std::byte *>(data.data()),
                                                reinterpret_cast<const std::byte *>(data.data()) + data.size());
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
