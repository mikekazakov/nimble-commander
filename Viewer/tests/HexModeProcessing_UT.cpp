#include "Tests.h"
#include "TextModeWorkingSet.h"
#include "HexModeProcessing.h"
#include <Utility/Encodings.h>

using namespace nc::viewer;

static std::shared_ptr<const TextModeWorkingSet> ProduceWorkingSet(const char16_t *_chars,
                                                                   const int _chars_number,
                                                                   long _ws_offset = 0);

static std::shared_ptr<const TextModeWorkingSet> ProduceWorkingSet(const char *_chars,
                                                                   const int _chars_number,
                                                                   long _ws_offset = 0);

#define PREFIX "HexModeSplitter "
TEST_CASE(PREFIX"Verify a layout of a primitive 1-byte encoded string")
{
    const auto string = std::string{"Hello"};
    const auto ws = ProduceWorkingSet(string.data(), (int)string.length());
    HexModeSplitter::Source source;
    source.working_set = ws.get();
    SECTION("16-bytes columns") {
        source.bytes_per_row = 16;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE( lines.size() == 1 );
        CHECK( lines[0].chars_start == 0 );
        CHECK( lines[0].chars_num == 5 );
        CHECK( lines[0].row_bytes_start == 0 );
        CHECK( lines[0].row_bytes_num == 5 );
        CHECK( lines[0].string_bytes_start == 0 );
        CHECK( lines[0].string_bytes_num == 5 );
    }
    SECTION("0-byte columns") {
        source.bytes_per_row = 0;
        CHECK_THROWS( HexModeSplitter::Split(source) );
    }
    SECTION("1-byte columns") {
        source.bytes_per_row = 1;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE( lines.size() == 5 );
        CHECK( lines[0].chars_start == 0 );
        CHECK( lines[0].chars_num == 1 );
        CHECK( lines[0].row_bytes_start == 0 );
        CHECK( lines[0].row_bytes_num == 1 );
        CHECK( lines[0].string_bytes_start == 0 );
        CHECK( lines[0].string_bytes_num == 1 );
        CHECK( lines[1].chars_start == 1 );
        CHECK( lines[1].chars_num == 1 );
        CHECK( lines[1].row_bytes_start == 1 );
        CHECK( lines[1].row_bytes_num == 1 );
        CHECK( lines[1].string_bytes_start == 1 );
        CHECK( lines[1].string_bytes_num == 1 );
        CHECK( lines[2].chars_start == 2 );
        CHECK( lines[2].chars_num == 1 );
        CHECK( lines[2].row_bytes_start == 2 );
        CHECK( lines[2].row_bytes_num == 1 );
        CHECK( lines[2].string_bytes_start == 2 );
        CHECK( lines[2].string_bytes_num == 1 );
        CHECK( lines[3].chars_start == 3 );
        CHECK( lines[3].chars_num == 1 );
        CHECK( lines[3].row_bytes_start == 3 );
        CHECK( lines[3].row_bytes_num == 1 );
        CHECK( lines[3].string_bytes_start == 3 );
        CHECK( lines[3].string_bytes_num == 1 );
        CHECK( lines[4].chars_start == 4 );
        CHECK( lines[4].chars_num == 1 );
        CHECK( lines[4].row_bytes_start == 4 );
        CHECK( lines[4].row_bytes_num == 1 );
        CHECK( lines[4].string_bytes_start == 4 );
        CHECK( lines[4].string_bytes_num == 1 );
    }
    SECTION("2-byte columns") {
        source.bytes_per_row = 2;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE( lines.size() == 3 );
        CHECK( lines[0].chars_start == 0 );
        CHECK( lines[0].chars_num == 2 );
        CHECK( lines[0].row_bytes_start == 0 );
        CHECK( lines[0].row_bytes_num == 2 );
        CHECK( lines[0].string_bytes_start == 0 );
        CHECK( lines[0].string_bytes_num == 2 );
        CHECK( lines[1].chars_start == 2 );
        CHECK( lines[1].chars_num == 2 );
        CHECK( lines[1].row_bytes_start == 2 );
        CHECK( lines[1].row_bytes_num == 2 );
        CHECK( lines[1].string_bytes_start == 2 );
        CHECK( lines[1].string_bytes_num == 2 );
        CHECK( lines[2].chars_start == 4 );
        CHECK( lines[2].chars_num == 1 );
        CHECK( lines[2].row_bytes_start == 4 );
        CHECK( lines[2].row_bytes_num == 1 );
        CHECK( lines[2].string_bytes_start == 4 );
        CHECK( lines[2].string_bytes_num == 1 );
    }
}

#define PREFIX "HexModeSplitter "
TEST_CASE(PREFIX"Verify a layout of a primitive 1-byte encoded string in a shifted working set")
{
    const auto string = std::string{"Hello"};
    const auto ws = ProduceWorkingSet(string.data(), (int)string.length(), 14);
    HexModeSplitter::Source source;
    source.working_set = ws.get();
    SECTION("16-bytes columns") {
        source.bytes_per_row = 16;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE( lines.size() == 2 );
        CHECK( lines[0].chars_start == 0 );
        CHECK( lines[0].chars_num == 2 );
        CHECK( lines[0].row_bytes_start == 0 );
        CHECK( lines[0].row_bytes_num == 2 );
        CHECK( lines[0].string_bytes_start == 0 );
        CHECK( lines[0].string_bytes_num == 2 );
        CHECK( lines[1].chars_start == 2 );
        CHECK( lines[1].chars_num == 3 );
        CHECK( lines[1].row_bytes_start == 2 );
        CHECK( lines[1].row_bytes_num == 3 );
        CHECK( lines[1].string_bytes_start == 2 );
        CHECK( lines[1].string_bytes_num == 3 );
    }
    SECTION("5-bytes columns") {
        source.bytes_per_row = 2;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE( lines.size() == 3 );
        CHECK( lines[0].chars_start == 0 );
        CHECK( lines[0].chars_num == 2 );
        CHECK( lines[0].row_bytes_start == 0 );
        CHECK( lines[0].row_bytes_num == 2 );
        CHECK( lines[0].string_bytes_start == 0 );
        CHECK( lines[0].string_bytes_num == 2 );
        CHECK( lines[1].chars_start == 2 );
        CHECK( lines[1].chars_num == 2 );
        CHECK( lines[1].row_bytes_start == 2 );
        CHECK( lines[1].row_bytes_num == 2 );
        CHECK( lines[1].string_bytes_start == 2 );
        CHECK( lines[1].string_bytes_num == 2 );
        CHECK( lines[2].chars_start == 4 );
        CHECK( lines[2].chars_num == 1 );
        CHECK( lines[2].row_bytes_start == 4 );
        CHECK( lines[2].row_bytes_num == 1 );
        CHECK( lines[2].string_bytes_start == 4 );
        CHECK( lines[2].string_bytes_num == 1 );
    }
}

#define PREFIX "HexModeSplitter "
TEST_CASE(PREFIX"Verify a layout of a primitive utf8 encoded string")
{
    const auto string = std::string{u8"Привет"};
    const auto ws = ProduceWorkingSet(string.data(), (int)string.length());
    HexModeSplitter::Source source;
    source.working_set = ws.get();
    SECTION("16-bytes columns") {
        source.bytes_per_row = 16;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE( lines.size() == 1 );
        CHECK( lines[0].chars_start == 0 );
        CHECK( lines[0].chars_num == 6 );
        CHECK( lines[0].row_bytes_start == 0 );
        CHECK( lines[0].row_bytes_num == 12 );
        CHECK( lines[0].string_bytes_start == 0 );
        CHECK( lines[0].string_bytes_num == 12 );
    }
    SECTION("6-bytes columns") {
        source.bytes_per_row = 6;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE( lines.size() == 2 );
        CHECK( lines[0].chars_start == 0 );
        CHECK( lines[0].chars_num == 3 );
        CHECK( lines[0].row_bytes_start == 0 );
        CHECK( lines[0].row_bytes_num == 6 );
        CHECK( lines[0].string_bytes_start == 0 );
        CHECK( lines[0].string_bytes_num == 6 );
        CHECK( lines[1].chars_start == 3 );
        CHECK( lines[1].chars_num == 3 );
        CHECK( lines[1].row_bytes_start == 6 );
        CHECK( lines[1].row_bytes_num == 6 );
        CHECK( lines[1].string_bytes_start == 6 );
        CHECK( lines[1].string_bytes_num == 6 );
    }
    SECTION("7-bytes columns") {
        source.bytes_per_row = 7;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE( lines.size() == 2 );
        CHECK( lines[0].chars_start == 0 );
        CHECK( lines[0].chars_num == 4 );
        CHECK( lines[0].row_bytes_start == 0 );
        CHECK( lines[0].row_bytes_num == 7 );
        CHECK( lines[0].string_bytes_start == 0 );
        CHECK( lines[0].string_bytes_num == 8 );
        CHECK( lines[1].chars_start == 4 );
        CHECK( lines[1].chars_num == 2 );
        CHECK( lines[1].row_bytes_start == 7 );
        CHECK( lines[1].row_bytes_num == 5 );
        CHECK( lines[1].string_bytes_start == 8 );
        CHECK( lines[1].string_bytes_num == 4 );
    }
}

#define PREFIX "HexModeSplitter "
TEST_CASE(PREFIX"Verify a layout of a utf8 encoded string with mixed lengths")
{
    const auto string = std::string{u8"NцQф"};
    const auto ws = ProduceWorkingSet(string.data(), (int)string.length());
    HexModeSplitter::Source source;
    source.working_set = ws.get();
    SECTION("2-byte columns") {
        source.bytes_per_row = 2;
        const auto lines = HexModeSplitter::Split(source);
        REQUIRE( lines.size() == 3 );
        CHECK( lines[0].chars_start == 0 ); // "Nц"
        CHECK( lines[0].chars_num == 2 );
        CHECK( lines[0].row_bytes_start == 0 );
        CHECK( lines[0].row_bytes_num == 2 );
        CHECK( lines[0].string_bytes_start == 0 );
        CHECK( lines[0].string_bytes_num == 3 );
        CHECK( lines[1].chars_start == 2 ); // "Q"
        CHECK( lines[1].chars_num == 1 );
        CHECK( lines[1].row_bytes_start == 2 );
        CHECK( lines[1].row_bytes_num == 2 );
        CHECK( lines[1].string_bytes_start == 3 );
        CHECK( lines[1].string_bytes_num == 1 );
        CHECK( lines[2].chars_start == 3 ); // ф
        CHECK( lines[2].chars_num == 1 );
        CHECK( lines[2].row_bytes_start == 4 );
        CHECK( lines[2].row_bytes_num == 2 );
        CHECK( lines[2].string_bytes_start == 4 );
        CHECK( lines[2].string_bytes_num == 2 );
    }
}

[[maybe_unused]]
static std::shared_ptr<const TextModeWorkingSet> ProduceWorkingSet(const char16_t *_chars,
                                                                   const int _chars_number,
                                                                   long _ws_offset)
{
    std::vector<int> offsets(_chars_number, 0);
    std::generate(offsets.begin(), offsets.end(), [offset=-2] () mutable { return offset+=2; });
    TextModeWorkingSet::Source source;
    source.unprocessed_characters = _chars;
    source.mapping_to_byte_offsets = offsets.data();
    source.characters_number = _chars_number;
    source.bytes_offset = _ws_offset;
    source.bytes_offset = _chars_number * 2;
    return std::make_shared<TextModeWorkingSet>(source);
}

static std::shared_ptr<const TextModeWorkingSet> ProduceWorkingSet(const char *_chars,
                                                                   const int _chars_number,
                                                                   long _ws_offset)
{
    auto utf16_chars = std::make_unique<unsigned short[]>( _chars_number );
    auto utf16_chars_offsets = std::make_unique<unsigned[]>( _chars_number );
    size_t utf16_length = 0;
    encodings::InterpretAsUnichar(encodings::ENCODING_UTF8,
                                  (const unsigned char*)_chars,
                                  _chars_number,
                                  utf16_chars.get(),
                                  utf16_chars_offsets.get(),
                                  &utf16_length);
    auto source = TextModeWorkingSet::Source{};
    source.unprocessed_characters = (const char16_t*)utf16_chars.get();
    source.mapping_to_byte_offsets = (const int*)utf16_chars_offsets.get();
    source.characters_number = (int)utf16_length;
    source.bytes_offset = _ws_offset;
    source.bytes_length = (int)_chars_number;
    return std::make_shared<TextModeWorkingSet>(source);
}
