// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TextModeFrame.h"
#include "TextModeWorkingSet.h"
#include <Utility/Encodings.h>
#include <Base/algo.h>

#include <algorithm>
#include <numeric>
#include <vector>

using nc::viewer::TextModeFrame;
using nc::viewer::TextModeWorkingSet;

static std::shared_ptr<const TextModeWorkingSet> ProduceWorkingSet(const char16_t *_chars, int _chars_number);
static std::shared_ptr<const TextModeFrame> ProduceFrame(std::shared_ptr<const TextModeWorkingSet> _working_set,
                                                         double _wrapping_width,
                                                         int _tab_spaces,
                                                         CTFontRef _font);

#define PREFIX "TextModeFrame "
TEST_CASE(PREFIX "Does proper hit-test")
{
    const auto font = CTFontCreateWithName(CFSTR("Menlo-Regular"), 13., nullptr);
    const auto release_font = at_scope_end([&] { CFRelease(font); });
    const auto str = u"01234"
                     "\x0A"
                     "56789";
    const auto len = std::char_traits<char16_t>::length(str);
    const auto frame = ProduceFrame(ProduceWorkingSet(str, len), 10000., 4, font);
    CHECK(frame->CharIndexForPosition({-50., -50.}) == 0);
    CHECK(frame->CharIndexForPosition({-50., 5.}) == 0);
    CHECK(frame->CharIndexForPosition({0., 5.}) == 0);
    CHECK(frame->CharIndexForPosition({2., 5.}) == 0);
    CHECK(frame->CharIndexForPosition({3., 5.}) == 0);
    CHECK(frame->CharIndexForPosition({4., 5.}) == 1);
    CHECK(frame->CharIndexForPosition({5., 5.}) == 1);
    CHECK(frame->CharIndexForPosition({6., 5.}) == 1);
    CHECK(frame->CharIndexForPosition({7., 5.}) == 1);
    CHECK(frame->CharIndexForPosition({8., 5.}) == 1);
    CHECK(frame->CharIndexForPosition({9., 5.}) == 1);
    CHECK(frame->CharIndexForPosition({10., 5.}) == 1);
    CHECK(frame->CharIndexForPosition({11., 5.}) == 1);
    CHECK(frame->CharIndexForPosition({12., 5.}) == 2);
    CHECK(frame->CharIndexForPosition({100., 5.}) == 5);
    CHECK(frame->CharIndexForPosition({-50., 15.}) == 6);
    CHECK(frame->CharIndexForPosition({2., 15.}) == 6);
    CHECK(frame->CharIndexForPosition({100., 15.}) == 11);
    CHECK(frame->CharIndexForPosition({100., 100.}) == 11);
}

TEST_CASE(PREFIX "Properly selects text by words")
{
    const auto font = CTFontCreateWithName(CFSTR("Menlo-Regular"), 13., nullptr);
    const auto release_font = at_scope_end([&] { CFRelease(font); });
    const auto str = u"01234"
                     "\x0A"
                     "56789";
    const auto len = std::char_traits<char16_t>::length(str);
    const auto frame = ProduceFrame(ProduceWorkingSet(str, len), 10000., 4, font);
    CHECK(frame->WordRangeForPosition({-100., -100.}).first == 0);
    CHECK(frame->WordRangeForPosition({-100., -100.}).second == 5);
    CHECK(frame->WordRangeForPosition({-100., 5.}).first == 0);
    CHECK(frame->WordRangeForPosition({-100., 5.}).second == 5);
    CHECK(frame->WordRangeForPosition({4., 5.}).first == 0);
    CHECK(frame->WordRangeForPosition({4., 5.}).second == 5);
    CHECK(frame->WordRangeForPosition({10., 5.}).first == 0);
    CHECK(frame->WordRangeForPosition({10., 5.}).second == 5);
    CHECK(frame->WordRangeForPosition({100., 5.}).first == 5);
    CHECK(frame->WordRangeForPosition({100., 5.}).second == 6);
    CHECK(frame->WordRangeForPosition({-100., 100.}).first == 6);
    CHECK(frame->WordRangeForPosition({-100., 100.}).second == 11);
    CHECK(frame->WordRangeForPosition({100., 100.}).first == 6);
    CHECK(frame->WordRangeForPosition({100., 100.}).second == 11);
}

static std::shared_ptr<const TextModeFrame> ProduceFrame(std::shared_ptr<const TextModeWorkingSet> _working_set,
                                                         double _wrapping_width,
                                                         int _tab_spaces,
                                                         CTFontRef _font)
{
    TextModeFrame::Source source;
    source.working_set = _working_set;
    source.wrapping_width = _wrapping_width;
    source.tab_spaces = _tab_spaces;
    source.font = _font;
    source.font_info = nc::utility::FontGeometryInfo{_font};
    source.foreground_colors.fill(CGColorGetConstantColor(kCGColorBlack));
    return std::make_shared<TextModeFrame>(source);
}

static std::shared_ptr<const TextModeWorkingSet> ProduceWorkingSet(const char16_t *_chars, const int _chars_number)
{
    std::vector<int> offsets(_chars_number, 0);
    std::ranges::generate(offsets, [offset = -2]() mutable { return offset += 2; });
    TextModeWorkingSet::Source source;
    source.unprocessed_characters = _chars;
    source.mapping_to_byte_offsets = offsets.data();
    source.characters_number = _chars_number;
    source.bytes_offset = 0;
    source.bytes_offset = static_cast<long>(_chars_number) * 2l;
    return std::make_shared<TextModeWorkingSet>(source);
}
