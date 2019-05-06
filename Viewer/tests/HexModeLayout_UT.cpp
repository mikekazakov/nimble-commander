#include "Tests.h"
#include "TextModeWorkingSet.h"
#include "HexModeProcessing.h"
#include "HexModeFrame.h"
#include "HexModeLayout.h"
#include <Utility/Encodings.h>
#include <Habanero/algo.h>

using namespace nc::viewer;

static std::shared_ptr<const TextModeWorkingSet> ProduceWorkingSet(const char *_chars,
                                                                   const int _chars_number,
                                                                   long _ws_offset = 0);
static std::shared_ptr<const HexModeFrame> ProduceFrame
(const std::shared_ptr<const TextModeWorkingSet> &ws,
 const char *_chars,
 const int _chars_number);

static std::unique_ptr<HexModeLayout> ProduceLayout(std::shared_ptr<const HexModeFrame> _frame);

#define PREFIX "HexModeLayout "

TEST_CASE(PREFIX"Correctly performs a hit-test on columns")
{
    const auto string = std::string(10000, 'X');
    const auto ws = ProduceWorkingSet(string.data(), (int)string.length());
    const auto frame = ProduceFrame(ws, string.data(), (int)string.length());
    const auto layout = ProduceLayout(frame);
    
    CHECK( layout->ByteOffsetFromColumnHit({ 50.,8.}) == 0 );
    CHECK( layout->ByteOffsetFromColumnHit({124.,8.}) == 0 );
    CHECK( layout->ByteOffsetFromColumnHit({128.,8.}) == 0 );
    CHECK( layout->ByteOffsetFromColumnHit({134.,8.}) == 1 );
    CHECK( layout->ByteOffsetFromColumnHit({150.,8.}) == 1 );
    CHECK( layout->ByteOffsetFromColumnHit({288.,8.}) == 7 );
    CHECK( layout->ByteOffsetFromColumnHit({488.,8.}) == 15 );
    CHECK( layout->ByteOffsetFromColumnHit({500.,8.}) == 16 );
    CHECK( layout->ByteOffsetFromColumnHit({488.,22.}) == 31 );
    CHECK( layout->ByteOffsetFromColumnHit({500.,22.}) == 32 );
}

TEST_CASE(PREFIX"Correctly calculates a selection background range")
{
    const auto string = std::string(100, 'X');
    const auto ws = ProduceWorkingSet(string.data(), (int)string.length());
    const auto frame = ProduceFrame(ws, string.data(), (int)string.length());
    const auto layout = ProduceLayout(frame);
    const auto offsets = layout->CalcHorizontalOffsets();
    
    SECTION("1000,1") {
        const auto sel = layout->CalcColumnSelectionBackground({1000, 1}, 0, 0, offsets);
        CHECK( sel.first == 0. );
        CHECK( sel.second == 0. );
    }    
    SECTION("0,1") {
        const auto sel = layout->CalcColumnSelectionBackground({0, 1}, 0, 0, offsets);
        CHECK( sel.first == Approx(114.) );
        CHECK( sel.second == Approx(130.) );
    }
    SECTION("0,2") {
        const auto sel = layout->CalcColumnSelectionBackground({0, 2}, 0, 0, offsets);
        CHECK( sel.first == Approx(114.) );
        CHECK( sel.second == Approx(154.) );
    }
    SECTION("7,1") {
        const auto sel = layout->CalcColumnSelectionBackground({7, 1}, 0, 0, offsets);
        CHECK( sel.first == Approx(278.) );
        CHECK( sel.second == Approx(295.) );
    }
    SECTION("0,8") {
        const auto sel = layout->CalcColumnSelectionBackground({0, 8}, 0, 0, offsets);
        CHECK( sel.first == Approx(114.) );
        CHECK( sel.second == Approx(295.) );
    }    
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

static std::shared_ptr<const HexModeFrame> ProduceFrame
(const std::shared_ptr<const TextModeWorkingSet> &ws,
 const char *_chars,
 const int _chars_number)
{
    const auto font = CTFontCreateWithName(CFSTR("Menlo-Regular"), 13., nullptr);
    const auto release_font = at_scope_end([&]{ CFRelease(font); });
    HexModeFrame::Source source;
    source.working_set = ws;
    source.raw_bytes_begin = (const std::byte*)_chars;
    source.raw_bytes_end = (const std::byte*)_chars + _chars_number;
    source.font = font;
    source.font_info = nc::utility::FontGeometryInfo{font};
    source.foreground_color = CGColorGetConstantColor(kCGColorBlack);
    source.digits_in_address = 10;
    source.bytes_per_column = 8;
    source.number_of_columns = 2;
    return std::make_shared<HexModeFrame>(source);
}

static std::unique_ptr<HexModeLayout> ProduceLayout(std::shared_ptr<const HexModeFrame> _frame)
{
    HexModeLayout::Source source;
    source.frame = _frame;
    source.view_size = CGSizeMake(1000., 1000.);
    source.file_size = _frame->WorkingSet().BytesLength();
    return std::make_unique<HexModeLayout>(source);
}
