#include "TextProcessing.h"
#include "IndexedTextLine.h"

#include <Habanero/algo.h>
#include <Habanero/dispatch_cpp.h>

#include <stdexcept>
#include <cmath>
#include <algorithm>

namespace nc::viewer {
    
int ScanHeadingSpacesForBreakPosition(const char16_t* const _characters,
                                      const int _characters_length,
                                      const int _scan_starting_position,
                                      const double _mono_font_width,
                                      const double _width_threshold)
{
    if( _characters == nullptr ||
        _characters_length < 0 ||
        _scan_starting_position < 0 ||
        _mono_font_width <= 0. ||
        _width_threshold < 0. )
        throw std::invalid_argument( "ScanHeadingSpacesForBreakPosition: invalid input");
        
    double spaces_width_total = 0.0;
    int spaces_total = 0;
    
    for ( int pos = _scan_starting_position; pos < _characters_length; ++pos ) {
        if( _characters[pos] == ' ' ) {
            spaces_width_total += _mono_font_width;
            spaces_total++;
            if( spaces_width_total >= _width_threshold ) {
                return spaces_total;
            }
        }
        else {
            break;
        }
    }
    
    if( _scan_starting_position + spaces_total == _characters_length )
        return spaces_total;
    
    return 0;
}

void CleanUnicodeControlSymbols(char16_t* const _characters,
                                int const _characters_length)
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
            _characters[i] = ' ';
        }
        
        if( c == 0x000D &&
            i + 1 < _characters_length &&
           _characters[i + 1] == 0x000A ) {
            _characters[i] = ' '; // fix windows-like CR+LF newline to native LF
        }
    }
}

int ScanForExtraTrailingSpaces(const char16_t* _characters,
                               int _scan_starting_position,
                               int _scan_end_position,
                               double _mono_font_width,
                               double _width_threshold,
                               CTTypesetterRef _setter)
{
    if( _characters == nullptr ||
        _scan_starting_position < 0 ||
        _scan_end_position < _scan_starting_position ||
        _mono_font_width <= 0. ||
       _setter == nullptr ) {
        throw std::invalid_argument("ScanForExtraTrailingSpaces: invalid argument");
    }
    
    // 1st - count trailing spaces
    int spaces_count = 0;
    for ( int i = _scan_end_position - 1; i >= _scan_starting_position; --i ) {
        if( _characters[i] == ' ' )
            spaces_count++;
        else
            break;
    }
    
    if( spaces_count == 0)
        return 0;
    
    if( spaces_count == _scan_end_position - _scan_starting_position )
        return 0;
    
    // 2nd - calc width of string without spaces
    const auto range_without_trailing_space =
        CFRangeMake(_scan_starting_position,
                    _scan_end_position - _scan_starting_position - spaces_count );
    const auto line = CTTypesetterCreateLine(_setter, range_without_trailing_space);
    const auto line_width = CTLineGetTypographicBounds(line, nullptr, nullptr, nullptr);
    CFRelease(line);
    if( line_width > _width_threshold )
        return 0; // guard from singular cases
    
    // 3rd - calc residual space and amount of space characters to fill it
    const auto delta_width = _width_threshold - line_width;
    const auto fit_spaces = (int) std::ceil(delta_width / _mono_font_width);
    const auto extras = std::max(spaces_count - fit_spaces, 0);
    return extras;
}
    
std::vector<IndexedTextLine> SplitIntoLines(CFAttributedStringRef const _attributed_string,
                                            double const _wrapping_width,
                                            double const _monospace_width,
                                            const uint32_t * const _unichars_to_byte_indices)
{
    // Create a typesetter using the attributed string.
    const auto typesetter = CTTypesetterCreateWithAttributedString(_attributed_string);
    const auto release_typesetter = at_scope_end([&]{ CFRelease(typesetter); });
    
    const auto cf_string = CFAttributedStringGetString(_attributed_string);
    
    const auto raw_chars = (const char16_t*)CFStringGetCharactersPtr(cf_string);
    if( raw_chars == nullptr )
        throw std::invalid_argument("SplitIntoLines: can't get raw characters pointer");
    
    const auto raw_chars_length = (int)CFStringGetLength(cf_string);
    
    std::vector< std::pair<int, int> > starts_and_length;
    int start = 0;
    while ( start < raw_chars_length  ) {
        // 1st - manual hack for breaking lines by space characters
        int count = 0;
        
        const int spaces = ScanHeadingSpacesForBreakPosition
            (raw_chars, raw_chars_length, (int)start, _monospace_width, _wrapping_width);
        if( spaces != 0 ) {
            count = spaces;
        }
        else {
            count = (int)CTTypesetterSuggestLineBreak(typesetter, start, _wrapping_width);
            if( count <= 0 )
                break;
            
            const int tail_spaces_cut = ScanForExtraTrailingSpaces
                (raw_chars, start, start + count, _monospace_width, _wrapping_width, typesetter);
            
            count -= tail_spaces_cut;
        }
        
        // Use the returned character count (to the break) to create the line.
        starts_and_length.emplace_back(start, count);
        start += count;
    }
    
    // build our CTLines in multiple threads since it can be time-consuming
    std::vector<nc::viewer::IndexedTextLine> lines( starts_and_length.size() );
    const auto block = [&] (size_t n) {
        const auto &position = starts_and_length[n];
        const auto unichar_range = CFRangeMake(position.first, position.second);
        const auto line = CTTypesetterCreateLine(typesetter, unichar_range);
        lines[n] = IndexedTextLine{
            position.first,
            position.second,
            (int)_unichars_to_byte_indices[position.first],
            (int)_unichars_to_byte_indices[position.first + position.second - 1] -
            (int)_unichars_to_byte_indices[position.first],
            line
        };
    };
    dispatch_apply( lines.size(), dispatch_get_global_queue(0, 0), block );
    
    return lines;
}

}

