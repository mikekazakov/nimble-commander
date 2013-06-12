//
//  BigFileViewText.m
//  ViewerBase
//
//  Created by Michael G. Kazakov on 09.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <vector>
#import "BigFileViewText.h"
#import "BigFileView.h"
#import "Common.h"

static const size_t g_FixupWindowSize = 128*1024;

static CGFloat GetLineHeightForFont(CTFontRef iFont)
{
    CGFloat lineHeight = 0.0;
    
    assert(iFont != NULL);
    
    // Get the ascent from the font, already scaled for the font's size
    lineHeight += CTFontGetAscent(iFont);
    
    // Get the descent from the font, already scaled for the font's size
    lineHeight += CTFontGetDescent(iFont);
    
    // Get the leading from the font, already scaled for the font's size
    lineHeight += CTFontGetLeading(iFont);
    
    return lineHeight;
}

static double GetMonospaceFontCharWidth(CTFontRef _font)
{
    CFStringRef string = CFSTR("A");
    CFMutableAttributedStringRef attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    CFAttributedStringReplaceString(attrString, CFRangeMake(0, 0), string);
    CFAttributedStringSetAttribute(attrString, CFRangeMake(0, CFStringGetLength(string)), kCTFontAttributeName, _font);
    CTLineRef line = CTLineCreateWithAttributedString(attrString);
    double width = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
    CFRelease(line);
    CFRelease(attrString);
    return width;
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
    const auto len = CFStringGetLength(_string);    
    
    for(unsigned i = _start + _count - 1; i >= _start; --i)
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
    assert(line_width < _line_width);
    
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
    }
}

struct TextLine
{
    uint32_t    unichar_no;
    uint32_t    unichar_len;
    uint32_t    byte_no;         // offset within file window of a current text line
    uint32_t    bytes_len;
    CTLineRef   line;
};

@implementation BigFileViewText
{
    // basic stuff
    BigFileView    *m_View;
    const UniChar  *m_Window;
    const uint32_t *m_Indeces;
    size_t          m_WindowSize;

    UniChar        *m_FixupWindow;
    
    // data stuff
    CFStringRef     m_StringBuffer;
    size_t          m_StringBufferSize; // should be equal to m_DecodedBufferSize
        
    // layout stuff
    CGFloat                      m_FontHeight;
    CGFloat                      m_FontWidth;
    CGFloat                      m_LeftInset;
    CFMutableAttributedStringRef m_AttrString;
    std::vector<TextLine>        m_Lines;
    unsigned                     m_VerticalOffset; // offset in lines number within text lines

    int                          m_FrameLines; // amount of lines in our frame size ( +1 to fit cutted line also)
    
    int                          m_FramePxWidth;
}

- (id) InitWithWindow:(const UniChar*) _unichar_window
                offsets:(const uint32_t*) _unichar_indeces
                   size:(size_t) _unichars_amount // unichars, not bytes (x2)
                 parent:(BigFileView*) _view
{
    m_View = _view;
    m_Window = _unichar_window;
    m_Indeces = _unichar_indeces;
    m_WindowSize = _unichars_amount;
    m_FramePxWidth = 0;
    m_LeftInset = 5;
    
    m_FontHeight = GetLineHeightForFont([m_View TextFont]);
    m_FontWidth  = GetMonospaceFontCharWidth([m_View TextFont]);
    m_FixupWindow = (UniChar*) malloc(sizeof(UniChar) * g_FixupWindowSize);
    
    [self OnFrameChanged];

    [self OnBufferDecoded:m_WindowSize];
    
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

- (void) OnBufferDecoded: (size_t) _new_size // unichars, not bytes (x2)
{
    assert(_new_size <= g_FixupWindowSize);
    m_WindowSize = _new_size;
    
    if(m_StringBuffer)
        CFRelease(m_StringBuffer);
    
    memcpy(m_FixupWindow, m_Window, sizeof(UniChar) * m_WindowSize);
    CleanUnicodeControlSymbols(m_FixupWindow, m_WindowSize);

    m_StringBuffer = CFStringCreateWithCharactersNoCopy(0, m_FixupWindow, m_WindowSize, kCFAllocatorNull);
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
//    MachTimeBenchmark m;
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(m_AttrString);
//    m.Reset("CTTypesetterCreateWithAttributedString");
    
    CFIndex start = 0;
    while(start < m_StringBufferSize)
    {
        // 1st - manual hack for breaking lines by space characters
//static unsigned ShouldBreakLineBySpaces(CFStringRef _string, unsigned _start, double _font_width, double _line_width)
        CFIndex count;
        
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
        CTLineRef line = CTTypesetterCreateLine(typesetter, CFRangeMake(start, count));
        
        TextLine l;
        l.line = line;
        l.unichar_no = (uint32_t)start;
        l.unichar_len = (uint32_t)count;
        l.byte_no = m_Indeces[start];
        l.bytes_len = m_Indeces[start + count - 1] - l.byte_no;
        m_Lines.push_back(l);
        
        start += count;
    }
    CFRelease(typesetter);
    
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

- (void) DoDraw:(CGContextRef) _context dirty:(NSRect)_dirty_rect
{
    CGContextSetRGBFillColor(_context,
                             [m_View BackgroundFillColor].r,
                             [m_View BackgroundFillColor].g,
                             [m_View BackgroundFillColor].b,
                             [m_View BackgroundFillColor].a);
    CGContextFillRect(_context, NSRectToCGRect(_dirty_rect));
    CGContextSetTextMatrix(_context, CGAffineTransformIdentity);
    CGContextSetTextDrawingMode(_context, kCGTextFill);
    CGContextSetShouldSmoothFonts(_context, false);
    CGContextSetShouldAntialias(_context, true);
    
     NSRect v = [m_View visibleRect];
     
    if(!m_StringBuffer) return;
     
    CGPoint textPosition;
    textPosition.x = m_LeftInset;
    textPosition.y = v.size.height - m_FontHeight;
     
    size_t first_string = m_VerticalOffset;
    uint32_t last_drawn_byte_pos = 0;
    
     for(size_t i = first_string; i < m_Lines.size(); ++i)
     {
         CTLineRef line = m_Lines[i].line;
         CGContextSetTextPosition(_context, textPosition.x, textPosition.y);
         CTLineDraw(line, _context);

         last_drawn_byte_pos = m_Lines[i].byte_no + m_Lines[i].bytes_len;
         
         textPosition.y -= m_FontHeight;
         if(textPosition.y < 0 - m_FontHeight)
             break;
     }

    if(first_string < m_Lines.size())
    {
        uint64_t byte_pos = m_Lines[first_string].byte_no + [m_View RawWindowPosition];
        uint64_t byte_scroll_size = [m_View FullSize] - (last_drawn_byte_pos - m_Lines[first_string].byte_no);
        double prop = double(last_drawn_byte_pos - m_Lines[first_string].byte_no) / double([m_View FullSize]);
        [m_View UpdateVerticalScroll:double(byte_pos) / double(byte_scroll_size)
                                prop:prop];
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
        uint64_t window_pos = [m_View RawWindowPosition];
        uint64_t window_size = [m_View RawWindowSize];
        if(window_pos > 0)
        {
            size_t anchor_index = m_VerticalOffset + m_FrameLines - 1;
            if(anchor_index >= m_Lines.size()) anchor_index = m_Lines.size() - 1;
            
            uint64_t anchor_glob_offset = m_Lines[anchor_index].byte_no + window_pos;
            
            uint64_t desired_window_offset = anchor_glob_offset;
            if( desired_window_offset > 3*window_size/4 )// TODO: need something more intelligent here
                desired_window_offset -= 3*window_size/4;
            else
                desired_window_offset = 0;
            
            [self MoveFileWindowTo:desired_window_offset
                        WithAnchor:anchor_glob_offset
                          AtLineNo:int(anchor_index+1)];
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
        uint64_t window_pos = [m_View RawWindowPosition];
        uint64_t window_size = [m_View RawWindowSize];
        uint64_t file_size = [m_View FullSize];
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
        uint64_t window_pos = [m_View RawWindowPosition];
        uint64_t window_size = [m_View RawWindowSize];
        uint64_t file_size = [m_View FullSize];
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
        uint64_t window_pos = [m_View RawWindowPosition];
        uint64_t window_size = [m_View RawWindowSize];
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
    uint64_t window_pos = [m_View RawWindowPosition];
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
            min_dist = 0;
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
}

- (void) HandleVerticalScroll: (double) _pos
{
    // TODO: this is a very first implementation, contains many issues

    uint64_t window_pos = [m_View RawWindowPosition];
    uint64_t window_size = [m_View RawWindowSize];
    uint64_t file_size = [m_View FullSize];

    uint64_t bytepos = uint64_t( _pos * double(file_size) ); // need to substract current screen's size in bytes
    
    if(bytepos >= window_pos && bytepos < window_pos + window_size)
    {
        uint32_t offset_in_wnd = uint32_t(bytepos - window_pos);
        
        uint32_t min_dist = 1000000;
        size_t closest = 0;
        for(size_t i = 0; i < m_Lines.size(); ++i)
        {
            if(m_Lines[i].byte_no == offset_in_wnd)
            {
                min_dist = 0;
                closest = i;
                break;
            }
            else
            {
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
    if(bytepos > window_size / 2)
        desired_wnd_pos = bytepos - window_size / 2;
    else
        desired_wnd_pos = 0;

    if(desired_wnd_pos + window_size >= file_size)
        desired_wnd_pos = file_size - window_size;

    [self MoveFileWindowTo:desired_wnd_pos WithAnchor:bytepos AtLineNo:0];
}

- (void) OnFrameChanged
{
    NSRect fr = [m_View frame];
    m_FrameLines = fr.size.height / m_FontHeight;
    if( m_FramePxWidth != (int)fr.size.width)
    {
        [self BuildLayout];
        m_FramePxWidth = (int)fr.size.width;
    }
}

- (void) OnWordWrappingChanged: (bool) _wrap_words
{
    [self BuildLayout];
    if(m_VerticalOffset >= m_Lines.size())
    {
        if(m_Lines.size() >= m_FrameLines)
            m_VerticalOffset = (int)m_Lines.size() - m_FrameLines;
        else
            m_VerticalOffset = 0;
    }
}

@end
