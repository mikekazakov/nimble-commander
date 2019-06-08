// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "TextModeFrame.h"
#include <cmath>

namespace nc::viewer {

std::pair<int, int> TextModeFrame::WordRangeForPosition( CGPoint _position ) const
{
    const int base_index = std::clamp( CharIndexForPosition(_position),
                                       0,
                                       std::max(m_WorkingSet->Length() - 1, 1) );
    
    // this is not an ideal implementation since here we do search in the entire buffer.
    // that's basically a O(N) linear search, which sucks.
    // consider doing this split once during frame preparation and than using that
    // array of indices via binary serach - i.e. can get O(log2N) instead.
    __block int sel_start = 0, sel_end = 0;
    const auto block = ^([[maybe_unused]] NSString *word,
                         NSRange word_range,
                         [[maybe_unused]] NSRange enclosing_range,
                         BOOL *stop){
        if( NSLocationInRange(base_index, word_range) ) {
            sel_start = (int)word_range.location;
            sel_end   = (int)word_range.location + (int)word_range.length;
            *stop = YES;
        }
        else if( (int)word_range.location > base_index )
            *stop = YES;
    };
    
    const auto string = (__bridge NSString *) m_WorkingSet->String();
    const auto options = NSStringEnumerationByWords | NSStringEnumerationSubstringNotRequired;
    [string enumerateSubstringsInRange:NSMakeRange(0, m_WorkingSet->Length())
                               options:options
                            usingBlock:block];
    
    if( sel_start == sel_end ) { // selects a single character
        sel_start = base_index;
        sel_end   = base_index + 1;
    }
    return {sel_start, sel_end};
}
    
}
