#pragma once

#include <CoreText/CoreText.h>

namespace nc::viewer {

/**
 * Scans *heading* spaces starting from _scan_starting_position and up to _characters_length.
 * Counts total width occupied by these heading spaces.
 * If at some point sum of these spaces widths exceeds _width_threshold - returns the amount
 * of heading spaces encountered.
 * If these entire range of [_scan_starting_position, _characters_length) consists of spaces only
 * - also returns the amount of heading spaces encountered.
 * Otherwise returns zero.
 * The input (_characters) is UTF16.
 * (rationale: CTTypesetterSuggestLineBreak cheats and fits endless heading spaces into a single
 * line, which is not true and NC doesn't show data this way).
 */
int ScanHeadingSpacesForBreakPosition(const char16_t* _characters,
                                      int _characters_length,
                                      int _scan_starting_position,
                                      double _mono_font_width,
                                      double _width_threshold);

/**
 * Replaces control symbols with spaces (' ' = 0x20).
 * Replaces 0x0D followed by 0x0A with 0x20 followed by 0x0A.
 */
void CleanUnicodeControlSymbols(char16_t* _characters, int _characters_length);

    
/**
 * Checks whether the characters block of [_scan_starting_position, _scan_end_position) has
 * trailing spaces and if it does:
 * checks if whether there are excess trailing space character that has to be cut from the end
 * to make he characters block fit into _width_threshold.
 * Returns a number of trailing space characters to be cut out.
 * (rationale: CTTypesetterSuggestLineBreak cheats and fits endless trailing spaces into a single
 * line, which is not true and NC doesn't show data this way).
 */
int ScanForExtraTrailingSpaces(const char16_t* _characters,
                               int _scan_starting_position,
                               int _scan_end_position,
                               double _mono_font_width,
                               double _width_threshold,
                               CTTypesetterRef _setter);

}
