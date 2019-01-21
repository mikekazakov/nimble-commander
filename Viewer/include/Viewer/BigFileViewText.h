// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontExtras.h>
#include "BigFileViewProtocol.h"

class BigFileViewText : public BigFileViewImpl
{
public:
    BigFileViewText(BigFileViewDataBackend* _data, BigFileView* _view);
    ~BigFileViewText();
    
    virtual void OnBufferDecoded() override;
    virtual void OnFrameChanged() override;
    virtual void DoDraw(CGContextRef _context, NSRect _dirty_rect) override;
    virtual void OnUpArrow() override;
    virtual void OnDownArrow() override;
    virtual void OnPageDown() override;
    virtual void OnPageUp() override;
    virtual uint32_t GetOffsetWithinWindow() override;
    virtual void MoveOffsetWithinWindow(uint32_t _offset) override;
    virtual void ScrollToByteOffset(uint64_t _offset) override;
    virtual void HandleVerticalScroll(double _pos) override;
    virtual void OnScrollWheel(NSEvent *theEvent) override;
    virtual void OnMouseDown(NSEvent *_event) override;
    virtual void OnWordWrappingChanged() override;
    virtual void OnFontSettingsChanged() override;
    virtual void OnLeftArrow() override;
    virtual void OnRightArrow() override;
    virtual void CalculateScrollPosition( double &_position, double &_knob_proportion ) override;
    
private:
    void GrabFontGeometry();
    void ClearLayout();
    void BuildLayout();
    
    /**
     * returns a offset for a left-top symbol of a text in a file window.
     * not accounting scrolling, only visual smoothing position and font config.
     */
    CGPoint TextAnchor();
    
    int LineIndexFromYPos(double _y);
    inline int LineIndexFromPos(CGPoint _point) { return LineIndexFromYPos(_point.y); };
    int CharIndexFromPoint(CGPoint _point);
    
    /**
     * move our file window to '_pos' global offset,
     * making line starting with '_anchor_byte_no' global byte offset
     * positioned at '_anchor_line_no' offset from the top of screen
     */
    void MoveFileWindowTo(uint64_t _pos, uint64_t _anchor_byte_no, int _anchor_line_no);
    
    void HandleSelectionWithTripleClick(NSEvent* event);
    void HandleSelectionWithDoubleClick(NSEvent* event);
    void HandleSelectionWithMouseDragging(NSEvent* event);
    void MoveLinesDelta(int _delta);
    
    /**
     * will return -1 on empty lines container, valid index otherwise.
     * O( log2(N) ) complexity.
     */
    int FindClosestLineInd(uint64_t _glob_offset) const;
    
    /**
     * Look at FindClosestLineInd();
     */
    int FindClosestNotGreaterLineInd(uint64_t _glob_offset) const;
    
    struct TextLine;

    // basic stuff
    __unsafe_unretained BigFileView      *m_View;
    BigFileViewDataBackend  *m_Data = nullptr;
    
    // data stuff
    std::unique_ptr<UniChar[]>  m_FixupWindow;
    CFStringRef                 m_StringBuffer = nullptr;
    size_t                      m_StringBufferSize = 0;
    
    // layout stuff
    nc::utility::FontGeometryInfo m_FontInfo;
    double                       m_LeftInset = 5;
    CFMutableAttributedStringRef m_AttrString = nullptr;
    std::vector<TextLine>        m_Lines;
    unsigned                     m_VerticalOffset = 0; // offset in lines number within text lines
    unsigned                     m_HorizontalOffset = 0; // offset in characters from the left window edge
    
    int                          m_FrameLines = 0; // amount of lines in our frame size ( +1 to fit cutted line also)
    
    CGSize                       m_FrameSize = {0, 0};
    bool                         m_SmoothScroll = true; // turned on when we can view all file in file window without movements
    CGPoint                      m_SmoothOffset = {0, 0};
};
