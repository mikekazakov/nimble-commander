#pragma once

#include "TextModeWorkingSet.h"
#include "TextProcessing.h"
#include "IndexedTextLine.h"
#include <Utility/FontExtras.h>

namespace nc::viewer {
    
class TextModeFrame
{
public:
    struct Source {
        std::shared_ptr<const TextModeWorkingSet> working_set;
        double wrapping_width = 10000.;
        int tab_spaces = 4;
        CTFontRef font = nullptr;
        nc::utility::FontGeometryInfo font_info;
        CGColorRef foreground_color = nullptr;
    };
    
    TextModeFrame( const Source &_source );
    TextModeFrame( const TextModeFrame& ) = delete;
    TextModeFrame( TextModeFrame&& ) noexcept;
    ~TextModeFrame();
    TextModeFrame& operator=(const TextModeFrame&) = delete;
    TextModeFrame& operator=(TextModeFrame&&) noexcept;
    
    const std::vector<IndexedTextLine>& Lines() const noexcept;
    bool Empty() const noexcept;
    /** Returns the number of IndexedTextLine lines in the frame. */
    int LinesNumber() const noexcept;
    const IndexedTextLine& Line(int _index) const noexcept;
    
    /**
     * Returns an index of a character which corresponds to the pixel specified by _position.
     * If _position is located before the first character in the line, index of the first character
     * in the line will be returned. If _position is located after the last character in the line,
     * the index of the last character in the line + 1 will be returned.
     * This function assumes top-bottom Y coordidates increase.
     * (0., 0.) is assumed to be at the left-top corner of the first line.
     * This function guarantees to return a value in the range of [0, m_WorkinSet->Length()].
     */
    int CharIndexForPosition( CGPoint _position ) const noexcept;
    
    /** Returns an index for a line corresponding to _position.
     * If _position is above any exisiting lines - will return -1.
     * If _position is below any exisiting lines - will return LinesNumber().
     * This function guarantees to return a value in the range of [-1, LinesNumber()].
     */
    int LineIndexForPosition( CGPoint _position ) const noexcept;
    
private:
    std::shared_ptr<const TextModeWorkingSet> m_WorkingSet;
    std::vector<IndexedTextLine> m_Lines;
    nc::utility::FontGeometryInfo m_FontInfo;
};

inline const std::vector<IndexedTextLine>& TextModeFrame::Lines() const noexcept
{
    return m_Lines;
}

inline bool TextModeFrame::Empty() const noexcept
{
    return m_Lines.empty();
}

inline int TextModeFrame::LinesNumber() const noexcept
{
    return (int)m_Lines.size();
}
    
inline const IndexedTextLine& TextModeFrame::Line(int _index) const noexcept
{
    assert( _index >= 0 && _index < LinesNumber() );
    return m_Lines[_index];
}

}
