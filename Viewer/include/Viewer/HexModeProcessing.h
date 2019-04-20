#pragma once

#include "TextModeWorkingSet.h"

#include <vector>

namespace nc::viewer {
    
struct HexModeSplitter
{
    struct Line {
        int chars_start;        // unicode character index of the string start in the working set
        int chars_num;          // amount of unicode characters in the line
        int string_bytes_start; // byte index of the string start in the working set
        int string_bytes_num;   // amount of bytes occupied by the string
        int row_bytes_start;    // byte index of the row start in the working set
        int row_bytes_num;      // amount of bytes occupied by the row
    };

    struct Source {
        const TextModeWorkingSet *working_set = nullptr; // must be set to a valid working set
        int bytes_per_row = 16;
    };
    
    static std::vector<Line> Split( const Source& _source );
};

}
