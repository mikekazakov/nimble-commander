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

static const unsigned g_BytesPerHexLine = 16;
static const unsigned g_HexColumns = 2;
static const unsigned g_RowOffsetSymbs = 10;

struct MachTimeBenchmark
{
    uint64_t last;
    inline MachTimeBenchmark() : last(mach_absolute_time()) {};
    inline void Reset()
    {
        uint64_t now = mach_absolute_time();
        NSLog(@"%llu\n", (now - last) / 1000000 );
        last = now;
    }
};

namespace
{

struct TextLine
{
    uint32_t char_start; // unicode character index in window
    uint32_t chars_num;  // amount of unicode characters in line
    uint32_t string_byte_start;
    uint32_t string_bytes_num;
    uint32_t row_byte_start;    // offset within file window corresponding to the current row start 
    uint32_t row_bytes_num;
    CFStringRef string;
    CFMutableAttributedStringRef attr_string;
    
    struct
    {
        CFStringRef string;
        CFMutableAttributedStringRef attr_string;
    } hex[g_HexColumns];
    
    struct
    {
        CFStringRef string;
        CFMutableAttributedStringRef attr_string;
    } row;
};
    
}

static const unsigned char g_4Bits_To_Char[16] = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};

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


@implementation BigFileViewHex
{
    // basic stuff
    BigFileView    *m_View;
    const UniChar  *m_Window;
    const uint32_t *m_Indeces;
    size_t          m_WindowSize;
    
    unsigned              m_RowsOffset;
    int                   m_FrameLines; // amount of lines in our frame size ( +1 to fit cutted line also)    
    CGFloat               m_FontHeight;
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
        
    m_FontHeight = GetLineHeightForFont([m_View TextFont]);
    m_FrameLines = [_view frame].size.height / m_FontHeight;
    
//    MachTimeBenchmark m;
    [self OnBufferDecoded:m_WindowSize];
//    m.Reset();
    
    m_RowsOffset = 0;
    
    [m_View setNeedsDisplay:true];
    return self;
}

- (void) dealloc
{
    [self ClearLayout];
}

- (void) OnBufferDecoded: (size_t) _new_size // unichars, not bytes (x2)
{
    [self ClearLayout];
    
    m_WindowSize = _new_size;
    
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
                    
        // check if there's a manual line-breaking codes in this text block. if yes - need to build a temp string with replacements
        bool need_fixup = false;
        for(uint32_t i = current.char_start; i < current.char_start + current.chars_num; ++i)
            if(m_Window[i] == 0x0D || m_Window[i] == 0x0A || m_Window[i] == 0x09) // for DOS-style too
            {
                need_fixup = true;
                break;
            }

        // built current CF string
        if(!need_fixup)
        {
            current.string = CFStringCreateWithBytesNoCopy(0,
                                                       (UInt8*) (m_Window + current.char_start),
                                                       current.chars_num*sizeof(UniChar),
                                                       kCFStringEncodingUnicode,
                                                       false,
                                                       kCFAllocatorNull);
        }
        else
        {
            UniChar tmp[256];
            assert(current.chars_num < 256);
            memcpy(tmp, m_Window + current.char_start, current.chars_num*sizeof(UniChar));
            for(uint32_t i = 0; i < current.chars_num; ++i)
            {
                if(tmp[i] == 0x0A) tmp[i] = 0x25D9;
                if(tmp[i] == 0x0D) tmp[i] = 0x266A;
                if(tmp[i] == 0x09) tmp[i] = 0x25CB;
            }

            current.string = CFStringCreateWithBytes(0,
                                                           (UInt8*) tmp,
                                                           current.chars_num*sizeof(UniChar),
                                                           kCFStringEncodingUnicode,
                                                           false);
        }
        
        // built attribute string for current line
        current.attr_string = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
        CFAttributedStringReplaceString(current.attr_string, CFRangeMake(0, 0), current.string);
        CFAttributedStringSetAttribute(current.attr_string, CFRangeMake(0, current.chars_num), kCTForegroundColorAttributeName, [m_View TextForegroundColor]);
        CFAttributedStringSetAttribute(current.attr_string, CFRangeMake(0, current.chars_num), kCTFontAttributeName, [m_View TextFont]);
        
        // build hex codes
        for(int i = 0; i < g_HexColumns; ++i)
        {
            const unsigned bytes_num = g_BytesPerHexLine / g_HexColumns;
            const unsigned char *bytes = (const unsigned char *)[m_View RawWindow] + current.row_byte_start;
            
            UniChar tmp[256];
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
            
            current.hex[i].string = CFStringCreateWithBytes(0,
                                                            (UInt8*) tmp,
                                                            bytes_num*3*sizeof(UniChar),
                                                            kCFStringEncodingUnicode,
                                                            false);
            
            current.hex[i].attr_string = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
            CFAttributedStringReplaceString(current.hex[i].attr_string, CFRangeMake(0, 0), current.hex[i].string);
            CFAttributedStringSetAttribute(current.hex[i].attr_string, CFRangeMake(0, bytes_num*3), kCTForegroundColorAttributeName, [m_View TextForegroundColor]);
            CFAttributedStringSetAttribute(current.hex[i].attr_string, CFRangeMake(0, bytes_num*3), kCTFontAttributeName, [m_View TextFont]);            
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
            
            current.row.string = CFStringCreateWithBytes(0, (UInt8*)tmp, g_RowOffsetSymbs*sizeof(UniChar), kCFStringEncodingUnicode, false);
            current.row.attr_string = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0);
            CFAttributedStringReplaceString(current.row.attr_string, CFRangeMake(0, 0), current.row.string);
            CFAttributedStringSetAttribute(current.row.attr_string, CFRangeMake(0, g_RowOffsetSymbs), kCTForegroundColorAttributeName, [m_View TextForegroundColor]);
            CFAttributedStringSetAttribute(current.row.attr_string, CFRangeMake(0, g_RowOffsetSymbs), kCTFontAttributeName, [m_View TextFont]);
        }
        
        m_Lines.push_back(current);
        
        charind += current.chars_num;
        byteind += current.row_bytes_num;
    }
    
}

- (void) ClearLayout
{
    for(auto &i: m_Lines)
    {
        if(i.string != nil) CFRelease(i.string);
        if(i.attr_string != nil) CFRelease(i.attr_string);

        if(i.row.string != nil) CFRelease(i.row.string);
        if(i.row.attr_string != nil) CFRelease(i.row.attr_string);

        for(auto &j: i.hex)
        {
            if(j.string != nil) CFRelease(j.string);
            if(j.attr_string != nil) CFRelease(j.attr_string);
        }
    }
    m_Lines.clear();
}

- (void) DoDraw:(CGContextRef) _context dirty:(NSRect)_dirty_rect
{
    CGContextSetRGBFillColor(_context, 1,1,1,1);
    CGContextFillRect(_context, NSRectToCGRect(_dirty_rect));
    CGContextSetTextMatrix(_context, CGAffineTransformIdentity);
    
    
    NSRect v = [m_View visibleRect];
    
    CGPoint textPosition;
    textPosition.x = 0;
    textPosition.y = v.size.height - m_FontHeight;
    
    size_t first_string = m_RowsOffset;
    for(size_t i = first_string; i < m_Lines.size(); ++i)
    {
        
        auto &c = m_Lines[i];
        
        [(__bridge NSAttributedString*) c.row.attr_string drawWithRect:NSMakeRect(0, textPosition.y, 0, 0) options:0 ];
        [(__bridge NSAttributedString*) c.hex[0].attr_string drawWithRect:NSMakeRect(100, textPosition.y, 0, 0) options:0 ];
        [(__bridge NSAttributedString*) c.hex[1].attr_string drawWithRect:NSMakeRect(300, textPosition.y, 0, 0) options:0 ];
        [(__bridge NSAttributedString*) c.attr_string drawWithRect:NSMakeRect(500, textPosition.y, 0, 0) options:0 ];
        
        textPosition.y -= m_FontHeight;
        if(textPosition.y < 0 - m_FontHeight)
            break;
    }    
}

- (void) OnUpArrow
{
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
            if( desired_window_offset > (window_size*8)/10 ) // TODO: need something more intelligent here
                desired_window_offset -= (window_size*8)/10;
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
            assert(desired_window_offset > (window_size*2)/10);
            desired_window_offset -= (window_size*2)/10; // TODO: need something more intelligent here
            
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
            assert(desired_window_offset > (window_size*2)/10);
            desired_window_offset -= (window_size*2)/10; // TODO: need something more intelligent here
            
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
            if( desired_window_offset > (window_size*8)/10 ) // TODO: need something more intelligent here
                desired_window_offset -= (window_size*8)/10;
            else
                desired_window_offset = 0;
            
            [m_View RequestWindowMovementAt:desired_window_offset];

            assert(anchor_row_offset >= [m_View RawWindowPosition]);
            uint64_t anchor_new_offset = anchor_row_offset - [m_View RawWindowPosition];
            assert(unsigned(anchor_new_offset / g_BytesPerHexLine) >= m_FrameLines);
            m_RowsOffset = unsigned(anchor_new_offset / g_BytesPerHexLine) - m_FrameLines;
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
            min_dist = 0;
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

@end
