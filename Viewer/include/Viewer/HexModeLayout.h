#pragma once

#include "HexModeFrame.h"

#include <optional>

namespace nc::viewer {
    
class HexModeLayout
{
public:
    struct ScrollOffset {
        int row = 0;
        double smooth = 0.;
    };
    struct Source {
        std::shared_ptr<const HexModeFrame> frame;
        CGSize view_size;
        ScrollOffset scroll_offset;
        long file_size;
    };
    struct ScrollerPosition {
        double position = 0.;
        double proportion = 1.;
    };
    HexModeLayout(const Source &_source);
    
    ScrollerPosition CalcScrollerPosition() const noexcept;
    int64_t CalcGlobalOffset() const noexcept;
    int64_t CalcGlobalOffsetForScrollerPosition(ScrollerPosition _scroller_position) const noexcept;
    
    ScrollOffset GetOffset() const noexcept;
    void SetOffset(ScrollOffset _new_offset);
    
    int RowsInView() const noexcept;
    int BytesInView() const noexcept;
    
    void SetFrame( std::shared_ptr<const HexModeFrame> _new_frame );
    
    void SetViewSize( CGSize _new_view_size );
    
    std::optional<int> FindRowToScrollWithGlobalOffset(int64_t _global_offset) const noexcept;
    
    static int FindEqualVerticalOffsetForRebuiltFrame(const HexModeFrame& old_frame,
                                                      const int old_vertical_offset,
                                                      const HexModeFrame& new_frame);
    
private:
    std::shared_ptr<const HexModeFrame> m_Frame;
    CGSize m_ViewSize;
    ScrollOffset m_ScrollOffset;
    long m_FileSize = 0;
};
    
inline HexModeLayout::ScrollOffset HexModeLayout::GetOffset() const noexcept
{
    return m_ScrollOffset;
}
    
}
