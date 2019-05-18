#pragma once

#include <vector>
#include <stdint.h>
#include <CoreText/CoreText.h>

namespace nc::viewer {

class TextModeIndexedTextLine;
    
/**
 * Replaces control symbols with _replacement or spaces (' ' = 0x20) by default.
 * Replaces 0x0D followed by 0x0A with 0x20 followed by 0x0A.
 */
void CleanUnicodeControlSymbols(char16_t* _characters,
                                int _characters_length,
                                char16_t _replacement = ' ');

/**
 * Creates an immutable paragraph style with settings to have a regular grid of specified tabs.
 */
CTParagraphStyleRef CreateParagraphStyleWithRegularTabs(double _tab_width);
    
    
/**
 * Returns a vector of pairs, each pair is (begin_index, chars_length)
 */
std::vector< std::pair<int, int> > SplitStringIntoLines(const char16_t* _characters,
                                                        int _characters_number,
                                                        double _wrapping_width,
                                                        double _monospace_width,
                                                        double _tab_width);
    
/**
* Splits _attributed_string into IndexedTextLine using layout information
 * obtained via SplitStringIntoLines.
* _unichars_to_byte_indices should be len+1 long to be able to index the [len] offset.
*/
std::vector<TextModeIndexedTextLine> SplitAttributedStringsIntoLines
    (CFAttributedStringRef _attributed_string,
     double _wrapping_width,
     double _monospace_width,
     double _tab_width,
     const int *_unichars_to_byte_indices);

}
