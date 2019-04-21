#include "HexModeProcessing.h"

#include <string>

namespace nc::viewer {

static constexpr char g_4Bits_To_Char[16] = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};
    
std::vector<HexModeSplitter::Line> HexModeSplitter::Split( const Source& _source )
{
    const int bytes_per_row = _source.bytes_per_row;
    if( bytes_per_row <= 0 )
        throw std::invalid_argument("HexModeSplitter: bytes_per_row can't be less than 1");
    const auto &working_set = *_source.working_set;
    
    const long window_bytes_pos = working_set.GlobalOffset();
    const int window_bytes_size = working_set.BytesLength();
    const int window_chars_size = working_set.Length();
    
    std::vector<HexModeSplitter::Line> result_lines;

    int char_index = 0; // for string breaking
    int char_extra_bytes = 0; // for string breaking, to handle large (more than 1 byte) characters
    int byte_index = 0; // for hex rows
    for(; char_index < window_chars_size;) {
        Line line;
        line.chars_start = char_index;
        line.string_bytes_start = working_set.ToLocalByteOffset(line.chars_start);
        line.row_bytes_start = byte_index;
        line.chars_num = 1;
        
        // upper bound in bytes for this row. the actual number of bytes in this row can be
        // less than this number, but not more.
        const int bytes_for_current_row =
            char_index != 0 ?
            bytes_per_row :
            (bytes_per_row - int(window_bytes_pos % bytes_per_row));
        const int bytes_for_current_string = bytes_for_current_row - char_extra_bytes;
        
        for( int i = char_index + 1; i < window_chars_size; ++i ) {
            const auto bytes_dist = working_set.ToLocalByteOffset(i) - line.string_bytes_start;
            if( bytes_dist >= bytes_for_current_string )
                break;
            line.chars_num++;
        }
        
        line.string_bytes_num = working_set.ToLocalByteOffset(line.chars_start + line.chars_num) -
            line.string_bytes_start;
        char_extra_bytes = std::max(line.string_bytes_num - bytes_for_current_string, 0);

        line.row_bytes_num = std::min(bytes_for_current_row,
                                      window_bytes_size - line.row_bytes_start);
        
        result_lines.push_back(line);
        
        char_index += line.chars_num;
        byte_index += line.row_bytes_num;
    }
        
    return result_lines;
}
 
base::CFPtr<CFStringRef> HexModeSplitter::MakeAddressString(const int _row_bytes_start,
                                                            const long _working_set_global_offset,
                                                            const int _bytes_per_line,
                                                            const int _hex_digits_in_address )
{
    constexpr int max_hex_length = 64;
    if( _hex_digits_in_address > max_hex_length )
        throw std::invalid_argument("HexModeSplitter::MakeAddressString _hex_digits_in_address "
                                    "is loo big.");
    if( _hex_digits_in_address < 0 )
        throw std::invalid_argument("HexModeSplitter::MakeAddressString _hex_digits_in_address "
                                    "can't be less than 0");
        
    const long unrounded_row_offset = long(_row_bytes_start) + _working_set_global_offset;
    const long row_offset = unrounded_row_offset - unrounded_row_offset % _bytes_per_line;

    char16_t buffer[max_hex_length];
    
    long offset = row_offset;
    for( int char_ind = _hex_digits_in_address - 1; char_ind >= 0; --char_ind ) {
        buffer[char_ind] = g_4Bits_To_Char[offset & 0xF];
        offset >>= 4;
    }
    
    const auto str = CFStringCreateWithCharacters(nullptr,
                                                  (const UniChar *)buffer,
                                                  _hex_digits_in_address);
    return base::CFPtr<CFStringRef>::adopt( str );
}

static void Fill(const std::byte * const _first,
                 const std::byte * const _last,
                 char16_t * const _buffer,
                 const char16_t _gap_symbol) noexcept
{
    auto target = _buffer;
    for( auto source = _first; source < _last; source += 1, target += 3 ) {
        const auto c = (int)(*source);
        const auto lower_4bits = g_4Bits_To_Char[ c & 0x0F      ];
        const auto upper_4bits = g_4Bits_To_Char[(c & 0xF0) >> 4];
        target[0] = upper_4bits;
        target[1] = lower_4bits;
        target[2] = _gap_symbol;
    }
}

base::CFPtr<CFStringRef> HexModeSplitter::MakeBytesHexString(const std::byte * const _first,
                                                             const std::byte * const _last,
                                                             const char16_t _gap_symbol)
{
    const auto size = (int)(_last - _first);
    const auto chars_per_byte = 3;
    const auto max_bytes_via_alloca = 1024;
    if( size * chars_per_byte * sizeof(char16_t) < max_bytes_via_alloca ) {
        auto buffer = (char16_t*)alloca(size * chars_per_byte * sizeof(char16_t) );
        Fill(_first, _last, buffer, _gap_symbol);
        const auto str = CFStringCreateWithCharacters(nullptr,
                                                      (const UniChar *)buffer,
                                                      std::max(size * chars_per_byte - 1, 0) );
        return base::CFPtr<CFStringRef>::adopt( str );
    }
    else {
        std::u16string buffer( size * chars_per_byte, (char16_t)0 );
        Fill(_first, _last, buffer.data(), _gap_symbol);
        const auto str = CFStringCreateWithCharacters(nullptr,
                                                      (const UniChar *)buffer.data(),
                                                      std::max(size * chars_per_byte - 1, 0) );
        return base::CFPtr<CFStringRef>::adopt( str );
    }
}
    
}
