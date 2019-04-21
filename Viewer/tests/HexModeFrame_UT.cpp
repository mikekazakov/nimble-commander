#include "Tests.h"
#include "TextModeWorkingSet.h"
#include "HexModeProcessing.h"
#include "HexModeFrame.h"
#include <Utility/Encodings.h>
#include <Habanero/algo.h>

using namespace nc::viewer;

static std::shared_ptr<const TextModeWorkingSet> ProduceWorkingSet(const char16_t *_chars,
                                                                   const int _chars_number,
                                                                   long _ws_offset = 0);

static std::shared_ptr<const TextModeWorkingSet> ProduceWorkingSet(const char *_chars,
                                                                   const int _chars_number,
                                                                   long _ws_offset = 0);

static bool Equal(CFStringRef _lhs, CFStringRef _rhs);

#define PREFIX "HexModeFrame "

TEST_CASE(PREFIX"Verify RowsBuilder against Hello, World!")
{
    const auto string = std::string{u8"Hello, World!"};
    const auto ws = ProduceWorkingSet(string.data(), (int)string.length());
    const auto font = CTFontCreateWithName(CFSTR("Menlo-Regular"), 13., nullptr);
    const auto release_font = at_scope_end([&]{ CFRelease(font); });
    HexModeFrame::Source frame_source;
    frame_source.working_set = ws;
    frame_source.font = font;
    frame_source.font_info = nc::utility::FontGeometryInfo{font};
    frame_source.foreground_color = CGColorGetConstantColor(kCGColorBlack);
    SECTION("8 bytes per column, 2 columns") {
        frame_source.bytes_per_column = 8;
        frame_source.number_of_columns = 2;
        HexModeFrame::RowsBuilder builder(frame_source,
                                          (const std::byte*)string.data(),
                                          (const std::byte*)string.data() + string.size(),
                                          6);
        const auto row = builder.Build(std::make_pair(0, 13),
                                       std::make_pair(0, 13),
                                       std::make_pair(0, 13));
        REQUIRE( row.ColumnsNumber() == 2 );
        CHECK( Equal(row.AddressString(), CFSTR("000000")) );
        CHECK( Equal(row.SnippetString(), CFSTR("Hello, World!")) );
        CHECK( Equal(row.ColumnString(0), CFSTR("48 65 6C 6C 6F 2C 20 57")) );
        CHECK( Equal(row.ColumnString(1), CFSTR("6F 72 6C 64 21")) );
    }
    SECTION("4 bytes per column, 4 columns") {
        frame_source.bytes_per_column = 4;
        frame_source.number_of_columns = 4;
        HexModeFrame::RowsBuilder builder(frame_source,
                                          (const std::byte*)string.data(),
                                          (const std::byte*)string.data() + string.size(),
                                          6);
        const auto row = builder.Build(std::make_pair(0, 13),
                                       std::make_pair(0, 13),
                                       std::make_pair(0, 13));
        REQUIRE( row.ColumnsNumber() == 4 );
        CHECK( Equal(row.AddressString(), CFSTR("000000")) );
        CHECK( Equal(row.SnippetString(), CFSTR("Hello, World!")) );
        CHECK( Equal(row.ColumnString(0), CFSTR("48 65 6C 6C")) );
        CHECK( Equal(row.ColumnString(1), CFSTR("6F 2C 20 57")) );
        CHECK( Equal(row.ColumnString(2), CFSTR("6F 72 6C 64")) );
        CHECK( Equal(row.ColumnString(3), CFSTR("21")) );
    }
    SECTION("4 bytes per column, 2 columns, 1st row") {
        frame_source.bytes_per_column = 4;
        frame_source.number_of_columns = 2;
        HexModeFrame::RowsBuilder builder(frame_source,
                                          (const std::byte*)string.data(),
                                          (const std::byte*)string.data() + string.size(),
                                          6);
        const auto row = builder.Build(std::make_pair(0, 8),
                                       std::make_pair(0, 8),
                                       std::make_pair(0, 8));
        REQUIRE( row.ColumnsNumber() == 2 );
        CHECK( Equal(row.AddressString(), CFSTR("000000")) );
        CHECK( Equal(row.SnippetString(), CFSTR("Hello, W")) );
        CHECK( Equal(row.ColumnString(0), CFSTR("48 65 6C 6C")) );
        CHECK( Equal(row.ColumnString(1), CFSTR("6F 2C 20 57")) );
    }
    SECTION("4 bytes per column, 2 columns, 2nd row") {
        frame_source.bytes_per_column = 4;
        frame_source.number_of_columns = 2;
        HexModeFrame::RowsBuilder builder(frame_source,
                                          (const std::byte*)string.data(),
                                          (const std::byte*)string.data() + string.size(),
                                          6);
        const auto row = builder.Build(std::make_pair(8, 5),
                                       std::make_pair(8, 5),
                                       std::make_pair(8, 5));
        REQUIRE( row.ColumnsNumber() == 2 );
        CHECK( Equal(row.AddressString(), CFSTR("000008")) );
        CHECK( Equal(row.SnippetString(), CFSTR("orld!")) );
        CHECK( Equal(row.ColumnString(0), CFSTR("6F 72 6C 64")) );
        CHECK( Equal(row.ColumnString(1), CFSTR("21")) );
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

static bool Equal(CFStringRef _lhs, CFStringRef _rhs)
{
    return CFStringCompare(_lhs, _rhs, 0) == kCFCompareEqualTo;
}
