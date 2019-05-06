#pragma once

#include "HexModeFrame.h"

#include <optional>

namespace nc::viewer {
    

/****
 * Horizontal layout:
 * (left_inset)[address](address_columns_gap)[column1](columns_gap)..(columns_snippet_gap)
 * [snippet]
 */
class HexModeLayout
{
public:
    struct ScrollOffset {
        int row = 0;
        double smooth = 0.;
        ScrollOffset WithoutSmoothOffset() const noexcept;
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
    struct Gaps {
        double left_inset = 4.;
        double address_columns_gap = 32.;
        double between_columns_gap = 16.;
        double columns_snippet_gap = 32.;
    };
    struct HorizontalOffsets {
        double address;
        double snippet;
        std::vector<double> columns;
    };
    enum class HitPart {
        Address, AddressColumsGap, Columns, ColumnsSnippetGap, Snippet
    };
    HexModeLayout(const Source &_source);
    
    ScrollerPosition CalcScrollerPosition() const noexcept;
    int64_t CalcGlobalOffset() const noexcept;
    int64_t CalcGlobalOffsetForScrollerPosition(ScrollerPosition _scroller_position) const noexcept;
    
    ScrollOffset GetOffset() const noexcept;
    void SetOffset(ScrollOffset _new_offset);
    
    /** Number of rows that can theoretically fit in the view without being clipped */
    int RowsInView() const noexcept;
    /** Number of bytes that can theoretically be presented in the view without being clipped */
    int BytesInView() const noexcept;
    
    void SetFrame( std::shared_ptr<const HexModeFrame> _new_frame );
    
    void SetViewSize( CGSize _new_view_size );
    
    std::optional<int> FindRowToScrollWithGlobalOffset(int64_t _global_offset) const noexcept;
        
    void SetGaps( Gaps _gaps );
    Gaps GetGaps() const noexcept;
    
    HorizontalOffsets CalcHorizontalOffsets() const noexcept;
    
    /**
     * Does a primitive hit-testing, considering only a horizontal position.
     * Does not take into consideration any real row of the frame.
     */
    HitPart HitTest(double _x) const;
    
    /**
     * Returns a range [x1, x2) which should be highlighted in columns to reflect a selected
     * range(_bytes_selection) inside a working set. Returns {0., 0.} if there's no intersection.
     */
    std::pair<double, double> CalcColumnSelectionBackground(CFRange _bytes_selection,
                                                            int _row,
                                                            int _colum,
                                                            const HorizontalOffsets& _offsets)const;

    /**
     * Returns a range [x1, x2) which should be highlighted in a snippet to reflect a selected
     * range(_chars_selection) inside a working set. Returns {0., 0.} if there's no intersection.
     */
    std::pair<double, double>
    CalcSnippetSelectionBackground(CFRange _chars_selection,
                                   int _row,
                                   const HorizontalOffsets& _offsets) const;
    
    /**
     * Returns an index of a row which corresponds to the specified Y coordinate.
     * If the coordinate is above any existing content, -1 is returned.
     * If the coordinate is below any existing content, Frame->NumberOfRow() is returned.
     */
    int RowIndexFromYCoordinate(double _y) const;
    
    /** Returns a byte offset inside a working set which corresponds to the position. */
    int ByteOffsetFromColumnHit(CGPoint _position) const;
    
    /** Returns a char offset inside a working set which corresponds to the position. */
    int CharOffsetFromSnippetHit(CGPoint _position) const;
    
    static int FindEqualVerticalOffsetForRebuiltFrame(const HexModeFrame& old_frame,
                                                      const int old_vertical_offset,
                                                      const HexModeFrame& new_frame);

    /**
     * Returns a pair of indices [start, end) which represents selection with given:
     * - originally existed selection, which is taken into consideration when _modifiying_existing
     *   is true;
     * - first mouse hit index;
     * - current mouse hit index.
     */
    static std::pair<int, int> MergeSelection(CFRange _existing_selection,
                                              bool _modifiying_existing,
                                              int _first_mouse_hit_index,
                                              int _current_mouse_hit_index) noexcept;
    
private:
    std::shared_ptr<const HexModeFrame> m_Frame;
    CGSize m_ViewSize;
    ScrollOffset m_ScrollOffset;
    long m_FileSize = 0;
    Gaps m_Gaps;
};
    
inline HexModeLayout::ScrollOffset HexModeLayout::GetOffset() const noexcept
{
    return m_ScrollOffset;
}
 
inline HexModeLayout::ScrollOffset HexModeLayout::ScrollOffset::WithoutSmoothOffset() const noexcept
{
    ScrollOffset offset;
    offset.row = row;
    return offset;
}
    
inline HexModeLayout::Gaps HexModeLayout::GetGaps() const noexcept
{
    return m_Gaps;
}

}
