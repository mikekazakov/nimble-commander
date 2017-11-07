// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/algo.h>
#include <Utility/NSView+Sugar.h>
#include "BigFileViewText.h"
#include "BigFileView.h"

static unsigned ShouldBreakLineBySpaces(CFStringRef _string, unsigned _start, double _font_width, double _line_width)
{
    const auto len = CFStringGetLength(_string);
    const auto *chars = CFStringGetCharactersPtr(_string);
    assert(chars);
    
    double sum_space_width = 0.0;
    unsigned spaces_len = 0;
    
    for(unsigned i = _start; i < len; ++i)
    {
        if( chars[i] == ' ' )
        {
            sum_space_width += _font_width;
            spaces_len++;
            if(sum_space_width >= _line_width)
            {
                return spaces_len;
            }
        }
        else
        {
            break;
        }
    }
    
    if(_start + spaces_len == len)
        return spaces_len;
    
    return 0;
}

static unsigned ShouldCutTrailingSpaces(CFStringRef _string,
                                        CTTypesetterRef _setter,
                                        unsigned _start,
                                        unsigned _count,
                                        double _font_width,
                                        double _line_width)
{
    // 1st - count trailing spaces
    unsigned spaces_count = 0;
    const auto *chars = CFStringGetCharactersPtr(_string);
    assert(chars);
    
    for(int i = _start + _count - 1; i >= (int)_start; --i)
    {
        if(chars[i] == ' ')
            spaces_count++;
        else
            break;
    }
    
    if(!spaces_count)
        return 0;
    
    // 2nd - calc width of string without spaces
    assert(spaces_count <= _count); // logic assert
    if(spaces_count == _count)
        return 0;
    
    CTLineRef line = CTTypesetterCreateLine(_setter, CFRangeMake(_start, _count - spaces_count));
    double line_width = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
    CFRelease(line);
    if(line_width > _line_width)
        return 0; // guard from singular cases
//    assert(line_width < _line_width);
    
    // 3rd - calc residual space and amount of space characters to fill it
    double d = _line_width-line_width;
    unsigned n = unsigned(ceil(d / _font_width));
/*    assert(n <= spaces_count);
    unsigned extras = spaces_count - n;*/
    unsigned extras = spaces_count > n ? spaces_count - n : 0;
    
    return extras;
}

static void CleanUnicodeControlSymbols(UniChar *_s, size_t _n)
{
    for(size_t i = 0; i < _n; ++i)
    {
        UniChar c = _s[i];
        if(c >= 0x0080)
            continue;
        
        if(
           c == 0x0000 || // NUL
           c == 0x0001 || // SOH
           c == 0x0002 || // SOH
           c == 0x0003 || // STX
           c == 0x0004 || // EOT
           c == 0x0005 || // ENQ
           c == 0x0006 || // ACK
           c == 0x0007 || // BEL
           c == 0x0008 || // BS
           // c == 0x0009 || // HT
           // c == 0x000A || // LF
           c == 0x000B || // VT
           c == 0x000C || // FF
           // c == 0x000D || // CR
           c == 0x000E || // SO
           c == 0x000F || // SI
           c == 0x0010 || // DLE
           c == 0x0011 || // DC1
           c == 0x0012 || // DC2
           c == 0x0013 || // DC3
           c == 0x0014 || // DC4
           c == 0x0015 || // NAK
           c == 0x0016 || // SYN
           c == 0x0017 || // ETB
           c == 0x0018 || // CAN
           c == 0x0019 || // EM
           c == 0x001A || // SUB
           c == 0x001B || // ESC
           c == 0x001C || // FS
           c == 0x001D || // GS
           c == 0x001E || // RS
           c == 0x001F || // US
           c == 0x007F    // DEL
           )
        {
            _s[i] = ' ';
        }
        
        if(c == 0x000D && i + 1 < _n && _s[i+1] == 0x000A)
            _s[i] = ' '; // fix windows-like CR+LF newline to native LF
    }
}

struct BigFileViewText::TextLine
{
    TextLine()
    {
    }
    TextLine(TextLine &&_r)
    {
        unichar_no = _r.unichar_no;
        unichar_len = _r.unichar_len;
        byte_no = _r.byte_no;
        bytes_len = _r.bytes_len;
        line = _r.line;
        memset(&_r, 0, sizeof(TextLine));
    }
    ~TextLine()
    {
        if(line != 0)
        {
            CFRelease(line);
            line = 0;
        }
    }
    
    /**
     * index of a first unichar of this line whithin a window
     */
    uint32_t    unichar_no  = 0;
    
    /**
     * amount of unichars in this line
     */
    uint32_t    unichar_len = 0;
    
    /**
     * offset within file window of a current text line (offset of a first unichar of this line)
     */
    uint32_t    byte_no     = 0;
    
    
    uint32_t    bytes_len   = 0;
    CTLineRef   line        = 0;
  
    // helper functions
    inline bool uni_in(uint32_t _uni_ind) const
    {
        return _uni_ind >= unichar_no &&
               _uni_ind < unichar_no + unichar_len;
    }
    
    TextLine(const TextLine&) = delete;
    void operator=(const TextLine&) = delete;
};

BigFileViewText::BigFileViewText(BigFileViewDataBackend* _data, BigFileView* _view):
    m_FixupWindow(make_unique<UniChar[]>(m_Data->RawSize())), // unichar for every byte in raw window - should be ok in all cases
    m_View(_view),
    m_Data(_data),
    m_FrameSize(CGSizeMake(0, 0)),
    m_SmoothScroll(_data->IsFullCoverage())
{
    GrabFontGeometry();
    OnFrameChanged();
    OnBufferDecoded();
    [m_View setNeedsDisplay];
}

BigFileViewText::~BigFileViewText()
{
    ClearLayout();
    if(m_StringBuffer)
        CFRelease(m_StringBuffer);
}

void BigFileViewText::GrabFontGeometry()
{
    m_FontInfo = FontGeometryInfo( [m_View TextFont] );
}

void BigFileViewText::OnBufferDecoded()
{
    if(m_StringBuffer)
        CFRelease(m_StringBuffer);
    
    memcpy(&m_FixupWindow[0], m_Data->UniChars(), sizeof(UniChar) * m_Data->UniCharsSize());
    CleanUnicodeControlSymbols(&m_FixupWindow[0], m_Data->UniCharsSize());

    m_StringBuffer = CFStringCreateWithCharactersNoCopy(0, &m_FixupWindow[0], m_Data->UniCharsSize(), kCFAllocatorNull);
    m_StringBufferSize = CFStringGetLength(m_StringBuffer);

    BuildLayout();
}

void BigFileViewText::BuildLayout()
{
    ClearLayout();
    if(!m_StringBuffer)
        return;
    
    double wrapping_width = 10000;
    if(m_View.wordWrap)
        wrapping_width = m_View.contentBounds.width - m_LeftInset;

    m_AttrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    CFAttributedStringReplaceString(m_AttrString, CFRangeMake(0, 0), m_StringBuffer);
    CFAttributedStringSetAttribute(m_AttrString, CFRangeMake(0, m_StringBufferSize), kCTForegroundColorAttributeName, [m_View TextForegroundColor]);
    CFAttributedStringSetAttribute(m_AttrString, CFRangeMake(0, m_StringBufferSize), kCTFontAttributeName, [m_View TextFont]);

    
    // Create a typesetter using the attributed string.
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(m_AttrString);
    
    CFIndex start = 0;
    while(start < (unsigned)m_StringBufferSize)
    {
        // 1st - manual hack for breaking lines by space characters
        CFIndex count = 0;
        unsigned spaces = ShouldBreakLineBySpaces(m_StringBuffer, (unsigned)start, m_FontInfo.MonospaceWidth(), wrapping_width);
        if(spaces != 0)
        {
            count = spaces;
        }
        else
        {
            count = CTTypesetterSuggestLineBreak(typesetter, start, wrapping_width);
            if(count <= 0)
                break;
            
            unsigned tail_spaces_cut =  ShouldCutTrailingSpaces(m_StringBuffer,
                                                                typesetter,
                                                                (unsigned)start,
                                                                (unsigned)count,
                                                                m_FontInfo.MonospaceWidth(),
                                                                wrapping_width);
            count -= tail_spaces_cut;
        }
        
        // Use the returned character count (to the break) to create the line.
        m_Lines.emplace_back();
        TextLine &l = m_Lines.back();
        l.unichar_no = (uint32_t)start;
        l.unichar_len = (uint32_t)count;
        l.byte_no = m_Data->UniCharToByteIndeces()[start];
        l.bytes_len = m_Data->UniCharToByteIndeces()[start + count - 1] - l.byte_no;
        
        start += count;
    }

    // build our CTLines in multiple threads since it can be time-consuming
    dispatch_apply(m_Lines.size(), dispatch_get_global_queue(0, 0), ^(size_t n) {
        m_Lines[n].line = CTTypesetterCreateLine(typesetter, CFRangeMake(m_Lines[n].unichar_no, m_Lines[n].unichar_len));        
    });
    
    CFRelease(typesetter);
    
    if(m_VerticalOffset >= m_Lines.size())
        m_VerticalOffset = !m_Lines.empty() ? (unsigned)m_Lines.size()-1 : 0;
    
    [m_View setNeedsDisplay];
}

void BigFileViewText::ClearLayout()
{
    if(m_AttrString)
    {
        CFRelease(m_AttrString);
        m_AttrString = 0;
    }
    
    m_Lines.clear();
}

CGPoint BigFileViewText::TextAnchor()
{
    return NSMakePoint(ceil((m_LeftInset - m_HorizontalOffset * m_FontInfo.MonospaceWidth())) - m_SmoothOffset.x,
                       floor(m_View.contentBounds.height - m_FontInfo.LineHeight() + m_FontInfo.Descent()) + m_SmoothOffset.y);
}

int BigFileViewText::LineIndexFromYPos(double _y)
{
    CGPoint left_upper = TextAnchor();
    int y_off = (int)ceil((left_upper.y - _y) / m_FontInfo.LineHeight());
    int line_no = y_off + m_VerticalOffset;
    return line_no;
}

int BigFileViewText::CharIndexFromPoint(CGPoint _point)
{
    int line_no = LineIndexFromYPos(_point.y);
    if(line_no < 0)
        return -1;
    if(line_no >= (long)m_Lines.size())
        return (int)m_StringBufferSize + 1;
    
    const auto &line = m_Lines[line_no];

    int ind = (int)CTLineGetStringIndexForPosition(line.line, CGPointMake(_point.x - TextAnchor().x, 0));
    if(ind < 0)
        return -1;

    ind = clamp(ind, 0, (int)line.unichar_no + (int)line.unichar_len - 1); // TODO: check if this is right
    
    return ind;
}

void BigFileViewText::DoDraw(CGContextRef _context, NSRect _dirty_rect)
{
    //[m_View BackgroundFillColor].Set(_context);
    CGContextSetFillColorWithColor(_context, m_View.BackgroundFillColor);
    CGContextFillRect(_context, NSRectToCGRect(_dirty_rect));
    CGContextSetTextMatrix(_context, CGAffineTransformIdentity);
    CGContextSetTextDrawingMode(_context, kCGTextFill);
    CGContextSetShouldSmoothFonts(_context, true);
    CGContextSetShouldAntialias(_context, true);
    
    if(!m_StringBuffer) return;
    
    CGPoint pos = TextAnchor();
    
    double view_width = m_View.contentBounds.width;
    
    size_t first_string = m_VerticalOffset;
    if(m_SmoothOffset.y < 0 && first_string > 0)
    {
        --first_string; // to be sure that we can see bottom-clipped lines
        pos.y += m_FontInfo.LineHeight();
    }
    
    CFRange selection = [m_View SelectionWithinWindowUnichars];
    
     for(size_t i = first_string;
         i < m_Lines.size() && pos.y >= 0 - m_FontInfo.LineHeight();
         ++i, pos.y -= m_FontInfo.LineHeight())
     {
         auto &line = m_Lines[i];
         
         if(selection.location >= 0) // draw a selection background here
         {
             CGFloat x1 = 0, x2 = -1;
             if(line.unichar_no <= selection.location &&
                line.unichar_no + line.unichar_len > selection.location)
             {
                 x1 = pos.x + CTLineGetOffsetForStringIndex(line.line, selection.location, 0);
                 x2 = ((selection.location + selection.length <= line.unichar_no + line.unichar_len) ?
                       pos.x + CTLineGetOffsetForStringIndex(line.line,
                                                    (selection.location + selection.length <= line.unichar_no + line.unichar_len) ?
                                                    selection.location + selection.length : line.unichar_no + line.unichar_len,
                                               0) : view_width);
             }
             else if(selection.location + selection.length > line.unichar_no &&
                     selection.location + selection.length <= line.unichar_no + line.unichar_len )
             {
                 x1 = pos.x;
                 x2 = pos.x + CTLineGetOffsetForStringIndex(line.line, selection.location + selection.length, 0);
             }
             else if(selection.location < line.unichar_no &&
                     selection.location + selection.length > line.unichar_no + line.unichar_len)
             {
                 x1 = pos.x;
                 x2 = view_width;
             }

             if(x2 > x1)
             {
                 CGContextSaveGState(_context);
                 CGContextSetShouldAntialias(_context, false);
                 //m_View.SelectionBkFillColor.Set(_context);
                 CGContextSetFillColorWithColor(_context, m_View.SelectionBkFillColor);
                 CGContextFillRect(_context, CGRectMake(x1, pos.y - m_FontInfo.Descent(), x2 - x1, m_FontInfo.LineHeight()));
                 CGContextRestoreGState(_context);
             }
         }
         
         CGContextSetTextPosition(_context, pos.x, pos.y);
         CTLineDraw(line.line, _context);
     }
}

void BigFileViewText::CalculateScrollPosition( double &_position, double &_knob_proportion )
{
    _position = 0.0;
    _knob_proportion = 1.0;
    
    if(!m_SmoothScroll)
    {
        if(m_VerticalOffset < m_Lines.size())
        {
            uint64_t byte_pos = m_Lines[m_VerticalOffset].byte_no + m_Data->FilePos();
            uint64_t last_visible_byte_pos =
            ((m_VerticalOffset + m_FrameLines < m_Lines.size()) ?
             m_Lines[m_VerticalOffset + m_FrameLines].byte_no :
             m_Lines.back().byte_no )
            + m_Data->FilePos();;
            uint64_t byte_scroll_size = m_Data->FileSize() - (last_visible_byte_pos - byte_pos);
            double prop = double(last_visible_byte_pos - byte_pos) / double(m_Data->FileSize());
            _position = double(byte_pos) / double(byte_scroll_size);
            _knob_proportion = prop;
        }
    }
    else
    {
        double pos = 0.;
        if((int)m_Lines.size() > m_FrameLines)
            pos = double(m_VerticalOffset) / double(m_Lines.size() - m_FrameLines);
        double prop = 1.;
        if((int)m_Lines.size() > m_FrameLines)
            prop = double(m_FrameLines) / double(m_Lines.size());
        _position = pos;
        _knob_proportion = prop;
    }
}


void BigFileViewText::MoveLinesDelta(int _delta)
{
    if(m_Lines.empty())
        return;
    
    assert(m_VerticalOffset < m_Lines.size());
    
    const uint64_t window_pos = m_Data->FilePos();
    const uint64_t window_size = m_Data->RawSize();
    const uint64_t file_size = m_Data->FileSize();
    
    if(_delta < 0)
    { // we're moving up
        // check if we can satisfy request within our current window position, without moving it
        if((int)m_VerticalOffset + _delta >= 0)
        {
            // ok, just scroll within current window
            m_VerticalOffset += _delta;
        }
        else
        {
            // nope, we need to move file window if it is possible
            if(window_pos > 0)
            { // ok, can move - there's a space
                uint64_t anchor_glob_offset = m_Lines[m_VerticalOffset].byte_no + window_pos;
                int anchor_pos_on_screen = -_delta;
                
                // TODO: need something more intelligent here
                uint64_t desired_window_offset = anchor_glob_offset > 3*window_size/4 ?
                                                    anchor_glob_offset - 3*window_size/4 :
                                                    0;
                MoveFileWindowTo(desired_window_offset, anchor_glob_offset, anchor_pos_on_screen);
            }
            else
            { // window is already at the top, need to move scroll within window
                m_SmoothOffset.y = 0;
                m_VerticalOffset = 0;
            }
        }
        [m_View setNeedsDisplay];
    }
    else if(_delta > 0)
    { // we're moving down
        if(m_VerticalOffset + _delta + m_FrameLines < m_Lines.size() )
        { // ok, just scroll within current window
            m_VerticalOffset += _delta;
        }
        else
        { // nope, we need to move file window if it is possible
            if(window_pos + window_size < file_size)
            { // ok, can move - there's a space
                size_t anchor_index = MIN(m_VerticalOffset + _delta - 1, m_Lines.size() - 1);
                int anchor_pos_on_screen = -1;
                
                uint64_t anchor_glob_offset = m_Lines[anchor_index].byte_no + window_pos;

                assert(anchor_glob_offset > window_size/4); // internal logic check
                // TODO: need something more intelligent here
                uint64_t desired_window_offset = anchor_glob_offset - window_size/4;
                desired_window_offset = clamp(desired_window_offset, 0ull, file_size - window_size);
                
                MoveFileWindowTo(desired_window_offset, anchor_glob_offset, anchor_pos_on_screen);
            }
            else
            { // just move offset to the end within our window
                if(m_VerticalOffset + m_FrameLines < m_Lines.size())
                    m_VerticalOffset = (unsigned)m_Lines.size() - m_FrameLines;
            }
        }
        [m_View setNeedsDisplay];
    }
}

void BigFileViewText::OnUpArrow()
{
    MoveLinesDelta(-1);
}

void BigFileViewText::OnDownArrow()
{
    MoveLinesDelta(1);
}

void BigFileViewText::OnPageDown()
{
    MoveLinesDelta(m_FrameLines);
}

void BigFileViewText::OnPageUp()
{
    MoveLinesDelta(-m_FrameLines);
}

void BigFileViewText::MoveFileWindowTo(uint64_t _pos, uint64_t _anchor_byte_no, int _anchor_line_no)
{
    // now move our file window
    // data updating and layout stuff are called implicitly after that call
    [m_View RequestWindowMovementAt:_pos];
    
    // now we need to find a line which is at last_top_line_glob_offset position
    if(m_Lines.empty())
    {
        m_VerticalOffset = 0;
        return;
    }
        
    int closest_ind = FindClosestNotGreaterLineInd(_anchor_byte_no);
    
    m_VerticalOffset = max(closest_ind - _anchor_line_no, 0);
    
    assert(m_VerticalOffset < m_Lines.size());
    [m_View setNeedsDisplay];
}

int BigFileViewText::FindClosestLineInd(uint64_t _glob_offset) const
{
    if(m_Lines.empty())
        return -1;

    const uint64_t window_pos = m_Data->FilePos();
    
    auto lower = lower_bound(begin(m_Lines), end(m_Lines), _glob_offset, [=](auto &l, auto r){
        return (uint64_t)l.byte_no + window_pos < r;
    });

    size_t closest_ind = 0;
    
    if(lower == end(m_Lines))
        closest_ind = m_Lines.size() - 1;
    else if(lower == begin(m_Lines))
        closest_ind = 0;
    else {
        closest_ind = lower - begin(m_Lines);
        
        // if didn't found exactly requested line
        uint64_t d1 = (uint64_t)lower->byte_no + window_pos - _glob_offset;
        if(d1 != 0)
        { // then compare with prev element
            auto prev = lower - 1;
            if(_glob_offset - (uint64_t)prev->byte_no - window_pos < d1)
                closest_ind = prev - begin(m_Lines);
        }
    }
    
    return (int)closest_ind;
}

int BigFileViewText::FindClosestNotGreaterLineInd(uint64_t _glob_offset) const
{
    if(m_Lines.empty())
        return -1;
    
    const uint64_t window_pos = m_Data->FilePos();
    
    auto lower = lower_bound(begin(m_Lines), end(m_Lines), _glob_offset, [=](auto &l, auto r){
        return (uint64_t)l.byte_no + window_pos < r;
    });
    
    size_t closest_ind = 0;
    
    if(lower == end(m_Lines))
        closest_ind = m_Lines.size() - 1;
    else if(lower == begin(m_Lines))
        closest_ind = 0;
    else {
        closest_ind = lower - begin(m_Lines);
        if((uint64_t)lower->byte_no + window_pos != _glob_offset)
            --closest_ind;
    }
    
    return (int)closest_ind;
}

uint32_t BigFileViewText::GetOffsetWithinWindow()
{
    if(!m_Lines.empty())
    {
        assert(m_VerticalOffset < m_Lines.size());
        return m_Lines[m_VerticalOffset].byte_no;
    }
    else
    {
        assert(m_VerticalOffset == 0);
        return 0;
    }
}

void BigFileViewText::MoveOffsetWithinWindow(uint32_t _offset)
{
    m_VerticalOffset = max(FindClosestLineInd(_offset + m_Data->FilePos()), 0);
    assert(m_Lines.empty() || m_VerticalOffset < m_Lines.size());
}

void BigFileViewText::ScrollToByteOffset(uint64_t _offset)
{
    const uint64_t window_pos = m_Data->FilePos();
    const uint64_t window_size = m_Data->RawSize();
    const uint64_t file_size = m_Data->FileSize();
    
    m_SmoothOffset.y = 0; // reset vertical smoothing on any scrolling-to-line
    
    if((_offset >= window_pos && _offset < window_pos + window_size) ||
       (_offset == file_size && window_pos + window_size == file_size) )
    {
        // seems that we can satisfy this request immediately, without I/O
        int closest = FindClosestNotGreaterLineInd(_offset);
        if((unsigned)closest + m_FrameLines < m_Lines.size())
        { // check that we will fill whole screen after scrolling
            m_VerticalOffset = (unsigned)closest;
            [m_View setNeedsDisplay];
            return;
        }
        else if(window_pos + window_size == file_size)
        { // trying to scroll below bottom
            m_VerticalOffset = clamp((int)m_Lines.size()-m_FrameLines, 0, (int)m_Lines.size()-1);
            [m_View setNeedsDisplay];
            return;
        }
    }

    // nope, we need to perform I/O - to move file window
    uint64_t desired_wnd_pos = _offset > window_size / 2 ?
                                _offset - window_size / 2 :
                                0;
    desired_wnd_pos = clamp(desired_wnd_pos, 0ull, file_size - window_size);
    
    MoveFileWindowTo(desired_wnd_pos, _offset, 0);
    
    assert(m_Lines.empty() || m_VerticalOffset < m_Lines.size());
}

void BigFileViewText::HandleVerticalScroll(double _pos)
{
    if(!m_SmoothScroll)
    { // scrolling by bytes offset
        uint64_t file_size = m_Data->FileSize();
        uint64_t bytepos = uint64_t( _pos * double(file_size) ); // need to substract current screen's size in bytes
        ScrollToByteOffset(bytepos);
        
        if((int)m_Lines.size() - (int)m_VerticalOffset < m_FrameLines )
            m_VerticalOffset = (int)m_Lines.size() - m_FrameLines;

        m_SmoothOffset.y = 0;
    }
    else
    { // we have all file decomposed into strings, so we can do smooth scrolling now
        double full_document_size = double(m_Lines.size()) * m_FontInfo.LineHeight();
        double scroll_y_offset = _pos * (full_document_size - m_FrameSize.height);
        m_VerticalOffset = (unsigned)floor(scroll_y_offset / m_FontInfo.LineHeight());
        m_SmoothOffset.y = scroll_y_offset - m_VerticalOffset * m_FontInfo.LineHeight();
        [m_View setNeedsDisplay];
    }
    assert(m_Lines.empty() || m_VerticalOffset < m_Lines.size());
}

void BigFileViewText::OnScrollWheel(NSEvent *theEvent)
{
    double delta_y = theEvent.scrollingDeltaY;
    double delta_x = theEvent.scrollingDeltaX;
    if(!theEvent.hasPreciseScrollingDeltas)
    {
        delta_y *= m_FontInfo.LineHeight();
        delta_x *= m_FontInfo.MonospaceWidth();
    }
    
    // vertical scrolling
    if(!m_SmoothScroll)
    {
        if((delta_y > 0 && (m_Data->FilePos() > 0 ||
                            m_VerticalOffset > 0)       ) ||
           (delta_y < 0 && (m_Data->FilePos() + m_Data->RawSize() < m_Data->FileSize() ||
                            m_VerticalOffset + m_FrameLines < m_Lines.size()) )
           )
        {
            m_SmoothOffset.y -= delta_y;
        
            while(m_SmoothOffset.y < -m_FontInfo.LineHeight()) {
                OnUpArrow();
                m_SmoothOffset.y += m_FontInfo.LineHeight();
            }
            while(m_SmoothOffset.y > m_FontInfo.LineHeight()) {
                OnDownArrow();
                m_SmoothOffset.y -= m_FontInfo.LineHeight();
            }
        }
        else
            return;
    }
    else
    {
        if((delta_y > 0 && m_VerticalOffset > 0) ||
           (delta_y < 0 && m_VerticalOffset + m_FrameLines < m_Lines.size()) )
        {
            m_SmoothOffset.y -= delta_y;
            if(m_SmoothOffset.y < -m_FontInfo.LineHeight())
            {
                int dl = int(-m_SmoothOffset.y / m_FontInfo.LineHeight());
                if((int)m_VerticalOffset > dl) m_VerticalOffset -= dl;
                else m_VerticalOffset = 0;
                m_SmoothOffset.y += dl * m_FontInfo.LineHeight();
            }
            else if(m_SmoothOffset.y > m_FontInfo.LineHeight())
            {
                int dl = int(m_SmoothOffset.y / m_FontInfo.LineHeight());
                if(m_VerticalOffset + m_FrameLines + dl < m_Lines.size()) m_VerticalOffset += dl;
                else m_VerticalOffset = (int)m_Lines.size() - m_FrameLines;
                m_SmoothOffset.y -= dl * m_FontInfo.LineHeight();
            }
        }
        else
            return;
    }
    
    // horizontal scrolling
    if( !m_View.wordWrap && ((delta_x > 0 && m_HorizontalOffset > 0) || delta_x < 0) )
    {
        m_SmoothOffset.x -= delta_x;
        if(m_SmoothOffset.x > m_FontInfo.MonospaceWidth())
        {
            int dx = int(m_SmoothOffset.x / m_FontInfo.MonospaceWidth());
            m_HorizontalOffset += dx;
            m_SmoothOffset.x -= dx * m_FontInfo.MonospaceWidth();
            
        }
        else if(m_SmoothOffset.x < -m_FontInfo.MonospaceWidth())
        {
            int dx = int(-m_SmoothOffset.x / m_FontInfo.MonospaceWidth());
            if((int)m_HorizontalOffset > dx) m_HorizontalOffset -= dx;
            else m_HorizontalOffset = 0;
            m_SmoothOffset.x += dx * m_FontInfo.MonospaceWidth();
        }
    }
    
    // edge-case clipping (not allowing to appear a gap before first line or after last line or before the first line's character)
    if(m_Data->FilePos() == 0 &&
       m_VerticalOffset == 0 &&
       m_SmoothOffset.y < 0)
        m_SmoothOffset.y = 0;
    if(m_Data->FilePos() + m_Data->RawSize() == m_Data->FileSize() &&
       m_VerticalOffset + m_FrameLines >= m_Lines.size() &&
       m_SmoothOffset.y > 0 )
        m_SmoothOffset.y = 0;
    if(m_HorizontalOffset == 0 && m_SmoothOffset.x > 0)
        m_SmoothOffset.x = 0;
    
    [m_View setNeedsDisplay];
    assert(m_Lines.empty() || m_VerticalOffset < m_Lines.size());
}

void BigFileViewText::OnFrameChanged()
{
    NSSize sz = m_View.contentBounds;
    m_FrameLines = int(sz.height / m_FontInfo.LineHeight());

    if(m_FrameSize.width != sz.width)
        BuildLayout();
    m_FrameSize = sz;
}

void BigFileViewText::OnWordWrappingChanged()
{
    BuildLayout();
    if(m_VerticalOffset >= m_Lines.size())
    {
        if((int)m_Lines.size() >= m_FrameLines)
            m_VerticalOffset = (int)m_Lines.size() - m_FrameLines;
        else
            m_VerticalOffset = 0;
    }
    m_HorizontalOffset = 0;
    m_SmoothOffset.x = 0;
}

void BigFileViewText::OnFontSettingsChanged()
{
    GrabFontGeometry();
    OnFrameChanged();
    BuildLayout();
}

void BigFileViewText::OnLeftArrow()
{
    if(m_View.wordWrap)
        return;
    
    m_HorizontalOffset -= m_HorizontalOffset > 0 ? 1 : 0;
    [m_View setNeedsDisplay];
}

void BigFileViewText::OnRightArrow()
{
    if(m_View.wordWrap)
        return;
    
    m_HorizontalOffset++;
    [m_View setNeedsDisplay];
}

void BigFileViewText::OnMouseDown(NSEvent *event)
{
    if(event.clickCount > 2)
        HandleSelectionWithTripleClick(event);
    else if (event.clickCount == 2)
        HandleSelectionWithDoubleClick(event);
    else
        HandleSelectionWithMouseDragging(event);
}

void BigFileViewText::HandleSelectionWithTripleClick(NSEvent* event)
{
    int line_no = LineIndexFromPos([m_View convertPoint:event.locationInWindow fromView:nil]);
    if(line_no < 0 || line_no >= (int)m_Lines.size())
        return;
    
    auto &i = m_Lines[line_no];
    int sel_start = i.unichar_no;
    int sel_end = i.unichar_no + i.unichar_len;
    int sel_start_byte = m_Data->UniCharToByteIndeces()[sel_start];
    int sel_end_byte = sel_end < (long)m_StringBufferSize ?
        m_Data->UniCharToByteIndeces()[sel_end] :
        (int)m_Data->RawSize();
    m_View.selectionInFile = CFRangeMake(sel_start_byte + m_Data->FilePos(), sel_end_byte - sel_start_byte);
}

void BigFileViewText::HandleSelectionWithDoubleClick(NSEvent* event)
{
    NSPoint pt = [m_View convertPoint:[event locationInWindow] fromView:nil];
    int uc_index = clamp(CharIndexFromPoint(pt), 0, (int)m_StringBufferSize);

    __block int sel_start = 0, sel_end = 0;
    
    // this is not ideal implementation since here we search in whole buffer
    // it has O(n) from hit-test position, which it not good
    // consider background dividing of buffer in chunks regardless of UI events
    NSString *string = (__bridge NSString *) m_StringBuffer;    
    [string enumerateSubstringsInRange:NSMakeRange(0, m_StringBufferSize)
                               options:NSStringEnumerationByWords | NSStringEnumerationSubstringNotRequired
                            usingBlock:^(NSString *word,
                                         NSRange wordRange,
                                         NSRange enclosingRange,
                                         BOOL *stop){
                                if(NSLocationInRange(uc_index, wordRange))
                                {
                                    sel_start = (int)wordRange.location;
                                    sel_end   = (int)wordRange.location + (int)wordRange.length;
                                    *stop = YES;
                                }
                                else if((int)wordRange.location > uc_index)
                                    *stop = YES;
                            }];
    
    if(sel_start == sel_end) // select single character
    {
        sel_start = uc_index;
        sel_end   = uc_index + 1;        
    }

    int sel_start_byte = m_Data->UniCharToByteIndeces()[sel_start];
    int sel_end_byte = sel_end < (long)m_StringBufferSize ?
        m_Data->UniCharToByteIndeces()[sel_end] :
        (int)m_Data->RawSize();
    m_View.selectionInFile = CFRangeMake(sel_start_byte + m_Data->FilePos(), sel_end_byte - sel_start_byte);
}

void BigFileViewText::HandleSelectionWithMouseDragging(NSEvent* event)
{
    bool modifying_existing_selection = (event.modifierFlags & NSShiftKeyMask) ? true : false;
    
    NSPoint first_down = [m_View convertPoint:event.locationInWindow fromView:nil];
    int first_ind = clamp(CharIndexFromPoint(first_down), 0, (int)m_StringBufferSize);
    
    CFRange orig_sel = [m_View SelectionWithinWindowUnichars];
    
    while (event.type != NSLeftMouseUp)
    {
        NSPoint curr_loc = [m_View convertPoint:event.locationInWindow fromView:nil];
        int curr_ind = clamp(CharIndexFromPoint(curr_loc), 0, (int)m_StringBufferSize);
        
        int base_ind = first_ind;
        if(modifying_existing_selection && orig_sel.length > 0)
        {
            if(first_ind > orig_sel.location && first_ind <= orig_sel.location + orig_sel.length)
                base_ind =
                first_ind - orig_sel.location > orig_sel.location + orig_sel.length - first_ind ?
                (int)orig_sel.location : (int)orig_sel.location + (int)orig_sel.length;
            else if(first_ind < orig_sel.location + orig_sel.length && curr_ind < orig_sel.location + orig_sel.length)
                base_ind = (int)orig_sel.location + (int)orig_sel.length;
            else if(first_ind > orig_sel.location && curr_ind > orig_sel.location)
                base_ind = (int)orig_sel.location;
        }
        
        if(base_ind != curr_ind)
        {
            int sel_start = base_ind > curr_ind ? curr_ind : base_ind;
            int sel_end   = base_ind < curr_ind ? curr_ind : base_ind;
            int sel_start_byte = m_Data->UniCharToByteIndeces()[sel_start];
            int sel_end_byte = sel_end < (long)m_StringBufferSize ?
                m_Data->UniCharToByteIndeces()[sel_end] :
                (int)m_Data->RawSize();
            assert(sel_end_byte >= sel_start_byte);
            m_View.selectionInFile = CFRangeMake(sel_start_byte + m_Data->FilePos(), sel_end_byte - sel_start_byte);
        }
        else
            m_View.selectionInFile = CFRangeMake(-1,0);
        
        event = [m_View.window nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
    }
}
