// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontExtras.h>
#include <string>
#include <array>
#include <Base/dispatch_cpp.h>
#include <Base/CFPtr.h>
#include <cmath>
#include <pstld/pstld.h>

@implementation NSFont (StringDescription)

+ (NSFont *)fontWithStringDescription:(NSString *)_description
{
    if( !_description )
        return nil;

    NSArray *arr = [_description componentsSeparatedByString:@","];
    if( !arr || arr.count != 2 )
        return nil;

    NSString *family = arr[0];
    NSString *size = [arr[1] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    const auto sz = size.intValue;
    if( family.length == 0 || [family characterAtIndex:0] != '@' ) {
        // regular "family,size" syntax
        return [NSFont fontWithName:family size:sz];
    }
    else {
        if( [family isEqualToString:@"@systemFont"] )
            return [NSFont systemFontOfSize:sz];
        if( [family isEqualToString:@"@boldSystemFont"] )
            return [NSFont boldSystemFontOfSize:sz];
        if( [family isEqualToString:@"@labelFont"] )
            return [NSFont labelFontOfSize:sz];
        if( [family isEqualToString:@"@titleBarFont"] )
            return [NSFont titleBarFontOfSize:sz];
        if( [family isEqualToString:@"@menuFont"] )
            return [NSFont menuFontOfSize:sz];
        if( [family isEqualToString:@"@menuBarFont"] )
            return [NSFont menuBarFontOfSize:sz];
        if( [family isEqualToString:@"@messageFont"] )
            return [NSFont messageFontOfSize:sz];
        if( [family isEqualToString:@"@paletteFont"] )
            return [NSFont paletteFontOfSize:sz];
        if( [family isEqualToString:@"@toolTipsFont"] )
            return [NSFont toolTipsFontOfSize:sz];
        if( [family isEqualToString:@"@controlContentFont"] )
            return [NSFont controlContentFontOfSize:sz];
        return nil;
    }
}

static bool IsSystemFont(NSFont *_font)
{
    static const auto max_sz = 100;
    [[clang::no_destroy]] static std::array<NSString *, max_sz> descriptions;
    const auto pt = static_cast<int>(std::round(_font.pointSize));
    if( pt < 0 || pt >= max_sz )
        return false;

    const auto std_desc = [&] {
        if( !descriptions[pt] )
            descriptions[pt] = [NSFont systemFontOfSize:pt].fontName;
        return descriptions[pt];
    }();

    return [std_desc isEqualToString:_font.fontName];
}

- (bool)isSystemFont
{
    return IsSystemFont(self);
}

- (NSString *)toStringDescription
{
    const auto pt = static_cast<int>(std::round(self.pointSize));
    if( IsSystemFont(self) )
        return [NSString stringWithFormat:@"%@, %s", @"@systemFont", std::to_string(pt).c_str()];
    /* check for another system fonts flavours */
    return [NSString stringWithFormat:@"%@, %s", self.fontName, std::to_string(pt).c_str()];
}

- (std::string)toStdStringDescription
{
    return [self toStringDescription].UTF8String;
}

@end

namespace nc::utility {

FontGeometryInfo::FontGeometryInfo(NSFont *_font) : FontGeometryInfo((__bridge CTFontRef)_font)
{
}

static base::CFPtr<CFStringRef> ReplaceNewlines(CFStringRef _src, CFStringRef _with) noexcept
{
    static const auto newline_cs = CFCharacterSetGetPredefined(kCFCharacterSetNewline);

    auto str = base::CFPtr<CFMutableStringRef>::adopt(CFStringCreateMutableCopy(kCFAllocatorDefault, 0, _src));
    const auto replacement_length = CFStringGetLength(_with);
    CFRange search_range = CFRangeMake(0, CFStringGetLength(str.get()));
    while( search_range.length > 0 ) {
        CFRange found_range;
        const bool found = CFStringFindCharacterFromSet(str.get(), newline_cs, search_range, 0, &found_range);
        if( !found )
            break;
        CFStringReplace(str.get(), found_range, _with);
        search_range.location = found_range.location + replacement_length;
        search_range.length = CFStringGetLength(str.get()) - search_range.location;
    }

    return str;
}

static bool HasNewlines(CFStringRef _src) noexcept
{
    static const auto newline_cs = CFCharacterSetGetPredefined(kCFCharacterSetNewline);
    CFRange r;
    return CFStringFindCharacterFromSet(_src, newline_cs, CFRangeMake(0, CFStringGetLength(_src)), 0, &r);
}

static const auto g_InfiniteRectPath = CGPathCreateWithRect(CGRectMake(0, 0, CGFLOAT_MAX, CGFLOAT_MAX), nullptr);
static void CalculateWidthsOfStringsBulk(const CFStringRef *_str_first,
                                         const CFStringRef *_str_last,
                                         unsigned short *_out_width_first,
                                         [[maybe_unused]] unsigned short *_out_width_last,
                                         CFDictionaryRef _attributes)
{
    const auto strings_amount = static_cast<int>(_str_last - _str_first);
    assert(strings_amount > 0);
    assert(strings_amount == static_cast<int>(_out_width_last - _out_width_first));

    const auto initial_capacity = strings_amount * 64;
    const auto storage =
        base::CFPtr<CFMutableStringRef>::adopt(CFStringCreateMutable(kCFAllocatorDefault, initial_capacity));

    for( int i = 0; i < strings_amount; ++i ) {
        const auto str = _str_first[i];
        if( HasNewlines(str) ) {
            auto replaced = ReplaceNewlines(str, CFSTR(" "));
            CFStringAppend(storage.get(), replaced.get());
        }
        else {
            CFStringAppend(storage.get(), str);
        }
        CFStringAppend(storage.get(), CFSTR("\n"));
    }

    const auto storage_length = CFStringGetLength(storage.get());
    const auto attr_string =
        base::CFPtr<CFAttributedStringRef>::adopt(CFAttributedStringCreate(nullptr, storage.get(), _attributes));
    const auto framesetter =
        base::CFPtr<CTFramesetterRef>::adopt(CTFramesetterCreateWithAttributedString(attr_string.get()));
    const auto frame = base::CFPtr<CTFrameRef>::adopt(
        CTFramesetterCreateFrame(framesetter.get(), CFRangeMake(0, storage_length), g_InfiniteRectPath, nullptr));

    const auto lines = CTFrameGetLines(frame.get());
    const auto lines_cnt = CFArrayGetCount(lines);
    for( long idx = 0; idx < lines_cnt; ++idx ) {
        const auto line = static_cast<CTLineRef>(CFArrayGetValueAtIndex(lines, idx));
        const double original_width = CTLineGetTypographicBounds(line, nullptr, nullptr, nullptr);
        const unsigned short rounded_width = static_cast<unsigned short>(std::max(std::ceil(original_width), 0.));
        assert(rounded_width > 0 || CFStringGetLength(_str_first[idx]) == 0);
        assert(idx < strings_amount);
        _out_width_first[idx] = rounded_width;
    }
}

std::vector<unsigned short> FontGeometryInfo::CalculateStringsWidths(std::span<const CFStringRef> _strings,
                                                                     NSFont *_font)
{
    if( _font == nil )
        throw std::invalid_argument("FontGeometryInfo::CalculateStringsWidths: _font can't be empty");

    const auto count = _strings.size();
    if( count == 0 )
        return {};

    std::vector<unsigned short> widths(count);
    const auto attributes = @{NSFontAttributeName: _font};
    const auto cf_attributes = (__bridge CFDictionaryRef)attributes;
    const size_t parallel_threshold = 1024;
    if( count < parallel_threshold ) {
        // don't bother with parallelism, just calculate everything here
        CalculateWidthsOfStringsBulk(
            _strings.data(), _strings.data() + count, widths.data(), widths.data() + count, cf_attributes);
    }
    else {
        // distribute equally into chunks so that each CPU core has 2 batches to process
        // TODO: stop using the 'internal' namespace! Absorb these routines instead
        const size_t chunks = ::pstld::internal::max_hw_threads() * 2;
        ::pstld::internal::Partition<size_t, true, true> par(0, count, chunks);
        const auto block = [&](size_t _chunk_index) {
            const auto index_first = par.at(_chunk_index).first;
            const auto index_last = par.at(_chunk_index).last;
            CalculateWidthsOfStringsBulk(_strings.data() + index_first,
                                         _strings.data() + index_last,
                                         widths.data() + index_first,
                                         widths.data() + index_last,
                                         cf_attributes);
        };
        dispatch_apply(chunks, block);
    }
    return widths;
}

} // namespace nc::utility
