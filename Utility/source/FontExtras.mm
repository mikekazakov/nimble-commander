// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <string>
#include <array>
#include <Utility/FontExtras.h>
#include <Habanero/dispatch_cpp.h>

@implementation NSFont (StringDescription)

+ (NSFont*) fontWithStringDescription:(NSString*)_description
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

static bool IsSystemFont( NSFont *_font )
{
    static const auto max_sz = 100;
    static std::array<NSString*, max_sz> descriptions;
    const auto pt = (int)floor(_font.pointSize + 0.5);
    if( pt < 0 || pt >= max_sz )
        return false;
    
    const auto std_desc = [&]{
        if( !descriptions[pt] )
            descriptions[pt] = [NSFont systemFontOfSize:pt].fontName;
        return descriptions[pt];
    }();

    return [std_desc isEqualToString:_font.fontName];
}

- (NSString*) toStringDescription
{
    const auto pt = (int)floor(self.pointSize + 0.5);
    if( IsSystemFont(self) )
        return [NSString stringWithFormat:@"%@, %s", @"@systemFont", std::to_string(pt).c_str()];
    /* check for another system fonts flavours */
    return [NSString stringWithFormat:@"%@, %s", self.fontName, std::to_string(pt).c_str()];
}

@end

namespace nc::utility {

FontGeometryInfo::FontGeometryInfo(NSFont *_font):
    FontGeometryInfo( (__bridge CTFontRef)_font )
{
}

static const auto g_InfiniteRectPath = 
    CGPathCreateWithRect(CGRectMake(0, 0, CGFLOAT_MAX, CGFLOAT_MAX), nullptr);
static void CalculateWidthsOfStringsBulk(CFStringRef const *_str_first,
                                         CFStringRef const *_str_last,
                                         short *_out_width_first,
                                         short *_out_width_last,
                                         CFDictionaryRef _attributes)
{
    const auto strings_amount = (int)(_str_last - _str_first);
    assert( strings_amount > 0 );
    assert( strings_amount == (int)(_out_width_last - _out_width_first) );
    
    const auto initial_capacity = strings_amount * 64;
    const auto storage = CFStringCreateMutable(NULL, initial_capacity);
    
    for( int i = 0; i < strings_amount; ++i ) {
        CFStringAppend(storage, _str_first[i]);
        CFStringAppend(storage, CFSTR("\n"));
    }
            
    const auto storage_length = CFStringGetLength(storage);
    const auto attr_string = CFAttributedStringCreate(nullptr, storage, _attributes);
    const auto framesetter = CTFramesetterCreateWithAttributedString(attr_string);
    const auto frame = CTFramesetterCreateFrame(framesetter,
                                                CFRangeMake(0, storage_length),
                                                g_InfiniteRectPath,
                                                nullptr);
    
    const auto lines = (__bridge NSArray*)CTFrameGetLines(frame);
    int line_index = 0;
    for( id item in lines ) {
        const auto line = (__bridge CTLineRef)item;
        const double original_width = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
        const short rounded_width = (short)floor( original_width + 0.5 );
        _out_width_first[ line_index++ ] = rounded_width; 
    }
    CFRelease(frame);
    CFRelease(framesetter);
    CFRelease(attr_string);
    CFRelease(storage);        
}

std::vector<short> FontGeometryInfo::
    CalculateStringsWidths(const std::vector<CFStringRef> &_strings, NSFont *_font )
{
    const auto count = (int)_strings.size();
    if( count == 0 )
        return {};

    const auto items_per_chunk = [&]{
        if( count <= 512 )          return 128; 
        else if( count <= 2048 )    return 256;
        else                        return 512; 
    }();
    
    std::vector<short> widths( count );
    
    const auto attributes = @{NSFontAttributeName:_font};    
    const auto cf_attributes = (__bridge CFDictionaryRef)attributes;
    
    if( count > items_per_chunk ) {
        const auto iterations = (count / items_per_chunk) + (count % items_per_chunk ? 1 : 0);
        const auto block = [&](size_t _chunk_index) {
            const auto index_first = (int)_chunk_index * items_per_chunk;
            const auto index_last = std::min(index_first + items_per_chunk, count); 
            CalculateWidthsOfStringsBulk(_strings.data() + index_first,
                                         _strings.data() + index_last,
                                         widths.data() + index_first,
                                         widths.data() + index_last,
                                         cf_attributes);
        };
        dispatch_apply(iterations, block);
    }
    else {
        CalculateWidthsOfStringsBulk(_strings.data(),
                                     _strings.data() + count,
                                     widths.data(),
                                     widths.data() + count,
                                     cf_attributes);
    }
    
    return widths;
}

}
