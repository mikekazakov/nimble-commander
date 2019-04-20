#include "HexModeProcessing.h"

namespace nc::viewer {

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
    
}
