// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TextModeWorkingSet.h"
#include "HexModeProcessing.h"
#include "HexModeFrame.h"
#include "HexModeLayout.h"
#include <Utility/Encodings.h>
#include <Base/algo.h>

using namespace nc::viewer;
using Catch::Approx;

static std::shared_ptr<const TextModeWorkingSet>
ProduceWorkingSet(const char *_chars, int _chars_number, long _ws_offset = 0);
static std::shared_ptr<const HexModeFrame>
ProduceFrame(const std::shared_ptr<const TextModeWorkingSet> &ws, const char *_chars, int _chars_number);

static std::unique_ptr<HexModeLayout> ProduceLayout(std::shared_ptr<const HexModeFrame> _frame);

#define PREFIX "HexModeLayout "

TEST_CASE(PREFIX "Correctly performs a hit-test on columns")
{
    const auto string = std::string(10000, 'X');
    const auto ws = ProduceWorkingSet(string.data(), static_cast<int>(string.length()));
    const auto frame = ProduceFrame(ws, string.data(), static_cast<int>(string.length()));
    const auto layout = ProduceLayout(frame);
    const auto offsets = layout->CalcHorizontalOffsets();
    const auto fc = offsets.columns.front();
    const auto fs = offsets.snippet;

    CHECK(layout->ByteOffsetFromColumnHit({fc - 64., 8.}) == 0);
    CHECK(layout->ByteOffsetFromColumnHit({fc + 10., 8.}) == 0);
    CHECK(layout->ByteOffsetFromColumnHit({fc + 14., 8.}) == 0);
    CHECK(layout->ByteOffsetFromColumnHit({fc + 20., 8.}) == 1);
    CHECK(layout->ByteOffsetFromColumnHit({fc + 36., 8.}) == 1);
    CHECK(layout->ByteOffsetFromColumnHit({fc + 174., 8.}) == 7);
    CHECK(layout->ByteOffsetFromColumnHit({fc + 374., 8.}) == 15);
    CHECK(layout->ByteOffsetFromColumnHit({fc + 386., 8.}) == 16);
    CHECK(layout->ByteOffsetFromColumnHit({fc + 374., 22.}) == 31);
    CHECK(layout->ByteOffsetFromColumnHit({fc + 386., 22.}) == 32);
    CHECK(layout->CharOffsetFromSnippetHit({fs - 50., 8.}) == 0);
    CHECK(layout->CharOffsetFromSnippetHit({fs + 3., 8.}) == 0);
    CHECK(layout->CharOffsetFromSnippetHit({fs + 10., 8.}) == 1);
    CHECK(layout->CharOffsetFromSnippetHit({fs + 121., 8.}) == 15);
    CHECK(layout->CharOffsetFromSnippetHit({fs + 178., 8.}) == 16);
}

TEST_CASE(PREFIX "Correctly calculates a selection background range")
{
    const auto string = std::string(100, 'X');
    const auto ws = ProduceWorkingSet(string.data(), static_cast<int>(string.length()));
    const auto frame = ProduceFrame(ws, string.data(), static_cast<int>(string.length()));
    const auto layout = ProduceLayout(frame);
    const auto offsets = layout->CalcHorizontalOffsets();
    const auto fc = offsets.columns.front();
    const auto fs = offsets.snippet;

    {
        const auto sel = layout->CalcColumnSelectionBackground({1000, 1}, 0, 0, offsets);
        CHECK(sel.first == 0.);
        CHECK(sel.second == 0.);
    }
    {
        const auto sel = layout->CalcColumnSelectionBackground({0, 1}, 0, 0, offsets);
        CHECK(sel.first == Approx(fc + 0.));
        CHECK(sel.second == Approx(fc + 16.));
    }
    {
        const auto sel = layout->CalcColumnSelectionBackground({0, 2}, 0, 0, offsets);
        CHECK(sel.first == Approx(fc + 0.));
        CHECK(sel.second == Approx(fc + 40.));
    }
    {
        const auto sel = layout->CalcColumnSelectionBackground({7, 1}, 0, 0, offsets);
        CHECK(sel.first == Approx(fc + 164.));
        CHECK(sel.second == Approx(fc + 181.));
    }
    {
        const auto sel = layout->CalcColumnSelectionBackground({0, 8}, 0, 0, offsets);
        CHECK(sel.first == Approx(fc + 0.));
        CHECK(sel.second == Approx(fc + 181.));
    }
    {
        const auto sel = layout->CalcSnippetSelectionBackground({1000, 1}, 0, offsets);
        CHECK(sel.first == 0.);
        CHECK(sel.second == 0.);
    }
    {
        const auto sel = layout->CalcSnippetSelectionBackground({0, 1}, 0, offsets);
        CHECK(sel.first == Approx(fs + 0.));
        CHECK(sel.second == Approx(fs + 8.));
    }
    {
        const auto sel = layout->CalcSnippetSelectionBackground({0, 2}, 0, offsets);
        CHECK(sel.first == Approx(fs + 0.));
        CHECK(sel.second == Approx(fs + 16.));
    }
    {
        const auto sel = layout->CalcSnippetSelectionBackground({0, 1000}, 0, offsets);
        CHECK(sel.first == Approx(fs + 0.));
        CHECK(sel.second == Approx(fs + 126.));
    }
    {
        const auto sel = layout->CalcSnippetSelectionBackground({1, 1000}, 0, offsets);
        CHECK(sel.first == Approx(fs + 7.));
        CHECK(sel.second == Approx(fs + 126.));
    }
    {
        const auto sel = layout->CalcSnippetSelectionBackground({1, 3}, 0, offsets);
        CHECK(sel.first == Approx(fs + 7.));
        CHECK(sel.second == Approx(fs + 32.));
    }
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

static std::shared_ptr<const HexModeFrame>
ProduceFrame(const std::shared_ptr<const TextModeWorkingSet> &ws, const char *_chars, const int _chars_number)
{
    const auto font = CTFontCreateWithName(CFSTR("Menlo-Regular"), 13., nullptr);
    const auto release_font = at_scope_end([&] { CFRelease(font); });
    HexModeFrame::Source source;
    source.working_set = ws;
    source.raw_bytes_begin = reinterpret_cast<const std::byte *>(_chars);
    source.raw_bytes_end = reinterpret_cast<const std::byte *>(_chars) + _chars_number;
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
