// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/algo.h>
#include <Utility/NSView+Sugar.h>
#include "BigFileViewHex.h"
#include "BigFileView.h"
#include <cmath>

static const int g_BytesPerHexLine = 16;
static const int g_RowOffsetSymbs = 10;
static const int g_GapBetweenColumns = 2;
static const int g_SymbsPerBytes = 2;
static const int g_GapBetweenBytes = 1;
static const int g_HexColumns = 2;

// return monospace char index before the specified _byte byte.
// includes spaces (2 space) between columns and spaces (1 space) between bytes
// handles the last byte + 1 separately
static int Hex_CharPosFromByteNo(int _byte)
{
    const int byte_per_col = g_BytesPerHexLine / g_HexColumns;
    const int chars_pers_byte = g_SymbsPerBytes + g_GapBetweenBytes;
    assert(_byte <= g_BytesPerHexLine);
    
    if(_byte == g_BytesPerHexLine) // special case
        return (byte_per_col * chars_pers_byte + g_GapBetweenColumns) * g_HexColumns - g_GapBetweenColumns;
    
    int col_num = _byte / byte_per_col;
    int byte_in_col = _byte % byte_per_col;
    
    int char_in_col = byte_in_col * chars_pers_byte;
    
    return char_in_col + (byte_per_col * chars_pers_byte + g_GapBetweenColumns) * col_num;
}

static int Hex_ByteFromCharPos(int _char)
{
    const int byte_per_col = g_BytesPerHexLine / g_HexColumns;
    const int chars_pers_byte = g_SymbsPerBytes + g_GapBetweenBytes;
    
    if(_char < 0) return -1;
    if(_char >= (byte_per_col * chars_pers_byte + g_GapBetweenColumns) * g_HexColumns) return g_BytesPerHexLine;
    
    int col_num = _char / (byte_per_col * chars_pers_byte + g_GapBetweenColumns);
    int char_in_col = _char % (byte_per_col * chars_pers_byte + g_GapBetweenColumns);
    int byte_in_col = char_in_col / chars_pers_byte;
    
    return byte_in_col + col_num * byte_per_col;
}

static const unsigned char g_4Bits_To_Char[16] = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};

struct BigFileViewHex::TextLine
{
    uint32_t char_start;        // unicode character index in window
    uint32_t chars_num;         // amount of unicode characters in line
    uint32_t string_byte_start; // byte information about string
    uint32_t string_bytes_num;
    uint32_t row_byte_start;    // offset within file window corresponding to the current row start
    uint32_t row_bytes_num;
    
    CTLineRef   text_ctline;
    CFStringRef hex[g_HexColumns];
    CFStringRef row;
};

BigFileViewHex::BigFileViewHex(BigFileViewDataBackend* _data, BigFileView* _view)
{
    m_View = _view;
    m_Data = _data;
    m_FixupWindow = std::make_unique<UniChar[]>(m_Data->RawSize());
    m_LeftInset = 5;
    
    GrabFontGeometry();
    
    OnBufferDecoded();
    
    m_RowsOffset = 0;
    
    [m_View setNeedsDisplay];
    assert(m_FrameLines >= 0);
}

BigFileViewHex::~BigFileViewHex()
{
    ClearLayout();
}

void BigFileViewHex::GrabFontGeometry()
{
    m_FontInfo = nc::utility::FontGeometryInfo([m_View TextFont]);
    m_FrameLines = (int)std::floor(m_View.contentBounds.height / m_FontInfo.LineHeight() );
}

void BigFileViewHex::OnBufferDecoded()
{
    ClearLayout();
    
    // fix our decoded window - clear control characters
    auto uni_window = m_Data->UniChars();
    size_t uni_window_sz = m_Data->UniCharsSize();
    for(size_t i = 0; i < uni_window_sz; ++i)
    {
        UniChar c = uni_window[i];
        if(c < 0x0020 ||
           c == 0x007F ||
           c == NSParagraphSeparatorCharacter ||
           c == NSLineSeparatorCharacter )
            c = '.';
        m_FixupWindow[i] = c;
    }
    
    // split our string into a chunks of 16 bytes somehow
    const uint64_t raw_window_pos = m_Data->FilePos();
    const uint64_t raw_window_size = m_Data->RawSize();
    const unsigned char *raw_window = (const unsigned char *)m_Data->Raw();
    uint32_t charind = 0; // for string breaking
    uint32_t charextrabytes = 0; // for string breaking, to handle large (more than 1 byte) characters
    uint32_t byteind = 0; // for hex rows

    while(true)
    {
        if(charind >= uni_window_sz)
            break;
        
        TextLine current;
        current.char_start = charind;
        current.string_byte_start = m_Data->UniCharToByteIndeces()[current.char_start];
        current.row_byte_start = byteind;
        current.chars_num = 1;

        unsigned bytes_for_current_row = ((charind != 0) ?
                                          g_BytesPerHexLine : (g_BytesPerHexLine - raw_window_pos % g_BytesPerHexLine));
        unsigned bytes_for_current_string = bytes_for_current_row - charextrabytes;
        
        for(uint32_t i = charind + 1; i < uni_window_sz; ++i)
        {
            if(m_Data->UniCharToByteIndeces()[i] - current.string_byte_start >= bytes_for_current_string)
                break;
            
            current.chars_num++;
        }
        
        if(current.char_start + current.chars_num < uni_window_sz)
            current.string_bytes_num = m_Data->UniCharToByteIndeces()[current.char_start + current.chars_num] - current.string_byte_start;
        else
            current.string_bytes_num = (uint32_t)raw_window_size - current.string_byte_start;
        
        charextrabytes = current.string_bytes_num > bytes_for_current_string ?
            current.string_bytes_num - bytes_for_current_string :
            0;
        
        if(current.row_byte_start + bytes_for_current_row < raw_window_size) current.row_bytes_num = bytes_for_current_row;
        else current.row_bytes_num = (uint32_t)raw_window_size - current.row_byte_start;
        
        m_Lines.push_back(current);
        
        charind += current.chars_num;
        byteind += current.row_bytes_num;
    }
    
    // once we have our layout built - it's time to produce our strings and CTLines, creation of which can be VERY long
    CFMutableDictionaryRef attributes = CFDictionaryCreateMutable(kCFAllocatorDefault, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(attributes, kCTForegroundColorAttributeName, [m_View TextForegroundColor]);
    CFDictionarySetValue(attributes, kCTFontAttributeName, [m_View TextFont]);
    
    CFStringRef big_string = CFStringCreateWithCharactersNoCopy(0, &m_FixupWindow[0], uni_window_sz, kCFAllocatorNull);
    CFAttributedStringRef big_attr_str = CFAttributedStringCreate(0, big_string, attributes);
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(big_attr_str);
    
    dispatch_apply(m_Lines.size(), dispatch_get_global_queue(0, 0), ^(size_t n) {
            auto &i = m_Lines[n];
        
            // build hex codes
            for(int col = 0; col < g_HexColumns; ++col)
            {
                const auto bytes_num = g_BytesPerHexLine / g_HexColumns;
                const unsigned char *bytes = raw_window + i.row_byte_start;
            
                UniChar tmp[64];
                for(int j = 0; j < bytes_num*3; ++j)
                    tmp[j] = ' ';
            
                for(int j = bytes_num*col; j < (int)i.row_bytes_num; ++j)
                {
                    unsigned char c = bytes[j];
                    unsigned char lower_4bits = g_4Bits_To_Char[ c & 0x0F      ];
                    unsigned char upper_4bits = g_4Bits_To_Char[(c & 0xF0) >> 4];
                
                    tmp[(j - bytes_num*col)* 3]     = upper_4bits;
                    tmp[(j - bytes_num*col)* 3 + 1] = lower_4bits;
                    tmp[(j - bytes_num*col)* 3 + 2] = ' ';
                }
            
                i.hex[col] = CFStringCreateWithCharacters(0, tmp, bytes_num*3 - 1);
            }
        
            // build line number code
            {
                uint64_t row_offset = i.string_byte_start + raw_window_pos;
                row_offset -= row_offset % g_BytesPerHexLine;
                UniChar tmp[g_RowOffsetSymbs];
                for( int char_ind = g_RowOffsetSymbs - 1; char_ind >= 0; --char_ind ) {
                    tmp[char_ind] = g_4Bits_To_Char[row_offset & 0xF];
                    row_offset &= 0xFFFFFFFFFFFFFFF0;
                    row_offset >>= 4;
                }
            
                i.row = CFStringCreateWithCharacters(0, tmp, g_RowOffsetSymbs);
            }
        
            // build CTLine
            i.text_ctline = CTTypesetterCreateLine(typesetter, CFRangeMake(i.char_start, i.chars_num));

        });
    CFRelease(typesetter);
    CFRelease(big_attr_str);
    CFRelease(big_string);
    CFRelease(attributes);
    
    [m_View setNeedsDisplay];
}

void BigFileViewHex::OnFontSettingsChanged()
{
    GrabFontGeometry();
    OnBufferDecoded();
}

void BigFileViewHex::ClearLayout()
{
    for(auto &i: m_Lines)
    {
        if(i.text_ctline != nil) CFRelease(i.text_ctline);
        if(i.row != nil) CFRelease(i.row);

        for(auto &j: i.hex)
            if(j != nil) CFRelease(j);
    }
    m_Lines.clear();
}

CGPoint BigFileViewHex::TextAnchor()
{
    NSRect v = [m_View visibleRect];
    CGPoint textPosition;
    textPosition.x = std::ceil(m_LeftInset) + m_SmoothOffset.x;
    textPosition.y = std::floor(v.size.height - m_FontInfo.LineHeight()) + m_SmoothOffset.y;
    return textPosition;
}

BigFileViewHex::HitPart BigFileViewHex::PartHitTest(CGPoint _p)
{
    CGPoint text_pos = TextAnchor();
    if(_p.x < text_pos.x + m_FontInfo.MonospaceWidth() * (g_RowOffsetSymbs + 3))
        return HitPart::RowOffset;
    
    if(_p.x < text_pos.x + m_FontInfo.MonospaceWidth() * (g_RowOffsetSymbs + 3) +
       m_FontInfo.MonospaceWidth() * (g_BytesPerHexLine / g_HexColumns * 3 + 2) * 2)
        return HitPart::DataDump;
    
    return HitPart::Text;
}

// should be called when Part is DataDump
int BigFileViewHex::ByteIndexFromHitTest(CGPoint _p)
{
    CGPoint left_upper = TextAnchor();
    
    int y_off = (int)std::ceil((left_upper.y - _p.y) / m_FontInfo.LineHeight());
    int row_no = y_off + m_RowsOffset;
    if(row_no < 0)
        return -1;
    if(row_no >= (int)m_Lines.size())
        return (int)m_Data->RawSize() + 1;

    int x_off = int(_p.x - (left_upper.x + m_FontInfo.MonospaceWidth() * (g_RowOffsetSymbs + 3)));
    int char_ind = (int)std::ceil(x_off / m_FontInfo.MonospaceWidth());
    int byte_pos = Hex_ByteFromCharPos(char_ind);
    if(byte_pos < 0) byte_pos = 0;
    return m_Lines[row_no].row_byte_start + byte_pos;
}

// shold be called when Part is Text
int BigFileViewHex::CharIndexFromHitTest(CGPoint _p)
{
    CGPoint left_upper = TextAnchor();
    
    int y_off = (int)std::ceil((left_upper.y - _p.y) / m_FontInfo.LineHeight());
    int row_no = y_off + m_RowsOffset;
    if(row_no < 0)
        return -1;
    if(row_no >= (int)m_Lines.size())
        return (int)m_Data->RawSize() + 1; // ???????? here should be m_Data->UniCharSize ?
    
    int x_off = (int)_p.x - (int)(left_upper.x +
                        m_FontInfo.MonospaceWidth() * (g_RowOffsetSymbs + 3) +
                        m_FontInfo.MonospaceWidth() * (g_BytesPerHexLine / g_HexColumns * 3 + 2) * 2);
    
    int ind = (int)CTLineGetStringIndexForPosition(m_Lines[row_no].text_ctline, CGPointMake(x_off, 0));
    
    if(ind != kCFNotFound)
        return ind;
    
    return m_Lines[row_no].char_start;    
}

void BigFileViewHex::DoDraw(CGContextRef _context, NSRect _dirty_rect)
{
//    [m_View BackgroundFillColor].Set(_context);
    CGContextSetFillColorWithColor(_context, m_View.BackgroundFillColor);
    CGContextFillRect(_context, NSRectToCGRect(_dirty_rect));
    CGContextSetTextMatrix(_context, CGAffineTransformIdentity);
    CGContextSetTextDrawingMode(_context, kCGTextFill);
    CGContextSetShouldSmoothFonts(_context, true);
    CGContextSetShouldAntialias(_context, true);
    
    CFRange selection = [m_View SelectionWithinWindowUnichars];
    CFRange bselection = [m_View SelectionWithinWindow];

    CGPoint text_pos = TextAnchor();
    
    NSDictionary *text_attr =@{NSFontAttributeName:(NSFont*)[m_View TextFont],
                               NSForegroundColorAttributeName:[NSColor colorWithCGColor:[m_View TextForegroundColor]]};
    
    size_t first_row = m_RowsOffset;
    if(m_SmoothOffset.y < 0 && first_row > 0)
    {
        --first_row; // to be sure that we can see bottom-clipped lines
        text_pos.y += m_FontInfo.LineHeight();
    }
    
    for(size_t i = first_row; i < m_Lines.size(); ++i)
    {
        auto &c = m_Lines[i];
        
        CGPoint pos = text_pos;
        
        // draw row number
        [(__bridge NSString*)c.row drawAtPoint:pos withAttributes:text_attr];
        pos.x += m_FontInfo.MonospaceWidth() * (g_RowOffsetSymbs + 3);

        if(bselection.location >= 0 && bselection.length > 0) // draw selection under hex codes
        {
            int start = (int)bselection.location, end = start + (int)bselection.length;
            if(start < (int)c.row_byte_start)
                start = c.row_byte_start;
            if(end > int(c.row_byte_start + c.row_bytes_num))
                end = c.row_byte_start + c.row_bytes_num;
            if(start < end)
            {
                CGFloat x1 = Hex_CharPosFromByteNo(start - c.row_byte_start) * m_FontInfo.MonospaceWidth();
                CGFloat x2 = Hex_CharPosFromByteNo(end - c.row_byte_start) * m_FontInfo.MonospaceWidth();

                CGContextSaveGState(_context);
                CGContextSetShouldAntialias(_context, false);
                //[m_View SelectionBkFillColor].Set(_context);
                CGContextSetFillColorWithColor(_context, m_View.SelectionBkFillColor);
                CGContextFillRect(_context, CGRectMake(pos.x + x1, pos.y, x2 - x1, m_FontInfo.LineHeight()));
                CGContextRestoreGState(_context);
            }
        }
        
        // draw hex codes
        [(__bridge NSString*)c.hex[0] drawAtPoint:pos withAttributes:text_attr];
        pos.x += m_FontInfo.MonospaceWidth() * (g_BytesPerHexLine / g_HexColumns * 3 + 2);

        [(__bridge NSString*)c.hex[1] drawAtPoint:pos withAttributes:text_attr];
        pos.x += m_FontInfo.MonospaceWidth() * (g_BytesPerHexLine / g_HexColumns * 3 + 2);
        
        if(selection.location >= 0 && selection.length > 0) // draw selection under text
        {
            CGFloat x1 = 0, x2  = -1;
            if(selection.location <= c.char_start &&
               selection.location + selection.length >= c.char_start + c.chars_num) // selected entire string
                x2 = CTLineGetOffsetForStringIndex(c.text_ctline, c.char_start + c.chars_num, 0);
            else if(selection.location >= c.char_start &&
                    selection.location < c.char_start + c.chars_num ) // selection inside or right trim
            {
                x1 = CTLineGetOffsetForStringIndex(c.text_ctline, selection.location, 0);
                x2 = CTLineGetOffsetForStringIndex(c.text_ctline,
                                                   (selection.location + selection.length > c.char_start + c.chars_num) ?
                                                   c.char_start + c.chars_num : selection.location + selection.length, 0);
            }
            else if(selection.location + selection.length >= c.char_start &&
                    selection.location + selection.length < c.char_start + c.chars_num) // left trim
                x2 = CTLineGetOffsetForStringIndex(c.text_ctline,
                                                   selection.location + selection.length,
                                                   0);

            if(x2 > x1)
            {
                CGContextSaveGState(_context);
                CGContextSetShouldAntialias(_context, false);
                //[m_View SelectionBkFillColor].Set(_context);
                CGContextSetFillColorWithColor(_context, m_View.SelectionBkFillColor);
                CGContextFillRect(_context, CGRectMake(pos.x + x1, pos.y, x2 - x1, m_FontInfo.LineHeight()));
                CGContextRestoreGState(_context);
            }
        }
        
        // draw text itself (drawing with prepared CTLine should be faster than with raw CFString)
        CGContextSetTextMatrix(_context, CGAffineTransformIdentity);
        CGContextSetTextPosition(_context, pos.x, pos.y + std::ceil(m_FontInfo.Descent()));
        CTLineDraw(c.text_ctline, _context);
        
        text_pos.y -= m_FontInfo.LineHeight();
        if(text_pos.y < 0 - m_FontInfo.LineHeight())
            break;
    }
}

void BigFileViewHex::CalculateScrollPosition( double &_position, double &_knob_proportion )
{
    // update scroller also
    double pos;
    if( m_Data->FileSize() > uint64_t(g_BytesPerHexLine * m_FrameLines) )
        pos = (double(m_Data->FilePos()) + double(m_RowsOffset*g_BytesPerHexLine) ) /
            double(m_Data->FileSize() - g_BytesPerHexLine * m_FrameLines);
    else
        pos = 0;
    
    double prop = ( double(g_BytesPerHexLine) * double(m_FrameLines) ) / double(m_Data->FileSize());
    _position = pos;
    _knob_proportion = prop;
}

void BigFileViewHex::OnUpArrow()
{
    if(m_Lines.empty()) return;    
    assert(m_RowsOffset < m_Lines.size());
    if(m_RowsOffset > 1)
    {
        // just move offset;
        m_RowsOffset--;
        [m_View setNeedsDisplay];
    }
    else
    {
        uint64_t window_pos = m_Data->FilePos();
        uint64_t window_size = m_Data->RawSize();

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
            
            assert(anchor_row_offset >= m_Data->FilePos());
            uint64_t anchor_new_offset = anchor_row_offset - m_Data->FilePos();
            m_RowsOffset = unsigned(anchor_new_offset / g_BytesPerHexLine);
            assert(m_RowsOffset < m_Lines.size());
            [m_View setNeedsDisplay];
        }
        else
        {
            if(m_RowsOffset > 0)
            {
                m_RowsOffset--;
                [m_View setNeedsDisplay];
            }
        }
    }
}

void BigFileViewHex::OnDownArrow()
{
    if(m_Lines.empty()) return;
    assert(m_RowsOffset < m_Lines.size());
    if(m_RowsOffset + m_FrameLines < m_Lines.size())
    {
        // just move offset;
        m_RowsOffset++;
        [m_View setNeedsDisplay];
    }
    else
    {
        uint64_t window_pos = m_Data->FilePos();
        uint64_t window_size = m_Data->RawSize();
        uint64_t file_size = m_Data->FileSize();
        if(window_pos + window_size < file_size)
        {
            uint64_t anchor_row_offset = (uint64_t)(m_Lines[m_RowsOffset].string_byte_start) + window_pos;
            
            uint64_t desired_window_offset = anchor_row_offset;
            assert(desired_window_offset > window_size/4);
            desired_window_offset -= window_size/4; // TODO: need something more intelligent here
            
            if(desired_window_offset + window_size > file_size) // we'll reach a file's end
                desired_window_offset = file_size - window_size;
            
            [m_View RequestWindowMovementAt:desired_window_offset];
            
            assert(anchor_row_offset >= m_Data->FilePos());
            uint64_t anchor_new_offset = anchor_row_offset - m_Data->FilePos();
            m_RowsOffset = unsigned(anchor_new_offset / g_BytesPerHexLine) + 2; // why +2?
            assert(m_RowsOffset < m_Lines.size());
            [m_View setNeedsDisplay];
        }
    }
}

void BigFileViewHex::OnPageDown()
{
    if(m_Lines.empty()) return;    
    assert(m_RowsOffset < m_Lines.size());
    
    if(m_RowsOffset + m_FrameLines * 2 < m_Lines.size())
    {
        // just move offset;
        m_RowsOffset += m_FrameLines;
        [m_View setNeedsDisplay];
    }
    else
    {
        uint64_t window_pos = m_Data->FilePos();
        uint64_t window_size = m_Data->RawSize();
        uint64_t file_size = m_Data->FileSize();
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
            
            assert(anchor_row_offset >= m_Data->FilePos());
            uint64_t anchor_new_offset = anchor_row_offset - m_Data->FilePos();
            m_RowsOffset = unsigned(anchor_new_offset / g_BytesPerHexLine) + 1;
            assert(m_RowsOffset < m_Lines.size());
            [m_View setNeedsDisplay];
        }
        else
        {
            if(m_RowsOffset + m_FrameLines < m_Lines.size())
            {
                m_RowsOffset = (unsigned)m_Lines.size() - m_FrameLines;
                [m_View setNeedsDisplay];
            }
        }
    }
}

void BigFileViewHex::OnPageUp()
{
    if(m_Lines.empty()) return;    
    assert(m_RowsOffset < m_Lines.size());
    if(m_RowsOffset > unsigned(m_FrameLines + 1))
    {
        m_RowsOffset -= m_FrameLines;
        [m_View setNeedsDisplay];
    }
    else
    {
        uint64_t window_pos = m_Data->FilePos();
        uint64_t window_size = m_Data->RawSize();
        if(window_pos > 0)
        {
            uint64_t anchor_row_offset = (uint64_t)(m_Lines[m_RowsOffset].string_byte_start) + window_pos;            
            
            uint64_t desired_window_offset = anchor_row_offset;
            if( desired_window_offset > 3*window_size/4 ) // TODO: need something more intelligent here
                desired_window_offset -= 3*window_size/4;
            else
                desired_window_offset = 0;
            
            [m_View RequestWindowMovementAt:desired_window_offset];

            assert(anchor_row_offset >= m_Data->FilePos());
            uint64_t anchor_new_offset = anchor_row_offset - m_Data->FilePos();
            if( long(anchor_new_offset / g_BytesPerHexLine) >= m_FrameLines )
                m_RowsOffset = unsigned(anchor_new_offset / g_BytesPerHexLine) - m_FrameLines;
            else
                m_RowsOffset = 0;
            assert(m_RowsOffset < m_Lines.size());
            [m_View setNeedsDisplay];
        }
        else
        {
            if(m_RowsOffset > 0)
            {
                m_RowsOffset=0;
                [m_View setNeedsDisplay];
            }
        }
    }
}

uint32_t BigFileViewHex::GetOffsetWithinWindow()
{
    if(m_Lines.empty())
        return 0;
    assert(m_RowsOffset < m_Lines.size());
    return m_Lines[m_RowsOffset].row_byte_start;
}

void BigFileViewHex::MoveOffsetWithinWindow(uint32_t _offset)
{
    // A VERY BAD IMPLEMENTATION!!!!
    // TODO: optimize me
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
    m_SmoothOffset.y = 0;
}

void BigFileViewHex::HandleVerticalScroll(double _pos)
{
    if( m_Data->FileSize() < uint64_t(g_BytesPerHexLine * m_FrameLines) )
        return;

    uint64_t file_size = m_Data->FileSize();
    uint64_t bytepos = uint64_t( _pos * double(file_size - g_BytesPerHexLine * m_FrameLines) );
    ScrollToByteOffset(bytepos);
}

void BigFileViewHex::OnFrameChanged()
{
    m_FrameLines = (int)std::floor([m_View frame].size.height / m_FontInfo.LineHeight());
}

void BigFileViewHex::ScrollToByteOffset(uint64_t _offset)
{
    uint64_t window_pos = m_Data->FilePos();
    uint64_t window_size = m_Data->RawSize();
    uint64_t file_size = m_Data->FileSize();
    
    if( _offset >= file_size )
        return;
    
    if(_offset > window_pos + g_BytesPerHexLine &&
       _offset + m_FrameLines * g_BytesPerHexLine < window_pos + window_size)
    { // we can just move our offset in window
        
        m_RowsOffset = unsigned ( (_offset - window_pos) / g_BytesPerHexLine );
        [m_View setNeedsDisplay];
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
            [m_View setNeedsDisplay];
        }
        else
        {
            unsigned des_row_offset = unsigned ( (_offset - window_pos) / g_BytesPerHexLine );
            if(des_row_offset + m_FrameLines > m_Lines.size())
            {
                if( des_row_offset > unsigned(m_FrameLines) )
                    des_row_offset -= m_FrameLines;
                else
                    des_row_offset = 0;
            }
            m_RowsOffset = des_row_offset;
            [m_View setNeedsDisplay];
        }
    }
    m_SmoothOffset.y = 0;
}

void BigFileViewHex::OnMouseDown(NSEvent *event)
{
    HandleSelectionWithMouseDragging(event);
}

void BigFileViewHex::HandleSelectionWithMouseDragging(NSEvent* event)
{
    bool modifying_existing_selection = ([event modifierFlags] & NSShiftKeyMask) ? true : false;
    NSPoint first_down = [m_View convertPoint:[event locationInWindow] fromView:nil];
    HitPart hit_part = PartHitTest(first_down);
    
    if(hit_part == HitPart::DataDump)
    {
        CFRange orig_sel = [m_View SelectionWithinWindow];        
        uint64_t window_size = m_Data->RawSize();
        int first_byte = std::clamp(ByteIndexFromHitTest(first_down), 0, (int)window_size);
        
        while ([event type]!=NSLeftMouseUp)
        {
            NSPoint loc = [m_View convertPoint:[event locationInWindow] fromView:nil];
            int curr_byte = std::clamp(ByteIndexFromHitTest(loc), 0, (int)window_size);

            int base_byte = first_byte;
            if(modifying_existing_selection && orig_sel.length > 0)
            {
                if(first_byte > orig_sel.location && first_byte <= orig_sel.location + orig_sel.length)
                    base_byte = first_byte - orig_sel.location > orig_sel.location + orig_sel.length - first_byte ?
                    (int)orig_sel.location : (int)orig_sel.location + (int)orig_sel.length;
                else if(first_byte < orig_sel.location + orig_sel.length && curr_byte < orig_sel.location + orig_sel.length)
                    base_byte = (int)orig_sel.location + (int)orig_sel.length;
                else if(first_byte > orig_sel.location && curr_byte > orig_sel.location)
                    base_byte = (int) orig_sel.location;
            }
            
            if(base_byte != curr_byte)
            {
                int sel_start = base_byte < curr_byte ? base_byte : curr_byte;
                int sel_end   = base_byte > curr_byte ? base_byte : curr_byte;
                m_View.selectionInFile = CFRangeMake(sel_start + m_Data->FilePos(), sel_end - sel_start);
            }
            else
                m_View.selectionInFile = CFRangeMake(-1,0);
            
            event = [[m_View window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        }
    }
    else if(hit_part == HitPart::Text)
    {
        CFRange orig_sel = [m_View SelectionWithinWindowUnichars];
        int first_char = std::clamp(CharIndexFromHitTest(first_down), 0, (int)m_Data->UniCharsSize());
        
        while ([event type]!=NSLeftMouseUp)
        {
            NSPoint loc = [m_View convertPoint:[event locationInWindow] fromView:nil];
            int curr_char = std::clamp(CharIndexFromHitTest(loc), 0, (int)m_Data->UniCharsSize());
            
            int base_char = first_char;
            if(modifying_existing_selection && orig_sel.length > 0)
            {
                if(first_char > orig_sel.location && first_char <= orig_sel.location + orig_sel.length)
                    base_char = first_char - orig_sel.location > orig_sel.location + orig_sel.length - first_char ?
                    (int)orig_sel.location : (int)orig_sel.location + (int)orig_sel.length;
                else if(first_char < orig_sel.location + orig_sel.length && curr_char < orig_sel.location + orig_sel.length)
                    base_char = (int)orig_sel.location + (int)orig_sel.length;
                else if(first_char > orig_sel.location && curr_char > orig_sel.location)
                    base_char = (int) orig_sel.location;
            }            
            
            if(base_char != curr_char)
            {
                int sel_start = base_char < curr_char ? base_char : curr_char;
                int sel_end   = base_char > curr_char ? base_char : curr_char;
                int sel_start_byte = sel_start < long(m_Data->UniCharsSize()) ?
                    m_Data->UniCharToByteIndeces()[sel_start] :
                    (int)m_Data->RawSize();
                int sel_end_byte = sel_end < long(m_Data->UniCharsSize()) ?
                    m_Data->UniCharToByteIndeces()[sel_end] :
                    (int)m_Data->RawSize();
                assert(sel_end_byte >= sel_start_byte);
                m_View.selectionInFile = CFRangeMake(sel_start_byte + m_Data->FilePos(), sel_end_byte - sel_start_byte);
            }
            else
                m_View.selectionInFile = CFRangeMake(-1,0);
            
            event = [[m_View window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        }
    }
}

void BigFileViewHex::OnScrollWheel(NSEvent *theEvent)
{
    double delta_y = [theEvent scrollingDeltaY];
    if(![theEvent hasPreciseScrollingDeltas])
        delta_y *= m_FontInfo.LineHeight();
    
    if((delta_y > 0 && (m_Data->FilePos() > 0 ||
                        m_RowsOffset > 0)       ) ||
        (delta_y < 0 && (m_Data->FilePos() + m_Data->RawSize() < m_Data->FileSize() ||
                            m_RowsOffset + m_FrameLines < m_Lines.size()) )
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
        [m_View setNeedsDisplay];
    }
    
    // edge-case clipping (not allowing to appear a gap before first line or after last line)
    if(m_Data->FilePos() == 0 &&
       m_RowsOffset == 0 &&
       m_SmoothOffset.y < 0)
        m_SmoothOffset.y = 0;
    if(m_Data->FilePos() + m_Data->RawSize() == m_Data->FileSize() &&
       m_RowsOffset + m_FrameLines >= m_Lines.size() &&
       m_SmoothOffset.y > 0 )
        m_SmoothOffset.y = 0;
}





