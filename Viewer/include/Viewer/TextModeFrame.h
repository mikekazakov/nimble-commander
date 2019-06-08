// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "TextModeWorkingSet.h"
#include "TextProcessing.h"
#include "TextModeIndexedTextLine.h"
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
    
    const std::vector<TextModeIndexedTextLine>& Lines() const noexcept;
    bool Empty() const noexcept;
    /** Returns the number of IndexedTextLine lines in the frame. */
    int LinesNumber() const noexcept;
    const TextModeIndexedTextLine& Line(int _index) const;
    double LineWidth(int _index) const;
    CGSize Bounds() const noexcept;
    
    /**
     * Returns an index of a character which corresponds to the pixel specified by _position.
     * If _position is located before the first character in the line, index of the first character
     * in the line will be returned. If _position is located after the last character in the line,
     * the index of the last character in the line + 1 will be returned.
     * This function assumes top-bottom Y coordidates increase.
     * (0., 0.) is assumed to be at the left-top corner of the first line.
     * This function guarantees to return a value in the range of [0, m_WorkinSet->Length()].
     * This function performs not a strict hit-testing, but instead it returns an index of caret
     * position which would correspond to the _position see CTLineGetStringIndexForPosition()
     * for more details.
     */
    int CharIndexForPosition( CGPoint _position ) const;
    
    /** Returns an index for a line corresponding to _position.
     * If _position is above any exisiting lines - will return -1.
     * If _position is below any exisiting lines - will return LinesNumber().
     * This function guarantees to return a value in the range of [-1, LinesNumber()].
     */
    int LineIndexForPosition( CGPoint _position ) const;
    
    /**
     * Returns a range [characters_begin, characters_end) corresponding a word substring in a
     * specified position. That's a behaviour of double-click selection.
     * Will always return a valid range, which can be empty.
     */
    std::pair<int, int> WordRangeForPosition( CGPoint _position ) const;
    
    /**
     * Returns the wrapping width which used to layout out this frame.
     */
    double WrappingWidth() const noexcept;
    
    /**
     * Returns the underlying immutable working set.
     */
    const TextModeWorkingSet &WorkingSet() const noexcept;

    /**
     * Returns the info on the font used to lay out the frame.
     */
    const nc::utility::FontGeometryInfo& FontGeometryInfo() const noexcept;
    
private:
    std::shared_ptr<const TextModeWorkingSet> m_WorkingSet;
    std::vector<TextModeIndexedTextLine> m_Lines;
    std::vector<float> m_LinesWidths;
    nc::utility::FontGeometryInfo m_FontInfo;
    CGSize m_Bounds;
    double m_WrappingWidth = 0.;
};

inline const std::vector<TextModeIndexedTextLine>& TextModeFrame::Lines() const noexcept
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
    
inline const TextModeIndexedTextLine& TextModeFrame::Line(int _index) const
{
    return m_Lines.at(_index);
}
    
inline double TextModeFrame::LineWidth(int _index) const
{
    return m_LinesWidths.at(_index);
}

inline double TextModeFrame::WrappingWidth() const noexcept
{
    return m_WrappingWidth;
}

inline const TextModeWorkingSet &TextModeFrame::WorkingSet() const noexcept
{
    return *m_WorkingSet;
}
    
inline const nc::utility::FontGeometryInfo& TextModeFrame::FontGeometryInfo() const noexcept
{
    return m_FontInfo;
}

inline CGSize TextModeFrame::Bounds() const noexcept
{
    return m_Bounds;
}
    
}
