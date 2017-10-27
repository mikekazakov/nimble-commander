// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontExtras.h>
#include "BigFileViewProtocol.h"

class BigFileViewHex : public BigFileViewImpl
{
public:
    BigFileViewHex(BigFileViewDataBackend* _data, BigFileView* _view);
    ~BigFileViewHex();
    
    virtual void OnBufferDecoded() override;
    virtual void OnFontSettingsChanged() override;
    virtual void DoDraw(CGContextRef _context, NSRect _dirty_rect) override;
    virtual void OnUpArrow() override;
    virtual void OnDownArrow() override;
    virtual void OnPageDown() override;
    virtual void OnPageUp() override;
    virtual uint32_t GetOffsetWithinWindow() override;
    virtual void MoveOffsetWithinWindow(uint32_t _offset) override;
    virtual void HandleVerticalScroll(double _pos) override;
    virtual void OnFrameChanged() override;
    virtual void ScrollToByteOffset(uint64_t _offset) override;
    virtual void OnMouseDown(NSEvent *_event) override;
    virtual void OnScrollWheel(NSEvent *theEvent) override;
    virtual void CalculateScrollPosition( double &_position, double &_knob_proportion ) override;    
private:
        
    enum class HitPart
    {
        RowOffset,
        DataDump,
        Text
    };
    
    struct TextLine;
    
    void GrabFontGeometry();
    void ClearLayout();
    CGPoint TextAnchor();
    HitPart PartHitTest(CGPoint _p);
    int ByteIndexFromHitTest(CGPoint _p);
    int CharIndexFromHitTest(CGPoint _p);
    void HandleSelectionWithMouseDragging(NSEvent* event);
    
    // basic stuff
    __unsafe_unretained BigFileView *m_View = nil;
    BigFileViewDataBackend          *m_Data = nullptr;
    unique_ptr<UniChar[]>           m_FixupWindow;
    unsigned                        m_RowsOffset  = 0;
    CGPoint                         m_SmoothOffset = {0, 0};
    int                             m_FrameLines  = 0; // amount of lines in our frame size ( +1 to fit cutted line also)
    FontGeometryInfo                m_FontInfo;
    double                          m_LeftInset   = 0;
    vector<TextLine>                m_Lines;
};
