// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontExtras.h>
#include "BigFileViewProtocol.h"
#include "TextModeFrame.h"

namespace nc::viewer {

class TextModeIndexedTextLine;
class TextModeWorkingSet;

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
    void BuildLayout();
    
    /**
     * returns a offset for a left-top symbol of a text in a file window.
     * not accounting scrolling, only visual smoothing position and font config.
     */
    CGPoint TextAnchor();
    
    CGPoint ToFrameCoords(CGPoint _view_coords);
    
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
    
    // basic stuff
    __unsafe_unretained BigFileView      *m_View;
    BigFileViewDataBackend  *m_Data = nullptr;
    
    // data stuff
    std::shared_ptr<const TextModeWorkingSet> m_WorkingSet;
    
    // layout stuff
    nc::utility::FontGeometryInfo m_FontInfo;
    double                       m_LeftInset = 5;
    
    std::shared_ptr<const TextModeFrame> m_Frame;
    int                          m_VerticalOffset = 0; // offset in lines number within text lines
    unsigned                     m_HorizontalOffset = 0; // offset in characters from the left window edge
    
    int                          m_FrameLines = 0; // amount of lines in our frame size ( +1 to fit cutted line also)
    
    CGSize                       m_FrameSize = {0, 0};
    bool                         m_SmoothScroll = true; // turned on when we can view all file in file window without movements
    CGPoint                      m_SmoothOffset = {0, 0};
};

}

