//
//  BigFileViewText.h
//  ViewerBase
//
//  Created by Michael G. Kazakov on 09.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BigFileViewProtocol.h"

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
    
private:
    void GrabFontGeometry();
    void ClearLayout();
    void BuildLayout();
    CGPoint TextAnchor();
    int CharIndexFromPoint(CGPoint _point);
    void UpdateVerticalScrollBar();
    void MoveFileWindowTo(uint64_t _pos, uint64_t _anchor_byte_no, int _anchor_line_no);
    void HandleSelectionWithTripleClick(NSEvent* event);
    void HandleSelectionWithDoubleClick(NSEvent* event);
    void HandleSelectionWithMouseDragging(NSEvent* event);
    
    struct TextLine
    {
        uint32_t    unichar_no;      // index of a first unichar whitin a window
        uint32_t    unichar_len;
        uint32_t    byte_no;         // offset within file window of a current text line
        uint32_t    bytes_len;
        CTLineRef   line;
    };

    // basic stuff
    __unsafe_unretained BigFileView      *m_View;
    BigFileViewDataBackend  *m_Data = nullptr;
    
    // data stuff
    unique_ptr<UniChar[]>       m_FixupWindow;
    CFStringRef                 m_StringBuffer = nullptr;
    size_t                      m_StringBufferSize = 0;
    
    // layout stuff
    double                      m_FontHeight = 0;
    double                      m_FontAscent = 0;
    double                      m_FontDescent = 0;
    double                      m_FontLeading = 0;
    double                      m_FontWidth = 0;
    double                      m_LeftInset = 0;
    CFMutableAttributedStringRef m_AttrString = nullptr;
    vector<TextLine>             m_Lines;
    unsigned                     m_VerticalOffset = 0; // offset in lines number within text lines
    unsigned                     m_HorizontalOffset = 0; // offset in characters from the left window edge
    
    int                          m_FrameLines = 0; // amount of lines in our frame size ( +1 to fit cutted line also)
    
    CGSize                       m_FrameSize = {0, 0};
    bool                         m_SmoothScroll = true; // turned on when we can view all file in file window without movements
    CGPoint                      m_SmoothOffset = {0, 0};
};