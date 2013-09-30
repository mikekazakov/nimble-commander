//
//  BigFileViewText.m
//  ViewerBase
//
//  Created by Michael G. Kazakov on 09.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <vector>
#import <algorithm>
#import "BigFileViewText.h"
#import "BigFileView.h"
#import "Common.h"
#import "FontExtras.h"


static inline int CropIndex(int _val, int _max_possible)
{
    if(_val < 0) return 0;
    if(_val > _max_possible) return _max_possible;
    return _val;
}

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
//    const auto len = CFStringGetLength(_string);
    
    for(int i = _start + _count - 1; i >= _start; --i)
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
        
        if(c == 0x000D && i + 1< _n && _s[i+1] == 0x000A)
            _s[i] = ' '; // fix windows-like CR+LF newline to native LF
    }
}

struct TextLine
{
    uint32_t    unichar_no;      // index of a first unichar whitin a window
    uint32_t    unichar_len;
    uint32_t    byte_no;         // offset within file window of a current text line
    uint32_t    bytes_len;
    CTLineRef   line;
};

@implementation BigFileViewText
{
    // basic stuff
    BigFileView             *m_View;
    BigFileViewDataBackend  *m_Data;

    // data stuff
    UniChar        *m_FixupWindow;
    CFStringRef     m_StringBuffer;
    size_t          m_StringBufferSize; // should be equal to m_WindowSize
        
    // layout stuff
    double                      m_FontHeight;
    double                      m_FontAscent;
    double                      m_FontDescent;
    double                      m_FontLeading;
    double                      m_FontWidth;
    double                      m_LeftInset;
    CFMutableAttributedStringRef m_AttrString;
    std::vector<TextLine>        m_Lines;
    unsigned                     m_VerticalOffset; // offset in lines number within text lines
    unsigned                     m_HorizontalOffset; // offset in characters from the left window edge
    
    int                          m_FrameLines; // amount of lines in our frame size ( +1 to fit cutted line also)
    
    CGSize                       m_FrameSize;
    bool                         m_SmoothScroll; // turned on when we can view all file in file window without movements
    CGPoint                      m_SmoothOffset;
}

- (id) InitWithData:(BigFileViewDataBackend*) _data
             parent:(BigFileView*) _view;
{
    m_View = _view;
    m_Data = _data;
    m_FrameSize = CGSizeMake(0, 0);
    m_LeftInset = 5;
    m_HorizontalOffset = 0;
    m_SmoothScroll = _data->IsFullCoverage();

    if(!_data->IsFullCoverage())
        m_FixupWindow = (UniChar*) malloc(sizeof(UniChar) * m_Data->RawSize()); // unichar for every byte in raw window - should be ok in all cases
    else
        m_FixupWindow = (UniChar*) malloc(sizeof(UniChar) * m_Data->UniCharsSize());
    
    [self GrabFontGeometry];
    [self OnFrameChanged];
    [self OnBufferDecoded];
    
    [m_View setNeedsDisplay:true];
    return self;
}

- (void) dealloc
{
    [self ClearLayout];
    if(m_StringBuffer)
        CFRelease(m_StringBuffer);    
    free(m_FixupWindow);
}

- (void) GrabFontGeometry
{
    m_FontHeight = GetLineHeightForFont([m_View TextFont], &m_FontAscent, &m_FontDescent, &m_FontLeading);
    m_FontWidth  = GetMonospaceFontCharWidth([m_View TextFont]);
}

- (void) OnBufferDecoded
{
    if(m_StringBuffer)
        CFRelease(m_StringBuffer);
    
    memcpy(m_FixupWindow, m_Data->UniChars(), sizeof(UniChar) * m_Data->UniCharsSize());
    CleanUnicodeControlSymbols(m_FixupWindow, m_Data->UniCharsSize());

    m_StringBuffer = CFStringCreateWithCharactersNoCopy(0, m_FixupWindow, m_Data->UniCharsSize(), kCFAllocatorNull);
    m_StringBufferSize = CFStringGetLength(m_StringBuffer);

    [self BuildLayout];
}

- (void) BuildLayout
{
    [self ClearLayout];
    if(!m_StringBuffer)
        return;
    
    double wrapping_width = 10000;
    if([m_View WordWrap])
        wrapping_width = [m_View frame].size.width - [NSScroller scrollerWidth] - m_LeftInset;

    m_AttrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    CFAttributedStringReplaceString(m_AttrString, CFRangeMake(0, 0), m_StringBuffer);
    CFAttributedStringSetAttribute(m_AttrString, CFRangeMake(0, m_StringBufferSize), kCTForegroundColorAttributeName, [m_View TextForegroundColor]);
    CFAttributedStringSetAttribute(m_AttrString, CFRangeMake(0, m_StringBufferSize), kCTFontAttributeName, [m_View TextFont]);

    
    // Create a typesetter using the attributed string.
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(m_AttrString);
    
    CFIndex start = 0;
    while(start < m_StringBufferSize)
    {
        // 1st - manual hack for breaking lines by space characters
        CFIndex count = 0;
        unsigned spaces = ShouldBreakLineBySpaces(m_StringBuffer, (unsigned)start, m_FontWidth, wrapping_width);
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
                                                                m_FontWidth,
                                                                wrapping_width);
            count -= tail_spaces_cut;
        }
        
        // Use the returned character count (to the break) to create the line.                
        TextLine l;
        l.unichar_no = (uint32_t)start;
        l.unichar_len = (uint32_t)count;
        l.byte_no = m_Data->UniCharToByteIndeces()[start];
        l.bytes_len = m_Data->UniCharToByteIndeces()[start + count - 1] - l.byte_no;
        m_Lines.push_back(l);
        
        start += count;
    }

    // build our CTLines in multiple threads since it can be time-consuming
    dispatch_apply(m_Lines.size(), dispatch_get_global_queue(0, 0), ^(size_t n) {
        m_Lines[n].line = CTTypesetterCreateLine(typesetter, CFRangeMake(m_Lines[n].unichar_no, m_Lines[n].unichar_len));        
    });
    
    CFRelease(typesetter);
    
    if(m_VerticalOffset >= m_Lines.size())
        m_VerticalOffset = !m_Lines.empty() ? (unsigned)m_Lines.size()-1 : 0;
    
    [m_View setNeedsDisplay:true];
}

- (void) ClearLayout
{
    if(m_AttrString)
    {
        CFRelease(m_AttrString);
        m_AttrString = 0;
    }
    
    for(auto &i: m_Lines)
        CFRelease(i.line);
    
    m_Lines.clear();
}

- (CGPoint) TextAnchor
{
     NSRect v = [m_View visibleRect];
    CGPoint textPosition;
    textPosition.x = ceil((m_LeftInset - m_HorizontalOffset * m_FontWidth)) - m_SmoothOffset.x;
    textPosition.y = floor(v.size.height - m_FontHeight + m_FontDescent) + m_SmoothOffset.y;
    return textPosition;
}

- (int) CharIndexFromPoint: (CGPoint) _point
{
    CGPoint left_upper = [self TextAnchor];
    
    int y_off = ceil((left_upper.y - _point.y) / m_FontHeight);
    int line_no = y_off + m_VerticalOffset;
    if(line_no < 0)
        return -1;
    if(line_no >= m_Lines.size())
        return (int)m_StringBufferSize + 1;
    
    const auto &line = m_Lines[line_no];

    int ind = (int)CTLineGetStringIndexForPosition(line.line, CGPointMake(_point.x - left_upper.x, 0));
    if(ind == kCFNotFound)
        return -1;

    if(ind >= line.unichar_no + line.unichar_len) // TODO: check if this is right
        ind = line.unichar_no + line.unichar_len - 1;
    
    return ind;
}

- (void) DoDraw:(CGContextRef) _context dirty:(NSRect)_dirty_rect
{
    [m_View BackgroundFillColor].Set(_context);
    CGContextFillRect(_context, NSRectToCGRect(_dirty_rect));
    CGContextSetTextMatrix(_context, CGAffineTransformIdentity);
    CGContextSetTextDrawingMode(_context, kCGTextFill);
    CGContextSetShouldSmoothFonts(_context, [m_View ShouldSmoothFonts]);
    CGContextSetShouldAntialias(_context, [m_View ShouldAntialias]);
    
    if(!m_StringBuffer) return;
    
    CGPoint textPosition = [self TextAnchor];
    
    CGFloat view_width = [m_View visibleRect].size.width;
    
    size_t first_string = m_VerticalOffset;
    if(m_SmoothOffset.y < 0 && first_string > 0)
    {
        --first_string; // to be sure that we can see bottom-clipped lines
        textPosition.y += m_FontHeight;        
    }
    
    CFRange selection = [m_View SelectionWithinWindowUnichars];
    
     for(size_t i = first_string; i < m_Lines.size(); ++i)
     {
         CTLineRef line = m_Lines[i].line;
         
         if(selection.location >= 0) // draw a selection background here
         {
             CGFloat x1 = 0, x2 = -1;
             if(m_Lines[i].unichar_no <= selection.location &&
                m_Lines[i].unichar_no + m_Lines[i].unichar_len > selection.location)
             {
                 x1 = textPosition.x + CTLineGetOffsetForStringIndex(line, selection.location, 0);
                 x2 = ((selection.location + selection.length <= m_Lines[i].unichar_no + m_Lines[i].unichar_len) ?
                 textPosition.x + CTLineGetOffsetForStringIndex(line,
                                                    (selection.location + selection.length <= m_Lines[i].unichar_no + m_Lines[i].unichar_len) ?
                                                    selection.location + selection.length : m_Lines[i].unichar_no + m_Lines[i].unichar_len,
                                               0) : view_width);
             }
             else if(selection.location + selection.length > m_Lines[i].unichar_no &&
                     selection.location + selection.length <= m_Lines[i].unichar_no + m_Lines[i].unichar_len )
             {
                 x1 = textPosition.x;
                 x2 = textPosition.x + CTLineGetOffsetForStringIndex(line, selection.location + selection.length, 0);
             }
             else if(selection.location < m_Lines[i].unichar_no &&
                     selection.location + selection.length > m_Lines[i].unichar_no + m_Lines[i].unichar_len)
             {
                 x1 = textPosition.x;
                 x2 = view_width;
             }

             if(x2 > x1)
             {
                 CGContextSaveGState(_context);
                 CGContextSetShouldAntialias(_context, false);
                 [m_View SelectionBkFillColor].Set(_context);
                 CGContextFillRect(_context, CGRectMake(x1, textPosition.y - m_FontDescent, x2 - x1, m_FontHeight));
                 CGContextRestoreGState(_context);
             }
         }
         
         CGContextSetTextPosition(_context, textPosition.x, textPosition.y);
         CTLineDraw(line, _context);
         
         textPosition.y -= m_FontHeight;
         if(textPosition.y < 0 - m_FontHeight)
             break;
     }

    [self UpdateVerticalScrollBar];
}

- (void) UpdateVerticalScrollBar
{
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
            [m_View UpdateVerticalScroll:double(byte_pos) / double(byte_scroll_size)
                                    prop:prop];
        }
    }
    else
    {
        double pos = 0.;
        if(m_Lines.size() > m_FrameLines)
            pos = double(m_VerticalOffset) / double(m_Lines.size() - m_FrameLines);
        double prop = 1.;
        if(m_Lines.size() > m_FrameLines)
            prop = double(m_FrameLines) / double(m_Lines.size());
        [m_View UpdateVerticalScroll:pos prop:prop];
    }
}

- (void) OnUpArrow
{
    if(m_Lines.empty()) return;
    assert(m_VerticalOffset < m_Lines.size());
    
    // check if we still can be within current file window position
    if( m_VerticalOffset > 1)
    {
        // ok, just scroll within current window
        m_VerticalOffset--;
        [m_View setNeedsDisplay:true];
    }
    else
    {
        // nope, we need to move file window if it is possible
        uint64_t window_pos = m_Data->FilePos();
        uint64_t window_size = m_Data->RawSize();
        if(window_pos > 0)
        {
            size_t anchor_index = m_VerticalOffset + 1;
            if(anchor_index >= m_Lines.size()) anchor_index = m_Lines.size() - 1;
            
            uint64_t anchor_glob_offset = m_Lines[anchor_index].byte_no + window_pos;
            
            uint64_t desired_window_offset = anchor_glob_offset;
            if( desired_window_offset > 3*window_size/4 )// TODO: need something more intelligent here
                desired_window_offset -= 3*window_size/4;
            else
                desired_window_offset = 0;
            
            [self MoveFileWindowTo:desired_window_offset
                        WithAnchor:anchor_glob_offset
                          AtLineNo:1];
        }
        else
        {
            if(m_VerticalOffset > 0)
            {
                m_VerticalOffset--;
                [m_View setNeedsDisplay:true];
            }
        }
    }
}

- (void) OnDownArrow
{
    if(m_Lines.empty()) return;
    assert(m_VerticalOffset < m_Lines.size());
    
    // check if we still can be within current file window position
    if( m_VerticalOffset + m_FrameLines < m_Lines.size() )
    {
        // ok, just scroll within current window
        m_VerticalOffset ++;
        [m_View setNeedsDisplay:true];
    }
    else
    {
        // nope, we need to move file window if it is possible
        uint64_t window_pos = m_Data->FilePos();
        uint64_t window_size = m_Data->RawSize();
        uint64_t file_size = m_Data->FileSize();
        if(window_pos + window_size < file_size)
        {
            // remember last line offset so we can find it in a new window and layout breakdown
            uint64_t anchor_glob_offset = m_Lines[m_VerticalOffset].byte_no + window_pos;
            
            uint64_t desired_window_offset = anchor_glob_offset;
//            assert(desired_window_offset > window_size/4);
            if(desired_window_offset >= window_size/4)
                desired_window_offset -= window_size/4; // TODO: need something more intelligent here
            
            if(desired_window_offset + window_size > file_size) // we'll reach a file's end
                desired_window_offset = file_size - window_size;
            
            [self MoveFileWindowTo:desired_window_offset
                        WithAnchor:anchor_glob_offset
                          AtLineNo:-1];
        }
    }
}

- (void) OnPageDown
{
    if(m_Lines.empty()) return;
    assert(m_VerticalOffset < m_Lines.size());
    
    // check if we can just move our visual offset
    if( m_VerticalOffset + m_FrameLines*2 < m_Lines.size())
    {
        // ok, just move our offset
        m_VerticalOffset += m_FrameLines;
        [m_View setNeedsDisplay:true];
    }
    else
    {
        // nope, we need to move file window if it is possible
        uint64_t window_pos = m_Data->FilePos();
        uint64_t window_size = m_Data->RawSize();
        uint64_t file_size = m_Data->FileSize();
        if(window_pos + window_size < file_size)
        {
            size_t anchor_index = m_VerticalOffset + m_FrameLines - 1;
            if(anchor_index >= m_Lines.size()) anchor_index = m_Lines.size() - 1;
            
            uint64_t anchor_glob_offset = m_Lines[anchor_index].byte_no + window_pos;
            
            uint64_t desired_window_offset = anchor_glob_offset;
            assert(desired_window_offset > window_size/4); // internal logic check
            desired_window_offset -= window_size/4; // TODO: need something more intelligent here
            
            if(desired_window_offset + window_size > file_size) // we'll reach a file's end
                desired_window_offset = file_size - window_size;
            
            [self MoveFileWindowTo:desired_window_offset
                        WithAnchor:anchor_glob_offset
                          AtLineNo:-1];
        }
        else
        {
            // just move offset to the end within our window
            if(m_VerticalOffset + m_FrameLines < m_Lines.size())
            {
                m_VerticalOffset = (unsigned)m_Lines.size() - m_FrameLines;
                [m_View setNeedsDisplay:true];
            }
        }
    }
}

- (void) OnPageUp
{
    if(m_Lines.empty()) return;
    assert(m_VerticalOffset < m_Lines.size());
    
    // check if we can just move our visual offset
    if( m_VerticalOffset > m_FrameLines + 1)
    {
        // ok, just move our offset
        m_VerticalOffset -= m_FrameLines;
        [m_View setNeedsDisplay:true];
    }
    else
    {
        // nope, we need to move file window if it is possible
        uint64_t window_pos = m_Data->FilePos();
        uint64_t window_size = m_Data->RawSize();
        if(window_pos > 0)
        {
            size_t anchor_index = m_VerticalOffset;
            
            uint64_t anchor_glob_offset = m_Lines[anchor_index].byte_no + window_pos;
            
            uint64_t desired_window_offset = anchor_glob_offset;
            if( desired_window_offset > 3*window_size/4 ) // TODO: need something more intelligent here
                desired_window_offset -= 3*window_size/4;
            else
                desired_window_offset = 0;
            
            [self MoveFileWindowTo:desired_window_offset
                        WithAnchor:anchor_glob_offset
                          AtLineNo:int(m_FrameLines)];
        }
        else
        {
            if(m_VerticalOffset > 0)
            {
                m_VerticalOffset=0;
                [m_View setNeedsDisplay:true];
            }
        }
    }
}

- (void) MoveFileWindowTo:(uint64_t)_pos WithAnchor:(uint64_t)_byte_no AtLineNo:(int)_line
{
    // now move our file window
    [m_View RequestWindowMovementAt:_pos];
    
    // update data and layout stuff
//    [self BuildLayout];   <<-- this will be called implicitly
    
    // now we need to find a line which is at last_top_line_glob_offset position
    bool found = false;
    size_t closest_ind = 0;
    uint64_t closest_dist = 1000000;
    uint64_t window_pos = m_Data->FilePos();
    for(size_t i = 0; i < m_Lines.size(); ++i)
    {
        uint64_t pos = (uint64_t)m_Lines[i].byte_no + window_pos;
        if( pos == _byte_no)
        {
            found = true;
            if((int)i - _line >= 0)
                m_VerticalOffset = (int)i - _line;
            else
                m_VerticalOffset = 0; // edge case - we can't satisfy request, since whole file window is less than one page(?)
            if(m_VerticalOffset >= m_Lines.size())
            {
                m_VerticalOffset = (unsigned)m_Lines.size()-1; // TODO: write more intelligent adjustment
            }
            
            break;
        }
        else
        {
            if(pos > _byte_no)
                break; // ?
            
            uint64_t d = pos < _byte_no ? _byte_no - pos : pos - _byte_no;
            if(d < closest_dist)
            {
                closest_dist = d;
                closest_ind = i;
            }
        }
    }
    
    if(!found) // choose closest line as a new anchor
    {
        if((int)closest_ind - _line >= 0)
            m_VerticalOffset = (int)closest_ind - _line;
        else
            m_VerticalOffset = 0; // edge case - we can't satisfy request, since whole file window is less than one page(?)
    }
    
    assert(m_VerticalOffset < m_Lines.size());
    [m_View setNeedsDisplay:true];
}

- (uint32_t) GetOffsetWithinWindow
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

- (void) MoveOffsetWithinWindow: (uint32_t)_offset
{
    uint32_t min_dist = 1000000;
    size_t closest = 0;
    for(size_t i = 0; i < m_Lines.size(); ++i)
    {
        if(m_Lines[i].byte_no == _offset)
        {
            closest = i;
            break;
        }
        else
        {
            uint32_t dist = m_Lines[i].byte_no > _offset ? m_Lines[i].byte_no - _offset : _offset - m_Lines[i].byte_no;
            if(dist < min_dist)
            {
                min_dist = dist;
                closest = i;
            }
        }
    }
    
    m_VerticalOffset = (unsigned)closest;
    assert(m_Lines.empty() ||
           m_VerticalOffset < m_Lines.size());
}

- (void) ScrollToByteOffset: (uint64_t)_offset
{
    uint64_t window_pos = m_Data->FilePos();
    uint64_t window_size = m_Data->RawSize();
    uint64_t file_size = m_Data->FileSize();
    
    if(_offset >= window_pos && _offset < window_pos + window_size)
    {
        uint32_t offset_in_wnd = uint32_t(_offset - window_pos);
        
        uint32_t min_dist = 1000000;
        size_t closest = 0;
        for(size_t i = 0; i < m_Lines.size(); ++i)
        {
            if(m_Lines[i].byte_no == offset_in_wnd)
            {
                closest = i;
                break;
            }
            else
            {
                if(m_Lines[i].byte_no > offset_in_wnd)
                    break; // ?
                
                uint32_t dist = m_Lines[i].byte_no > offset_in_wnd ?
                m_Lines[i].byte_no - offset_in_wnd :
                offset_in_wnd - m_Lines[i].byte_no;
                if(dist < min_dist)
                {
                    min_dist = dist;
                    closest = i;
                }
            }
        }
        
        if((unsigned)closest + m_FrameLines < m_Lines.size())
        { // check that we will fill whole screen after scrolling
            m_VerticalOffset = (unsigned)closest;
            [m_View setNeedsDisplay:true];
            return;
        }
    }
    
    uint64_t desired_wnd_pos = 0;
    if(_offset > window_size / 2)
        desired_wnd_pos = _offset - window_size / 2;
    else
        desired_wnd_pos = 0;
    
    if(desired_wnd_pos + window_size >= file_size)
        desired_wnd_pos = file_size - window_size;
    
    [self MoveFileWindowTo:desired_wnd_pos WithAnchor:_offset AtLineNo:0];
    assert(m_Lines.empty() || m_VerticalOffset < m_Lines.size());
}

- (void) HandleVerticalScroll: (double) _pos
{
    if(!m_SmoothScroll)
    { // scrolling by bytes offset
        uint64_t file_size = m_Data->FileSize();
        uint64_t bytepos = uint64_t( _pos * double(file_size) ); // need to substract current screen's size in bytes
        [self ScrollToByteOffset: bytepos];
        
        if(m_Lines.size() - m_VerticalOffset < m_FrameLines )
            m_VerticalOffset = (int)m_Lines.size() - m_FrameLines;

        m_SmoothOffset.y = 0;
    }
    else
    { // we have all file decomposed into strings, so we can do smooth scrolling now
        double full_document_size = double(m_Lines.size()) * m_FontHeight;
        double scroll_y_offset = _pos * (full_document_size - m_FrameSize.height);
        m_VerticalOffset = floor(scroll_y_offset / m_FontHeight);
        m_SmoothOffset.y = scroll_y_offset - m_VerticalOffset * m_FontHeight;
        [m_View setNeedsDisplay:true];
    }
    assert(m_Lines.empty() || m_VerticalOffset < m_Lines.size());
}

- (void) OnScrollWheel:(NSEvent *)theEvent
{
    double delta_y = [theEvent scrollingDeltaY];
    double delta_x = [theEvent scrollingDeltaX];
    if(![theEvent hasPreciseScrollingDeltas])
    {
        delta_y *= m_FontHeight;
        delta_x *= m_FontWidth;
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
        
            while(m_SmoothOffset.y < -m_FontHeight) {
                [self OnUpArrow];
                m_SmoothOffset.y += m_FontHeight;
            }
            while(m_SmoothOffset.y > m_FontHeight) {
                [self OnDownArrow];
                m_SmoothOffset.y -= m_FontHeight;
            }
        }
    }
    else
    {
        if((delta_y > 0 && m_VerticalOffset > 0) ||
           (delta_y < 0 && m_VerticalOffset + m_FrameLines < m_Lines.size()) )
        {
            m_SmoothOffset.y -= delta_y;
            if(m_SmoothOffset.y < -m_FontHeight)
            {
                int dl = int(-m_SmoothOffset.y / m_FontHeight);
                if(m_VerticalOffset > dl) m_VerticalOffset -= dl;
                else m_VerticalOffset = 0;
                m_SmoothOffset.y += dl * m_FontHeight;
            }
            else if(m_SmoothOffset.y > m_FontHeight)
            {
                int dl = int(m_SmoothOffset.y / m_FontHeight);
                if(m_VerticalOffset + m_FrameLines + dl < m_Lines.size()) m_VerticalOffset += dl;
                else m_VerticalOffset = (int)m_Lines.size() - m_FrameLines;
                m_SmoothOffset.y -= dl * m_FontHeight;
            }
        }
    }
    
    // horizontal scrolling
    if( ![m_View WordWrap] && ((delta_x > 0 && m_HorizontalOffset > 0) || delta_x < 0) )
    {
        m_SmoothOffset.x -= delta_x;
        if(m_SmoothOffset.x > m_FontWidth)
        {
            int dx = int(m_SmoothOffset.x / m_FontWidth);
            m_HorizontalOffset += dx;
            m_SmoothOffset.x -= dx * m_FontWidth;
            
        }
        else if(m_SmoothOffset.x < -m_FontWidth)
        {
            int dx = int(-m_SmoothOffset.x / m_FontWidth);
            if(m_HorizontalOffset > dx) m_HorizontalOffset -= dx;
            else m_HorizontalOffset = 0;
            m_SmoothOffset.x += dx * m_FontWidth;
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
    
    [m_View setNeedsDisplay:true];
    assert(m_Lines.empty() || m_VerticalOffset < m_Lines.size());
}

- (void) OnFrameChanged
{
    NSRect fr = [m_View frame];
    m_FrameLines = fr.size.height / m_FontHeight;

    if(m_FrameSize.width != fr.size.width)
        [self BuildLayout];
    m_FrameSize = fr.size;
}

- (void) OnWordWrappingChanged
{
    [self BuildLayout];
    if(m_VerticalOffset >= m_Lines.size())
    {
        if(m_Lines.size() >= m_FrameLines)
            m_VerticalOffset = (int)m_Lines.size() - m_FrameLines;
        else
            m_VerticalOffset = 0;
    }
    m_HorizontalOffset = 0;
    m_SmoothOffset.x = 0;
}

- (void) OnFontSettingsChanged
{
    [self GrabFontGeometry];
    [self OnFrameChanged];
    [self BuildLayout];
}

- (void) OnLeftArrow
{
    if(![m_View WordWrap] && m_HorizontalOffset > 0)
    {
        m_HorizontalOffset--;
        [m_View setNeedsDisplay:true];
    }
}

- (void) OnRightArrow
{
    if(![m_View WordWrap])
    {
        m_HorizontalOffset++;
        [m_View setNeedsDisplay:true];
    }
}

- (void) OnMouseDown:(NSEvent *)event
{
    if([event clickCount] > 2)
        [self HandleSelectionWithTripleClick:event];
    else if ([event clickCount] == 2)
        [self HandleSelectionWithDoubleClick:event];
    else
        [self HandleSelectionWithMouseDragging:event];
}

- (void) HandleSelectionWithTripleClick: (NSEvent*) event
{
    NSPoint pt = [m_View convertPoint:[event locationInWindow] fromView:nil];
    int uc_index = CropIndex([self CharIndexFromPoint:pt], (int)m_StringBufferSize);

    for(const auto &i: m_Lines)
        if(i.unichar_no <= uc_index && i.unichar_no + i.unichar_len > uc_index)
        {
            int sel_start = i.unichar_no;
            int sel_end = i.unichar_no + i.unichar_len;
            int sel_start_byte = m_Data->UniCharToByteIndeces()[sel_start];
            int sel_end_byte = sel_end < m_StringBufferSize ? m_Data->UniCharToByteIndeces()[sel_end] : (int)m_Data->RawSize();
            [m_View SetSelectionInFile:CFRangeMake(sel_start_byte + m_Data->FilePos(), sel_end_byte - sel_start_byte)];
            break;
        }
}

- (void) HandleSelectionWithDoubleClick: (NSEvent*) event
{
    NSPoint pt = [m_View convertPoint:[event locationInWindow] fromView:nil];
    int uc_index = CropIndex([self CharIndexFromPoint:pt], (int)m_StringBufferSize);

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
                                else if(wordRange.location > uc_index)
                                    *stop = YES;
                            }];
    
    if(sel_start == sel_end) // select single character
    {
        sel_start = uc_index;
        sel_end   = uc_index + 1;        
    }

    int sel_start_byte = m_Data->UniCharToByteIndeces()[sel_start];
    int sel_end_byte = sel_end < m_StringBufferSize ? m_Data->UniCharToByteIndeces()[sel_end] : (int)m_Data->RawSize();
    [m_View SetSelectionInFile:CFRangeMake(sel_start_byte + m_Data->FilePos(), sel_end_byte - sel_start_byte)];
}

- (void) HandleSelectionWithMouseDragging: (NSEvent*) event
{
    bool modifying_existing_selection = ([event modifierFlags] & NSShiftKeyMask) ? true : false;
    
    NSPoint first_down = [m_View convertPoint:[event locationInWindow] fromView:nil];
    int first_ind = CropIndex([self CharIndexFromPoint:first_down], (int)m_StringBufferSize);
    
    CFRange orig_sel = [m_View SelectionWithinWindowUnichars];
    
    while ([event type]!=NSLeftMouseUp)
    {
        NSPoint curr_loc = [m_View convertPoint:[event locationInWindow] fromView:nil];
        int curr_ind = CropIndex([self CharIndexFromPoint:curr_loc], (int)m_StringBufferSize);
        
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
            int sel_end_byte = sel_end < m_StringBufferSize ? m_Data->UniCharToByteIndeces()[sel_end] : (int)m_Data->RawSize();
            assert(sel_end_byte >= sel_start_byte);
            [m_View SetSelectionInFile:CFRangeMake(sel_start_byte + m_Data->FilePos(), sel_end_byte - sel_start_byte)];
        }
        else
            [m_View SetSelectionInFile:CFRangeMake(-1,0)];
        
        event = [[m_View window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
    }
}

@end
