//
//  BigFileViewHex.m
//  ViewerBase
//
//  Created by Michael G. Kazakov on 09.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <vector>
#import <mach/mach_time.h>
#import "BigFileViewHex.h"
#import "BigFileView.h"
#import "Common.h"
#import "FontExtras.h"

static const unsigned g_BytesPerHexLine = 16;
static const unsigned g_HexColumns = 2;
static const unsigned g_RowOffsetSymbs = 10;

static int Hex_CharPosFromByteNo(int _byte)
{
    const int byte_per_col = g_BytesPerHexLine / g_HexColumns;
    assert(_byte <= g_BytesPerHexLine);
    
    if(_byte == g_BytesPerHexLine) // special case
        return (byte_per_col * 3 + 2) * g_HexColumns - 3;
    
    int col_num = _byte / byte_per_col;
    int byte_in_col = _byte % byte_per_col;
    
    int char_in_col = byte_in_col * 3;
    
    return char_in_col + (byte_per_col * 3 + 2) * col_num;
}

static int Hex_ByteFromCharPos(int _char)
{
    const int byte_per_col = g_BytesPerHexLine / g_HexColumns;
    if(_char < 0) return -1;
    if(_char >= (byte_per_col * 3 + 2) * g_HexColumns) return g_BytesPerHexLine;
    
    int col_num = _char / (byte_per_col * 3 + 2);
    int char_in_col = _char % (byte_per_col * 3 + 2);
    int byte_in_col = char_in_col / 3;
    
    return byte_in_col + col_num * byte_per_col;
}

enum class HitPart
{
    RowOffset,
    DataDump,
    Text
};

namespace
{

struct TextLine
{
    uint32_t char_start;        // unicode character index in window
    uint32_t chars_num;         // amount of unicode characters in line
    uint32_t string_byte_start; // byte information about string
    uint32_t string_bytes_num;
    uint32_t row_byte_start;    // offset within file window corresponding to the current row start 
    uint32_t row_bytes_num;

    CFStringRef text;
    CTLineRef   text_ctline;
    CFStringRef hex[g_HexColumns];
    CFStringRef row;
};
    
}

static const unsigned char g_4Bits_To_Char[16] = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};

@implementation BigFileViewHex
{
    // basic stuff
    BigFileView    *m_View;
    const UniChar  *m_Window;
    const uint32_t *m_Indeces;
    size_t          m_WindowSize;
    UniChar        *m_FixupWindow;
    
    unsigned              m_RowsOffset;
    int                   m_FrameLines; // amount of lines in our frame size ( +1 to fit cutted line also)    
    CGFloat               m_FontHeight;
    CGFloat               m_FontWidth;
    CGFloat                      m_FontAscent;
    CGFloat                      m_FontDescent;
    CGFloat                      m_FontLeading;
    CGFloat                      m_LeftInset;    
    std::vector<TextLine> m_Lines;
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
        
    m_FontHeight = GetLineHeightForFont([m_View TextFont], &m_FontAscent, &m_FontDescent, &m_FontLeading);
    m_FontWidth  = GetMonospaceFontCharWidth([m_View TextFont]);
    m_FrameLines = floor([_view frame].size.height / m_FontHeight);
    m_FixupWindow = (UniChar*) malloc(sizeof(UniChar) * [m_View RawWindowSize]);
    m_LeftInset = 5;
    
    [self OnBufferDecoded:m_WindowSize];
    
    m_RowsOffset = 0;
    
    [m_View setNeedsDisplay:true];
    return self;
}

- (void) dealloc
{
    [self ClearLayout];
    free(m_FixupWindow);    
}

- (void) OnBufferDecoded: (size_t) _new_size // unichars, not bytes (x2)
{
    [self ClearLayout];
    
    m_WindowSize = _new_size;
    
    // fix our decoded window - clear control characters
    for(size_t i = 0; i < m_WindowSize; ++i)
    {
        UniChar c = m_Window[i];
        if(c < 0x0020 || c == NSParagraphSeparatorCharacter || c == NSLineSeparatorCharacter)
            c = '.';
        m_FixupWindow[i] = c;
    }
    
    // split our string into a chunks of 16 bytes somehow
    const uint64_t raw_window_pos = [m_View RawWindowPosition];
    const uint64_t raw_window_size = [m_View RawWindowSize];
    uint32_t charind = 0; // for string breaking
    uint32_t charextrabytes = 0; // for string breaking, to handle large (more than 1 byte) characters
    uint32_t byteind = 0; // for hex rows
    
    while(true)
    {
        if(charind >= m_WindowSize)
            break;
        
        TextLine current;
        current.char_start = charind;
        current.string_byte_start = m_Indeces[current.char_start];
        current.row_byte_start = byteind;
        current.chars_num = 1;

        unsigned bytes_for_current_row = ((charind != 0) ?
                                          g_BytesPerHexLine : (g_BytesPerHexLine - raw_window_pos % g_BytesPerHexLine));
        unsigned bytes_for_current_string = bytes_for_current_row - charextrabytes;
        
        for(uint32_t i = charind + 1; i < m_WindowSize; ++i)
        {
            if(m_Indeces[i] - current.string_byte_start >= bytes_for_current_string)
                break;
            
            current.chars_num++;
        }
        
        if(current.char_start + current.chars_num < m_WindowSize)
            current.string_bytes_num = m_Indeces[current.char_start + current.chars_num] - current.string_byte_start;
        else
            current.string_bytes_num = (uint32_t)[m_View RawWindowSize] - current.string_byte_start;
        
        charextrabytes = current.string_bytes_num > bytes_for_current_string ?
            current.string_bytes_num - bytes_for_current_string :
            0;
        
        if(current.row_byte_start + bytes_for_current_row < raw_window_size) current.row_bytes_num = bytes_for_current_row;
        else current.row_bytes_num = (uint32_t)raw_window_size - current.row_byte_start;
        
        // build hex codes
        for(int i = 0; i < g_HexColumns; ++i)
        {
            const unsigned bytes_num = g_BytesPerHexLine / g_HexColumns;
            const unsigned char *bytes = (const unsigned char *)[m_View RawWindow] + current.row_byte_start;
            
            UniChar tmp[64];
            for(int j = 0; j < bytes_num*3; ++j)
                tmp[j] = ' ';
            
            for(int j = bytes_num*i; j < current.row_bytes_num; ++j)
            {
                unsigned char c = bytes[j];
                unsigned char lower_4bits = g_4Bits_To_Char[ c & 0x0F      ];
                unsigned char upper_4bits = g_4Bits_To_Char[(c & 0xF0) >> 4];
                
                tmp[(j - bytes_num*i)* 3]     = upper_4bits;
                tmp[(j - bytes_num*i)* 3 + 1] = lower_4bits;
                tmp[(j - bytes_num*i)* 3 + 2] = ' ';
            }
            
            current.hex[i] = CFStringCreateWithCharacters(0, tmp, bytes_num*3 - 1);
        }
        
        // build line number code
        {
            uint64_t row_offset = current.string_byte_start + [m_View RawWindowPosition];
            row_offset -= row_offset % g_BytesPerHexLine;
            UniChar tmp[g_RowOffsetSymbs];
            for(int i = g_RowOffsetSymbs - 1; i >= 0; --i)
            {
                tmp[i] = g_4Bits_To_Char[row_offset & 0xF];
                row_offset &= 0xFFFFFFFFFFFFFFF0;
                row_offset >>= 4;
            }
            
            current.row = CFStringCreateWithCharacters(0, tmp, g_RowOffsetSymbs);
        }
        
        m_Lines.push_back(current);
        
        charind += current.chars_num;
        byteind += current.row_bytes_num;
    }
    
    // once we have our layout built - it's time to produce our strings and CTLines, creation of which can be VERY long
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attributes, kCTForegroundColorAttributeName, [m_View TextForegroundColor]);
    CFDictionarySetValue(attributes, kCTFontAttributeName, [m_View TextFont]);    
    for(auto &i: m_Lines)
        dispatch_group_async(group, queue, ^{
            // build current CF string
            i.text = CFStringCreateWithCharactersNoCopy(0, m_FixupWindow + i.char_start, i.chars_num, kCFAllocatorNull);

            // attributed string and corresponding CTLine
            CFAttributedStringRef attr_str = CFAttributedStringCreate(0, i.text, attributes);
            i.text_ctline = CTLineCreateWithAttributedString( attr_str );
            CFRelease(attr_str);
        });
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    dispatch_release(group);
    CFRelease(attributes);
    
    [m_View setNeedsDisplay:true];
}

- (void) ClearLayout
{
    for(auto &i: m_Lines)
    {
        if(i.text_ctline != nil) CFRelease(i.text_ctline);
        if(i.text != nil) CFRelease(i.text);
        if(i.row != nil) CFRelease(i.row);

        for(auto &j: i.hex)
            if(j != nil) CFRelease(j);
    }
    m_Lines.clear();
}

- (CGPoint) TextAnchor
{
    NSRect v = [m_View visibleRect];
    CGPoint textPosition;
    textPosition.x = m_LeftInset;
    textPosition.y = v.size.height - m_FontHeight;
    return textPosition;
}

- (HitPart) PartHitTest: (CGPoint) _p
{
    CGPoint text_pos = [self TextAnchor];
    if(_p.x < text_pos.x + m_FontWidth * (g_RowOffsetSymbs + 3))
        return HitPart::RowOffset;
    
    if(_p.x < text_pos.x + m_FontWidth * (g_RowOffsetSymbs + 3) +
       m_FontWidth * (g_BytesPerHexLine / g_HexColumns * 3 + 2) * 2)
        return HitPart::DataDump;
    
    return HitPart::Text;
}

// should be called when Part is DataDump
- (int) ByteIndexFromHitTest: (CGPoint) _p
{
    CGPoint left_upper = [self TextAnchor];
    
    int y_off = ceil((left_upper.y - _p.y) / m_FontHeight);
    int row_no = y_off + m_RowsOffset;
    if(row_no < 0)
        return -1;
    if(row_no >= m_Lines.size())
        return (int)[m_View RawWindowSize] + 1;

    int x_off = _p.x - (left_upper.x + m_FontWidth * (g_RowOffsetSymbs + 3));
    int char_ind = ceil(x_off / m_FontWidth);
    int byte_pos = Hex_ByteFromCharPos(char_ind);
    if(byte_pos < 0) byte_pos = 0;
    return m_Lines[row_no].row_byte_start + byte_pos;
}

// shold be called when Part is Text
- (int) CharIndexFromHitTest: (CGPoint) _p
{
    CGPoint left_upper = [self TextAnchor];
    
    int y_off = ceil((left_upper.y - _p.y) / m_FontHeight);
    int row_no = y_off + m_RowsOffset;
    if(row_no < 0)
        return -1;
    if(row_no >= m_Lines.size())
        return (int)[m_View RawWindowSize] + 1;
    
    int x_off = _p.x - (left_upper.x +
                        m_FontWidth * (g_RowOffsetSymbs + 3) +
                        m_FontWidth * (g_BytesPerHexLine / g_HexColumns * 3 + 2) * 2);
    
    int ind = (int)CTLineGetStringIndexForPosition(m_Lines[row_no].text_ctline, CGPointMake(x_off, 0));
    
    if(ind != kCFNotFound)
        return m_Lines[row_no].char_start + ind;
    
    return m_Lines[row_no].char_start   ;    
}

- (void) DoDraw:(CGContextRef) _context dirty:(NSRect)_dirty_rect
{
    [m_View BackgroundFillColor].Set(_context);
    CGContextFillRect(_context, NSRectToCGRect(_dirty_rect));
    CGContextSetTextMatrix(_context, CGAffineTransformIdentity);
    CGContextSetTextDrawingMode(_context, kCGTextFill);
    CGContextSetShouldSmoothFonts(_context, false);
    CGContextSetShouldAntialias(_context, true);
    
    CFRange selection = [m_View SelectionWithinWindowUnichars];
    CFRange bselection = [m_View SelectionWithinWindow];

    CGPoint text_pos = [self TextAnchor];
    
    NSDictionary *text_attr =@{NSFontAttributeName:(__bridge NSFont*)[m_View TextFont],
                               NSForegroundColorAttributeName:[NSColor colorWithCGColor:[m_View TextForegroundColor]]};
    
    for(size_t i = m_RowsOffset; i < m_Lines.size(); ++i)
    {
        auto &c = m_Lines[i];
        
        CGPoint pos = text_pos;
        
        // draw row number
        [(__bridge NSString*)c.row drawAtPoint:pos withAttributes:text_attr];
        pos.x += m_FontWidth * (g_RowOffsetSymbs + 3);        

        if(bselection.location >= 0 && bselection.length > 0) // draw selection under hex codes
        {
            int start = (int)bselection.location, end = start + (int)bselection.length;
            if(start < c.row_byte_start) start = c.row_byte_start;
            if(end > c.row_byte_start + c.row_bytes_num) end = c.row_byte_start + c.row_bytes_num;
            if(start < end)
            {
                CGFloat x1 = Hex_CharPosFromByteNo(start - c.row_byte_start) * m_FontWidth;
                CGFloat x2 = Hex_CharPosFromByteNo(end - c.row_byte_start) * m_FontWidth;

                CGContextSaveGState(_context);
                CGContextSetShouldAntialias(_context, false);
                [m_View SelectionBkFillColor].Set(_context);
                CGContextFillRect(_context, CGRectMake(pos.x + x1, pos.y, x2 - x1, m_FontHeight));
                CGContextRestoreGState(_context);
            }
        }
        
        // draw hex codes
        [(__bridge NSString*)c.hex[0] drawAtPoint:pos withAttributes:text_attr];
        pos.x += m_FontWidth * (g_BytesPerHexLine / g_HexColumns * 3 + 2);

        [(__bridge NSString*)c.hex[1] drawAtPoint:pos withAttributes:text_attr];
        pos.x += m_FontWidth * (g_BytesPerHexLine / g_HexColumns * 3 + 2);
        
        if(selection.location >= 0 && selection.length > 0) // draw selection under text
        {
            CGFloat x1 = 0, x2  = -1;
            if(selection.location <= c.char_start &&
               selection.location + selection.length >= c.char_start + c.chars_num) // selected entire string
                x2 = CTLineGetOffsetForStringIndex(c.text_ctline, c.chars_num, 0);
            else if(selection.location >= c.char_start &&
                    selection.location < c.char_start + c.chars_num ) // selection inside or right trim
            {
                x1 = CTLineGetOffsetForStringIndex(c.text_ctline, selection.location - c.char_start, 0);
                x2 = CTLineGetOffsetForStringIndex(c.text_ctline,
                                                   (selection.location + selection.length > c.char_start + c.chars_num) ?
                                                   c.chars_num : selection.location + selection.length - c.char_start, 0);
            }
            else if(selection.location + selection.length >= c.char_start &&
                    selection.location + selection.length < c.char_start + c.chars_num) // left trim
                x2 = CTLineGetOffsetForStringIndex(c.text_ctline,
                                                   selection.location + selection.length - c.char_start,
                                                   0);

            if(x2 > x1)
            {
                CGContextSaveGState(_context);
                CGContextSetShouldAntialias(_context, false);
                [m_View SelectionBkFillColor].Set(_context);
                CGContextFillRect(_context, CGRectMake(pos.x + x1, pos.y, x2 - x1, m_FontHeight));
                CGContextRestoreGState(_context);
            }
        }
             
        // draw text itself (drawing with prepared CTLine should be faster than with raw CFString)
        CGContextSetTextPosition(_context, pos.x, pos.y + ceil(m_FontDescent));
        CTLineDraw(c.text_ctline, _context);
//        [(__bridge NSString*)c.text drawAtPoint:pos withAttributes:text_attr];
        
        text_pos.y -= m_FontHeight;
        if(text_pos.y < 0 - m_FontHeight)
            break;
    }
    
    // update scroller also
    double pos;
    if( [m_View FullSize] > g_BytesPerHexLine * m_FrameLines)
        pos = (double([m_View RawWindowPosition]) + double(m_RowsOffset*g_BytesPerHexLine) ) /
            double([m_View FullSize] - g_BytesPerHexLine * m_FrameLines);
    else
        pos = 0;
        
    double prop = ( double(g_BytesPerHexLine) * double(m_FrameLines) ) / double([m_View FullSize]);
    [m_View UpdateVerticalScroll:pos prop:prop];
}

- (void) OnUpArrow
{
    if(m_Lines.empty()) return;    
    assert(m_RowsOffset < m_Lines.size());
    if(m_RowsOffset > 1)
    {
        // just move offset;
        m_RowsOffset--;
        [m_View setNeedsDisplay:true];
    }
    else
    {
        uint64_t window_pos = [m_View RawWindowPosition];
        uint64_t window_size = [m_View RawWindowSize];

        // check if we can move our window up
        if(window_pos > 0)
        {
            uint64_t anchor_row_offset = (uint64_t)(m_Lines[m_RowsOffset].string_byte_start) + window_pos;
            
            uint64_t desired_window_offset = anchor_row_offset;
            if( desired_window_offset > 3*window_size/4 ) // TODO: need something more intelligent here
                desired_window_offset -= 3*window_size/4;
            else
                desired_window_offset = 0;
            
            [m_View RequestWindowMovementAt:desired_window_offset];
            
            assert(anchor_row_offset >= [m_View RawWindowPosition]);
            uint64_t anchor_new_offset = anchor_row_offset - [m_View RawWindowPosition];
            m_RowsOffset = unsigned(anchor_new_offset / g_BytesPerHexLine);
            assert(m_RowsOffset < m_Lines.size());
            [m_View setNeedsDisplay:true];
        }
        else
        {
            if(m_RowsOffset > 0)
            {
                m_RowsOffset--;
                [m_View setNeedsDisplay:true];
            }
        }
    }
}

- (void) OnDownArrow
{
    if(m_Lines.empty()) return;
    assert(m_RowsOffset < m_Lines.size());
    if(m_RowsOffset + m_FrameLines < m_Lines.size())
    {
        // just move offset;
        m_RowsOffset++;
        [m_View setNeedsDisplay:true];
    }
    else
    {
        uint64_t window_pos = [m_View RawWindowPosition];
        uint64_t window_size = [m_View RawWindowSize];
        uint64_t file_size = [m_View FullSize];
        if(window_pos + window_size < file_size)
        {
            uint64_t anchor_row_offset = (uint64_t)(m_Lines[m_RowsOffset].string_byte_start) + window_pos;
            
            uint64_t desired_window_offset = anchor_row_offset;
            assert(desired_window_offset > window_size/4);
            desired_window_offset -= window_size/4; // TODO: need something more intelligent here
            
            if(desired_window_offset + window_size > file_size) // we'll reach a file's end
                desired_window_offset = file_size - window_size;
            
            [m_View RequestWindowMovementAt:desired_window_offset];
            
            assert(anchor_row_offset >= [m_View RawWindowPosition]);
            uint64_t anchor_new_offset = anchor_row_offset - [m_View RawWindowPosition];
            m_RowsOffset = unsigned(anchor_new_offset / g_BytesPerHexLine) + 2; // why +2?
            assert(m_RowsOffset < m_Lines.size());
            [m_View setNeedsDisplay:true];
        }
    }
}

- (void) OnPageDown
{
    if(m_Lines.empty()) return;    
    assert(m_RowsOffset < m_Lines.size());
    
    if(m_RowsOffset + m_FrameLines * 2 < m_Lines.size())
    {
        // just move offset;
        m_RowsOffset += m_FrameLines;
        [m_View setNeedsDisplay:true];
    }
    else
    {
        uint64_t window_pos = [m_View RawWindowPosition];
        uint64_t window_size = [m_View RawWindowSize];
        uint64_t file_size = [m_View FullSize];
        if(window_pos + window_size < file_size)
        {
            assert(m_RowsOffset + m_FrameLines < m_Lines.size());
            uint64_t anchor_row_offset = (uint64_t)(m_Lines[m_RowsOffset + m_FrameLines].string_byte_start) + window_pos;
            
            uint64_t desired_window_offset = anchor_row_offset;
            assert(desired_window_offset > window_size/4);
            desired_window_offset -= window_size/4; // TODO: need something more intelligent here
            
            if(desired_window_offset + window_size > file_size) // we'll reach a file's end
                desired_window_offset = file_size - window_size;
            
            [m_View RequestWindowMovementAt:desired_window_offset];
            
            assert(anchor_row_offset >= [m_View RawWindowPosition]);
            uint64_t anchor_new_offset = anchor_row_offset - [m_View RawWindowPosition];
            m_RowsOffset = unsigned(anchor_new_offset / g_BytesPerHexLine) + 1;
            assert(m_RowsOffset < m_Lines.size());
            [m_View setNeedsDisplay:true];
        }
        else
        {
            if(m_RowsOffset + m_FrameLines < m_Lines.size())
            {
                m_RowsOffset = (unsigned)m_Lines.size() - m_FrameLines;
                [m_View setNeedsDisplay:true];
            }
        }
    }
}

- (void) OnPageUp
{
    if(m_Lines.empty()) return;    
    assert(m_RowsOffset < m_Lines.size());
    if(m_RowsOffset > m_FrameLines + 1)
    {
        m_RowsOffset -= m_FrameLines;
        [m_View setNeedsDisplay:true];
    }
    else
    {
        uint64_t window_pos = [m_View RawWindowPosition];
        uint64_t window_size = [m_View RawWindowSize];
        if(window_pos > 0)
        {
            uint64_t anchor_row_offset = (uint64_t)(m_Lines[m_RowsOffset].string_byte_start) + window_pos;            
            
            uint64_t desired_window_offset = anchor_row_offset;
            if( desired_window_offset > 3*window_size/4 ) // TODO: need something more intelligent here
                desired_window_offset -= 3*window_size/4;
            else
                desired_window_offset = 0;
            
            [m_View RequestWindowMovementAt:desired_window_offset];

            assert(anchor_row_offset >= [m_View RawWindowPosition]);
            uint64_t anchor_new_offset = anchor_row_offset - [m_View RawWindowPosition];
//            assert(unsigned(anchor_new_offset / g_BytesPerHexLine) >= m_FrameLines);
            if(unsigned(anchor_new_offset / g_BytesPerHexLine) >= m_FrameLines)
                m_RowsOffset = unsigned(anchor_new_offset / g_BytesPerHexLine) - m_FrameLines;
            else
                m_RowsOffset = 0;
            assert(m_RowsOffset < m_Lines.size());
            [m_View setNeedsDisplay:true];
        }
        else
        {
            if(m_RowsOffset > 0)
            {
                m_RowsOffset=0;
                [m_View setNeedsDisplay:true];
            }
        }
    }
}

- (uint32_t) GetOffsetWithinWindow
{
    if(m_Lines.empty())
        return 0;
    assert(m_RowsOffset < m_Lines.size());
    return m_Lines[m_RowsOffset].row_byte_start;
}

- (void) MoveOffsetWithinWindow: (uint32_t)_offset
{
    uint32_t min_dist = 1000000;
    size_t closest = 0;
    for(size_t i = 0; i < m_Lines.size(); ++i)
    {
        if(m_Lines[i].row_byte_start == _offset)
        {
            closest = i;
            break;
        }
        else
        {
            uint32_t dist = m_Lines[i].row_byte_start > _offset ? m_Lines[i].row_byte_start - _offset : _offset - m_Lines[i].row_byte_start;
            if(dist < min_dist)
            {
                min_dist = dist;
                closest = i;
            }
        }
    }
    
    m_RowsOffset = (unsigned)closest;
}

- (void) HandleVerticalScroll: (double) _pos
{
    if([m_View FullSize] < g_BytesPerHexLine * m_FrameLines)
        return;

    uint64_t file_size = [m_View FullSize];
    uint64_t bytepos = uint64_t( _pos * double(file_size - g_BytesPerHexLine * m_FrameLines) );
    [self ScrollToByteOffset:bytepos];
}

- (void) OnFrameChanged
{
    m_FrameLines = floor([m_View frame].size.height / m_FontHeight);    
}

- (void) ScrollToByteOffset: (uint64_t)_offset
{
    uint64_t window_pos = [m_View RawWindowPosition];
    uint64_t window_size = [m_View RawWindowSize];
    uint64_t file_size = [m_View FullSize];
    
    if(_offset > window_pos + g_BytesPerHexLine &&
       _offset + m_FrameLines * g_BytesPerHexLine < window_pos + window_size)
    { // we can just move our offset in window
        
        m_RowsOffset = unsigned ( (_offset - window_pos) / g_BytesPerHexLine );
        [m_View setNeedsDisplay:true];
    }
    else
    {
        if(window_pos > 0 || window_pos + window_size < file_size)
        {
            // we need to move file window
            uint64_t desired_wnd_pos = 0;
            if(_offset > window_size / 2)
                desired_wnd_pos = _offset - window_size/2;
            else
                desired_wnd_pos = 0;
            
            if(desired_wnd_pos + window_size > file_size)
                desired_wnd_pos = file_size - window_size;
            
            [m_View RequestWindowMovementAt:desired_wnd_pos];
            
            assert(desired_wnd_pos <= _offset);
            uint32_t byte_offset = uint32_t(_offset - desired_wnd_pos);
            m_RowsOffset = byte_offset / g_BytesPerHexLine;
            [m_View setNeedsDisplay:true];
        }
        else
        {
            unsigned des_row_offset = unsigned ( (_offset - window_pos) / g_BytesPerHexLine );
            if(des_row_offset + m_FrameLines > m_Lines.size())
            {
                if(des_row_offset > m_FrameLines)
                    des_row_offset -= m_FrameLines;
                else
                    des_row_offset = 0;
            }
            m_RowsOffset = des_row_offset;
            [m_View setNeedsDisplay:true];
        }
    }
}

- (void) OnMouseDown:(NSEvent *)event
{
    NSPoint first_down = [m_View convertPoint:[event locationInWindow] fromView:nil];
    HitPart hit_part = [self PartHitTest:first_down];
    
    if(hit_part == HitPart::DataDump)
    {
        int first_byte = [self ByteIndexFromHitTest:first_down];
        uint64_t window_size = [m_View RawWindowSize];
        if(first_byte < 0) first_byte = 0;
        if(first_byte > window_size) first_byte = (int)window_size;
        
        while ([event type]!=NSLeftMouseUp)
        {
            NSPoint loc = [m_View convertPoint:[event locationInWindow] fromView:nil];
            int curr_byte = [self ByteIndexFromHitTest:loc];
            if(curr_byte < 0) curr_byte = 0;
            if(curr_byte > window_size) curr_byte = (int)window_size;
            
            if(first_byte != curr_byte)
            {
                int sel_start = first_byte < curr_byte ? first_byte : curr_byte;
                int sel_end   = first_byte > curr_byte ? first_byte : curr_byte;
                [m_View SetSelectionInFile:CFRangeMake(sel_start + [m_View RawWindowPosition], sel_end - sel_start)];
            }
            else
                [m_View SetSelectionInFile:CFRangeMake(-1,0)];
            
            event = [[m_View window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        }
    }
    else if(hit_part == HitPart::Text)
    {
        int first_char = [self CharIndexFromHitTest:first_down];
        if(first_char < 0) first_char = 0;
        if(first_char > m_WindowSize) first_char = (int)m_WindowSize;
        
        while ([event type]!=NSLeftMouseUp)
        {
            NSPoint loc = [m_View convertPoint:[event locationInWindow] fromView:nil];
            int curr_char = [self CharIndexFromHitTest:loc];
            if(curr_char < 0) curr_char = 0;
            if(curr_char > m_WindowSize) curr_char = (int)m_WindowSize;

            if(first_char != curr_char)
            {
                int sel_start = first_char < curr_char ? first_char : curr_char;
                int sel_end   = first_char > curr_char ? first_char : curr_char;
                int sel_start_byte = sel_start < m_WindowSize ? m_Indeces[sel_start] : (int)[m_View RawWindowSize];
                int sel_end_byte = sel_end < m_WindowSize ? m_Indeces[sel_end] : (int)[m_View RawWindowSize];
                assert(sel_end_byte >= sel_start_byte);
                [m_View SetSelectionInFile:CFRangeMake(sel_start_byte + [m_View RawWindowPosition], sel_end_byte - sel_start_byte)];
            }
            else
                [m_View SetSelectionInFile:CFRangeMake(-1,0)];
        
            event = [[m_View window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        }
    }
}

@end




