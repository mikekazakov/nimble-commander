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

static void CleanUnicodeControlSymbols(UniChar *_s, size_t _n)
{
    for(size_t i = 0; i < _n; ++i)
    {
        UniChar c = _s[i];
        if(
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
    uint32_t   unichar_no;
    uint32_t   unichar_len;
    uint32_t   byte_no;
    CTLineRef  line;
};

@implementation BigFileViewText
{
    // basic stuff
    BigFileView    *m_View;
    const UniChar  *m_Window;
    const uint32_t *m_Indeces;
    size_t          m_WindowSize;

    // data stuff
    CFStringRef     m_StringBuffer;
    size_t          m_StringBufferSize; // should be equal to m_DecodedBufferSize
        
    // layout stuff
    CGFloat                      m_FontHeight;
    CFMutableAttributedStringRef m_AttrString;
    std::vector<TextLine>        m_Lines;
    unsigned                     m_VerticalOffset; // offset in lines number within text lines

    int                          m_FrameLines; // amount of lines in our frame size ( +1 to fit cutted line also)
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
    
    m_FontHeight = GetLineHeightForFont([m_View TextFont]);
    NSRect fr = [_view frame];
    m_FrameLines = fr.size.height / m_FontHeight;
    
    [self OnBufferDecoded:m_WindowSize];
    
    [m_View setNeedsDisplay:true];
    return self;
}

- (void) dealloc
{
    [self ClearLayout];
}

- (void) OnBufferDecoded: (size_t) _new_size // unichars, not bytes (x2)
{
    m_WindowSize = _new_size;
    
    if(m_StringBuffer)
        CFRelease(m_StringBuffer);
    
    UniChar *ss = (UniChar*) malloc(sizeof(UniChar) * m_WindowSize); // will leak; FIXME
    memcpy(ss, m_Window, sizeof(UniChar) * m_WindowSize);
    CleanUnicodeControlSymbols(ss, m_WindowSize);
    
    m_StringBuffer = CFStringCreateWithBytesNoCopy(0,
                                                   (UInt8*)/*m_Window*/ss,
                                                   m_WindowSize*sizeof(UniChar),
                                                   kCFStringEncodingUnicode,
                                                   false,
                                                   kCFAllocatorNull);
    m_StringBufferSize = CFStringGetLength(m_StringBuffer);

    [self BuildLayout];
}

- (void) BuildLayout
{
    [self ClearLayout];
    
    double wrapping_width = 10000;
    if(/*m_DoWrapLines*/ true)
        wrapping_width = [m_View frame].size.width;

    m_AttrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
    CFAttributedStringReplaceString(m_AttrString, CFRangeMake(0, 0), m_StringBuffer);
    CFAttributedStringSetAttribute(m_AttrString, CFRangeMake(0, m_StringBufferSize), kCTForegroundColorAttributeName, [m_View TextForegroundColor]);
    CFAttributedStringSetAttribute(m_AttrString, CFRangeMake(0, m_StringBufferSize), kCTFontAttributeName, [m_View TextFont]);
    
    // Create a typesetter using the attributed string.
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(m_AttrString);
    
    CFIndex start = 0;
    do
    {
        // this value will depend on "wrap words" flag
        CFIndex count = CTTypesetterSuggestLineBreak(typesetter, start, wrapping_width);
        if(count <= 0) break;
        
        // Use the returned character count (to the break) to create the line.
        CTLineRef line = CTTypesetterCreateLine(typesetter, CFRangeMake(start, count));
        
        TextLine l;
        l.line = line;
        l.unichar_no = (uint32_t)start;
        l.unichar_len = (uint32_t)count;
        l.byte_no = m_Indeces[start];
        m_Lines.push_back(l);
        
        start += count;
        
    } while(true);
    CFRelease(typesetter);
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
    CGContextSetRGBFillColor(_context, 1,1,1,1);
    CGContextFillRect(_context, NSRectToCGRect(_dirty_rect));
    CGContextSetTextMatrix(_context, CGAffineTransformIdentity);
     
     NSRect v = [m_View visibleRect];
     
     if(!m_StringBuffer) return;
     
     CGPoint textPosition;
     textPosition.x = 0;
     textPosition.y = v.size.height - m_FontHeight;
     
     size_t first_string = m_VerticalOffset;
     for(size_t i = first_string; i < m_Lines.size(); ++i)
     {
         CTLineRef line = m_Lines[i].line;
         CGContextSetTextPosition(_context, textPosition.x, textPosition.y);
         CTLineDraw(line, _context);
     
         textPosition.y -= m_FontHeight;
         if(textPosition.y < 0 - m_FontHeight)
             break;
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
            if( desired_window_offset > (window_size*8)/10 ) // TODO: need something more intelligent here
                desired_window_offset -= (window_size*8)/10;
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
            assert(desired_window_offset > (window_size*2)/10);
            desired_window_offset -= (window_size*2)/10; // TODO: need something more intelligent here
            
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
            assert(desired_window_offset > (window_size*2)/10); // internal logic check
            desired_window_offset -= (window_size*2)/10; // TODO: need something more intelligent here
            
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
            if( desired_window_offset > (window_size*8)/10 ) // TODO: need something more intelligent here
                desired_window_offset -= (window_size*8)/10;
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
    [self BuildLayout];
    
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

@end
