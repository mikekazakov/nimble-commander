#include "TextProcessing.h"
#include "TextModeIndexedTextLine.h"

#include <Habanero/algo.h>
#include <Habanero/dispatch_cpp.h>
#include <Utility/OrthodoxMonospace.h>

#include <stdexcept>
#include <cmath>
#include <algorithm>

namespace nc::viewer {

void CleanUnicodeControlSymbols(char16_t* const _characters,
                                int const _characters_length,
                                const char16_t _replacement)
{
    if( _characters == nullptr || _characters_length < 0 )
        throw std::invalid_argument("CleanUnicodeControlSymbols: invalid input");
    
    for ( int  i = 0; i < _characters_length; ++i ) {
        const auto c = _characters[i];
        if( c >= 0x0080 )
            continue;
        
        if(
           c == 0x0000 || // NUL
           c == 0x0001 || // SOH
           c == 0x0002 || // SOH
           c == 0x0003 || // STX
           c == 0x0004 || // EOT
           c == 0x0005 || // ENQ
           c == 0x0006 || // ACK
           c == 0x0007 || // BEL
           c == 0x0008 || // BS
           // c == 0x0009 || // HT
           // c == 0x000A || // LF
           c == 0x000B || // VT
           c == 0x000C || // FF
           // c == 0x000D || // CR
           c == 0x000E || // SO
           c == 0x000F || // SI
           c == 0x0010 || // DLE
           c == 0x0011 || // DC1
           c == 0x0012 || // DC2
           c == 0x0013 || // DC3
           c == 0x0014 || // DC4
           c == 0x0015 || // NAK
           c == 0x0016 || // SYN
           c == 0x0017 || // ETB
           c == 0x0018 || // CAN
           c == 0x0019 || // EM
           c == 0x001A || // SUB
           c == 0x001B || // ESC
           c == 0x001C || // FS
           c == 0x001D || // GS
           c == 0x001E || // RS
           c == 0x001F || // US
           c == 0x007F    // DEL
           ) {
            _characters[i] = _replacement;
        }
        
        if( c == 0x000D &&
            i + 1 < _characters_length &&
           _characters[i + 1] == 0x000A ) {
            _characters[i] = _replacement; // fix windows-like CR+LF newline to native LF
        }
    }
}
    
CTParagraphStyleRef CreateParagraphStyleWithRegularTabs(double _tab_width)
{
    const auto tab_width = _tab_width;
    const auto tab_stops = CFArrayCreate(nullptr, nullptr, 0, nullptr);
    const auto release_tab_stops = at_scope_end([&]{ CFRelease(tab_stops); });
    CTParagraphStyleSetting settings[2];
    settings[0].spec = kCTParagraphStyleSpecifierDefaultTabInterval;
    settings[0].valueSize = sizeof(tab_width);
    settings[0].value = &tab_width;
    settings[1].spec = kCTParagraphStyleSpecifierTabStops;
    settings[1].valueSize = sizeof(tab_stops);
    settings[1].value = &tab_stops;
    return CTParagraphStyleCreate(settings, 2);
}

std::vector< std::pair<int, int> > SplitStringIntoLines(const char16_t* _characters,
                                                        int _characters_number,
                                                        double _wrapping_width,
                                                        double _monospace_width,
                                                        double _tab_width)
{
    const auto wrapping_epsilon = 0.2;
    const auto is_hardbreak = [](char16_t c) -> bool {
        return c == 0xA || c == 0xD; // more???
    };
    
    std::vector< std::pair<int, int> > starts_and_lengths;
    int start = 0;
    while ( start < _characters_number  ) {
        // 1st - manual hack for breaking lines by space characters
        int count = 0;
        
        double width = 0.;
        for ( int i = start; i < _characters_number; ++i ) {
            const auto c = _characters[i];
            if( is_hardbreak(c) ) {
                count++;
                break;
            }
            
            if( oms::IsUnicodeCombiningCharacter(c) ) {
                count++;
                continue;
            }
            
            if( c == 0x09 ) { // HT - tab
                const auto probe_width = width + _tab_width - std::fmod(width, _tab_width);
                if( probe_width > _wrapping_width + wrapping_epsilon )
                    break;
                width = probe_width;
            }
            else {
                const auto probe_width =
                    oms::WCWidthMin1( c ) == 1 ?  // TODO: add support for surrogate pairs
                        width + _monospace_width :
                        width + 2 * _monospace_width;
                
                if( probe_width > _wrapping_width + wrapping_epsilon ) {
                    break;
                }
                width = probe_width;
            }
            count++;
        }
        
        // Use the returned character count (to the break) to create the line.
        starts_and_lengths.emplace_back(start, count);
        start += count;
    }
    return starts_and_lengths;
}

std::vector<TextModeIndexedTextLine> SplitAttributedStringsIntoLines
    (CFAttributedStringRef const _attributed_string,
     double const _wrapping_width,
     double const _monospace_width,
     double const _tab_width,
     const int * const _unichars_to_byte_indices)
{
    assert( _wrapping_width > 0. );
    assert( _monospace_width > 0. );
    assert( _tab_width > 0. );
    
    const auto cf_string = CFAttributedStringGetString(_attributed_string);
    assert( cf_string != nullptr );
    
    const auto raw_chars_length = (int)CFStringGetLength(cf_string);
    if( raw_chars_length == 0 )
        return {};
    
    // Create a typesetter using the attributed string.
    const auto typesetter = CTTypesetterCreateWithAttributedString(_attributed_string);
    const auto release_typesetter = at_scope_end([&]{ CFRelease(typesetter); });
    
    const auto raw_chars = (const char16_t*)CFStringGetCharactersPtr(cf_string);
    if( raw_chars == nullptr )
        throw std::invalid_argument("SplitIntoLines: can't get raw characters pointer");
    
    const auto starts_and_lengths = SplitStringIntoLines(raw_chars,
                                                        raw_chars_length,
                                                        _wrapping_width,
                                                        _monospace_width,
                                                        _tab_width);
    
    // build our CTLines in multiple threads since it can be time-consuming
    std::vector<nc::viewer::TextModeIndexedTextLine> lines( starts_and_lengths.size() );
    const auto block = [&] (size_t n) {
        const auto &position = starts_and_lengths[n];
        const auto unichar_range = CFRangeMake(position.first, position.second);
        const auto line = CTTypesetterCreateLine(typesetter, unichar_range);
        lines[n] = TextModeIndexedTextLine{
            position.first,
            position.second,
            _unichars_to_byte_indices[position.first],
            _unichars_to_byte_indices[position.first + position.second] -
                _unichars_to_byte_indices[position.first],
            line
        };
    };
    dispatch_apply( lines.size(), dispatch_get_global_queue(0, 0), block );
    
    return lines;
}
    
}
