// Copyright (C) 2019-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "TextModeWorkingSet.h"

#include <Base/CFPtr.h>

#include <vector>

namespace nc::viewer {

struct HexModeSplitter {
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

    static std::vector<Line> Split(const Source &_source);

    /**
     * Does floor rounding to be divisible by _bytes_per_line.
     */
    static base::CFPtr<CFStringRef> MakeAddressString(int _row_bytes_start,
                                                      long _working_set_global_offset,
                                                      int _bytes_per_line,
                                                      int _hex_digits_in_address);

    static base::CFPtr<CFStringRef>
    MakeBytesHexString(const std::byte *_first, const std::byte *_last, char16_t _gap_symbol = ' ');
};

} // namespace nc::viewer
