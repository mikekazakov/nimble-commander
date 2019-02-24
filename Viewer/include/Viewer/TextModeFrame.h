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
    int LinesNumber() const noexcept;
    const IndexedTextLine& Line(int _index) const noexcept;
    
private:
    std::shared_ptr<const TextModeWorkingSet> m_WorkingSet;
    std::vector<IndexedTextLine> m_Lines;
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
