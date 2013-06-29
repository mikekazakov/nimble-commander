//
//  TextView.m
//  ViewerBase
//
//  Created by Michael G. Kazakov on 05.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <algorithm>
#import "BigFileView.h"
#import "BigFileViewText.h"
#import "BigFileViewHex.h"
#import "BigFileViewEncodingSelection.h"
#import "DataBlockAnalysis.h"
#import "Common.h"
#import "AppDelegate.h"

@implementation BigFileView
{
    FileWindow     *m_File;
    
    int             m_Encoding;
    
    // a file's window decoded into Unicode
    UniChar         *m_DecodeBuffer;
    // array indexing every m_DecodeBuffer unicode character into a byte offset within original file window
    uint32_t        *m_DecodeBufferIndx;
    size_t          m_DecodedBufferSize; // amount of unichars

    CTFontRef       m_Font;
    CGColorRef      m_ForegroundColor;
    DoubleColor     m_SelectionBkFillColor;
    DoubleColor     m_BackgroundFillColor;
        
    // layout
    bool            m_WrapWords;
    
    __strong id<BigFileViewProtocol>      m_ViewImpl;
    __strong id<BigFileViewDelegateProtocol> m_Delegate;
    
    NSScroller      *m_VerticalScroller;
    int             m_ColumnOffset;
    
    CFRange         m_SelectionInFile;  // in bytes, raw position within whole file
    CFRange         m_SelectionInWindow;         // in bytes, whithin current window positio
                                                 // updated when windows moves, regarding current selection in bytes
    CFRange         m_SelectionInWindowUnichars; // in UniChars, whithin current window position,
                                                 // updated when windows moves, regarding current selection in bytes
}

- (void)awakeFromNib
{
    [self DoInit];
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self DoInit];
        // Initialization code here.
    }
    
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    CFRelease(m_ForegroundColor);
    CFRelease(m_Font);
    if(m_DecodeBuffer != 0)
        free(m_DecodeBuffer);
    if(m_DecodeBufferIndx != 0)
        free(m_DecodeBufferIndx);
}

- (void) DoInit
{
    m_Encoding = ENCODING_UTF8;
    m_WrapWords = true;
    m_ColumnOffset = 0;
    m_SelectionInFile = CFRangeMake(-1, 0);
    m_SelectionInWindow = CFRangeMake(-1, 0);
    m_SelectionInWindowUnichars = CFRangeMake(-1, 0);

    if( [(AppDelegate*)[NSApp delegate] Skin] == ApplicationSkin::Modern)
        [self InitAppearanceForModernPresentation];
    else
        [self InitAppearanceForClassicPresentation];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(frameDidChange)
                                                 name:NSViewFrameDidChangeNotification
                                               object:self];
    
    m_VerticalScroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    [m_VerticalScroller setEnabled:YES];
    [m_VerticalScroller setTarget:self];
    [m_VerticalScroller setAction:@selector(VerticalScroll:)];
    [m_VerticalScroller setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:m_VerticalScroller];

    NSDictionary *views = NSDictionaryOfVariableBindings(m_VerticalScroller);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"[m_VerticalScroller(15)]-(==0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_VerticalScroller]-(==0)-|" options:0 metrics:nil views:views]];
    
    [self frameDidChange];
}

- (void) InitAppearanceForModernPresentation
{
    m_Font = CTFontCreateWithName(CFSTR("Menlo"), 12, NULL);
    m_ForegroundColor = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 1.0);
    m_SelectionBkFillColor = DoubleColor(180./255., 214./255., 252./255., 1.);
    m_BackgroundFillColor = DoubleColor(1., 1., 1., 1.);
}

- (void) InitAppearanceForClassicPresentation
{
    m_Font = CTFontCreateWithName(CFSTR("Menlo"), 14, NULL);
    m_ForegroundColor = CGColorCreateGenericRGB(0.0, 1.0, 1.0, 1.0);
    m_BackgroundFillColor = DoubleColor(0., 0., 0.5, 1.);    
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (BOOL)isOpaque
{
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext]
                                          graphicsPort];

    if(m_ViewImpl != nil)
        [m_ViewImpl DoDraw:context dirty:dirtyRect];

}

- (void) SetFile:(FileWindow*) _file
{
    StaticDataBlockAnalysis stat;
    DoStaticDataBlockAnalysis(_file->Window(), _file->WindowSize(), &stat);
    
    m_File = _file;
    if(m_DecodeBuffer != 0)
        free(m_DecodeBuffer);
    if(m_DecodeBufferIndx != 0)
        free(m_DecodeBufferIndx);
    
    m_DecodeBuffer = (UniChar*) malloc(sizeof(UniChar) * m_File->WindowSize());
    m_DecodeBufferIndx = (uint32_t*) malloc(sizeof(uint32_t) * m_File->WindowSize());

    if(stat.likely_utf16_le)        m_Encoding = ENCODING_UTF16LE;
    else if(stat.likely_utf16_be)   m_Encoding = ENCODING_UTF16BE;
    else if(stat.can_be_utf8)       m_Encoding = ENCODING_UTF8;
    else                            m_Encoding = ENCODING_MACOS_ROMAN_WESTERN;
    
    [self DecodeRawFileBuffer];    
    
    if(stat.is_binary)  m_ViewImpl = [BigFileViewHex alloc];
    else                m_ViewImpl = [BigFileViewText alloc];
    
    [m_ViewImpl InitWithWindow:m_DecodeBuffer
                       offsets:m_DecodeBufferIndx
                          size:m_DecodedBufferSize
                        parent:self];
}

- (void) DecodeRawFileBuffer
{
    assert(encodings::BytesForCodeUnit(m_Encoding) <= 2); // TODO: support for UTF-32 in the future
    bool odd = (encodings::BytesForCodeUnit(m_Encoding) == 2) && ((m_File->WindowPos() & 1) == 1);    
    encodings::InterpretAsUnichar(m_Encoding,
                                  (unsigned char*)m_File->Window() + (odd ? 1 : 0),
                                  m_File->WindowSize() - (odd ? 1 : 0),
                                  m_DecodeBuffer,
                                  m_DecodeBufferIndx,
                                  &m_DecodedBufferSize);
    
    [self UpdateSelectionRange];
    
    if(m_ViewImpl)
        [m_ViewImpl OnBufferDecoded:m_DecodedBufferSize];
}

- (void)keyDown:(NSEvent *)event
{
    NSString*  const character = [event charactersIgnoringModifiers];
    if ( [character length] != 1 ) return;
    unichar const unicode        = [character characterAtIndex:0];
    unsigned short const keycode = [event keyCode];
//    NSUInteger const modif       = [event modifierFlags];

    uint64_t was_vert_pos = [self VerticalPositionInBytes];
    
#define ISMODIFIER(_v) ( (modif&NSDeviceIndependentModifierFlagsMask) == (_v) )
    switch (unicode)
    {
        case NSUpArrowFunctionKey:
            [m_ViewImpl OnUpArrow];
            break;
        case NSDownArrowFunctionKey:
            [m_ViewImpl OnDownArrow];
            break;
        case NSPageDownFunctionKey:
            [m_ViewImpl OnPageDown];
            break;
        case NSPageUpFunctionKey:
            [m_ViewImpl OnPageUp];
            break;
        case NSLeftArrowFunctionKey:
            if([m_ViewImpl respondsToSelector:@selector(OnLeftArrow)])
                [m_ViewImpl OnLeftArrow];
            break;
        case NSRightArrowFunctionKey:
            if([m_ViewImpl respondsToSelector:@selector(OnRightArrow)])
                [m_ViewImpl OnRightArrow];
            break;
        default:
            [super keyDown:event];
    }
#undef ISMODIFIER
    if(was_vert_pos != [self VerticalPositionInBytes])
        [m_Delegate BigFileViewScrolledByUser];
}

- (void) SetEncoding
{
    BigFileViewEncodingSelection *wnd = [BigFileViewEncodingSelection new];
    [wnd SetCurrentEncoding:m_Encoding];
    int ret = (int)[NSApp runModalForWindow: [wnd window]];
    [NSApp endSheet: [wnd window]];
    [[wnd window] orderOut: self];
    
    if(ret != ENCODING_INVALID)
    {
        [self SetEncoding:ret];
    }
}

- (int) Enconding
{
    return m_Encoding;
}

- (void) SetEncoding:(int)_encoding
{
    if(_encoding != m_Encoding && _encoding != ENCODING_INVALID)
    {
        m_Encoding = _encoding;
        [self DecodeRawFileBuffer];
    }
}

- (void)frameDidChange
{
    [m_ViewImpl OnFrameChanged];
}

- (CTFontRef) TextFont{
    return m_Font;
}

- (CGColorRef) TextForegroundColor{
    return m_ForegroundColor;
}

- (DoubleColor) SelectionBkFillColor{
    return m_SelectionBkFillColor;
}

- (DoubleColor) BackgroundFillColor{
    return m_BackgroundFillColor;
}

- (const void*) RawWindow
{
    return m_File->Window();
}

- (uint64_t) RawWindowPosition
{
    return m_File->WindowPos();
}

- (uint64_t) RawWindowSize
{
    return m_File->WindowSize();
}

- (uint64_t) FullSize
{
    return m_File->FileSize();
}

- (void) RequestWindowMovementAt: (uint64_t) _pos
{
    m_File->MoveWindow(_pos);
    
    [self DecodeRawFileBuffer];
}

- (void) DoClose
{    
    [self removeFromSuperview];

    m_ViewImpl = nil;
}

- (void) UpdateVerticalScroll: (double) _pos prop:(double)prop
{
    [m_VerticalScroller setKnobProportion:prop];
    [m_VerticalScroller setDoubleValue:_pos];

    [m_Delegate BigFileViewScrolled];
}

- (void)VerticalScroll:(id)sender
{
    uint64_t was_vert_pos = [self VerticalPositionInBytes];
    switch ([m_VerticalScroller hitPart])
    {
        case NSScrollerIncrementLine:
            [m_ViewImpl OnDownArrow];
            break;
        case NSScrollerIncrementPage:
            // Include code here for the case where CTRL + down arrow is pressed, or the space the scroll knob moves in is pressed
            [m_ViewImpl OnPageDown];
            break;
        case NSScrollerDecrementLine:
            // Include code here for the case where the up arrow is pressed
            [m_ViewImpl OnUpArrow];            
            break;
        case NSScrollerDecrementPage:
            // Include code here for the case where CTRL + up arrow is pressed, or the space the scroll knob moves in is pressed
            [m_ViewImpl OnPageUp];
            break;
        case NSScrollerKnob:
            // This case is when the knob itself is pressed
                [m_ViewImpl HandleVerticalScroll:[m_VerticalScroller doubleValue]];
            break;
        default:
            break;
    }
    if(was_vert_pos != [self VerticalPositionInBytes])
        [m_Delegate BigFileViewScrolledByUser];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    uint64_t was_vert_pos = [self VerticalPositionInBytes];    
    int idy = int([theEvent deltaY]); // TODO: temporary implementation
    if(idy < 0) [m_ViewImpl OnDownArrow];
    else if(idy > 0) [m_ViewImpl OnUpArrow];
    
    int idx = int([theEvent deltaX]);
    if(idx < 0)
        if([m_ViewImpl respondsToSelector:@selector(OnRightArrow)])
            [m_ViewImpl OnRightArrow];
    
    if(idx > 0)
        if([m_ViewImpl respondsToSelector:@selector(OnLeftArrow)])
            [m_ViewImpl OnLeftArrow];
    
    if(was_vert_pos != [self VerticalPositionInBytes])
        [m_Delegate BigFileViewScrolledByUser];
}

- (bool)WordWrap
{
    return m_WrapWords;
}

- (void)SetWordWrap:(bool)_wrapping
{
    if(m_WrapWords != _wrapping)
    {
        m_WrapWords = _wrapping;
        [self SetColumnOffset:0];
        if([m_ViewImpl respondsToSelector:@selector(OnWordWrappingChanged)])
            [m_ViewImpl OnWordWrappingChanged];
    }
}

- (BigFileViewModes) Mode
{
    if( [m_ViewImpl isKindOfClass: [BigFileViewText class]])
        return BigFileViewModes::Text;
    else if( [m_ViewImpl isKindOfClass: [BigFileViewHex class]])
        return BigFileViewModes::Hex;
    else
        assert(0);
}

- (void) SetMode: (BigFileViewModes) _mode
{
    if(_mode == [self Mode])
        return;
    
    uint32_t off = [m_ViewImpl GetOffsetWithinWindow];    
    
    switch (_mode)
    {
        case BigFileViewModes::Text:
            m_ViewImpl = [BigFileViewText alloc];
            break;
        case BigFileViewModes::Hex:
            m_ViewImpl = [BigFileViewHex alloc];
            break;
        default:
            assert(0);
    }

    [m_ViewImpl InitWithWindow:m_DecodeBuffer
                       offsets:m_DecodeBufferIndx
                          size:m_DecodedBufferSize
                        parent:self];

    [m_ViewImpl MoveOffsetWithinWindow:off];
}

- (void) SetDelegate:(id<BigFileViewDelegateProtocol>) _delegate
{
    m_Delegate = _delegate;
}

- (double) VerticalScrollPosition
{
    return  [m_VerticalScroller doubleValue];
}


- (void) SetSelectionInFile: (CFRange) _selection
{
    if(_selection.location == m_SelectionInFile.location &&
       _selection.length   == m_SelectionInFile.length)
        return;
    
    if(_selection.location < 0)
    {
        m_SelectionInFile = CFRangeMake(-1, 0);
        m_SelectionInWindow = CFRangeMake(-1, 0);
        m_SelectionInWindowUnichars = CFRangeMake(-1, 0);
    }
    else
    {
        assert(_selection.location + _selection.length <= m_File->FileSize());
        m_SelectionInFile = _selection;
        [self UpdateSelectionRange];
    }
    [self setNeedsDisplay:true];
}

- (void) ScrollToSelection
{
    if(m_SelectionInFile.location >= 0)
    {
        [m_ViewImpl ScrollToByteOffset:m_SelectionInFile.location];
        [self UpdateSelectionRange];
    }
}

- (uint64_t) VerticalPositionInBytes
{
    return uint64_t([m_ViewImpl GetOffsetWithinWindow]) + m_File->WindowPos();
}

- (void) SetVerticalPositionInBytes:(uint64_t) _pos
{
    [m_ViewImpl ScrollToByteOffset:_pos];    
}

// searching for selected UniChars in file window if there's any overlapping of
// selected bytes in file on current window position
// this method should be called on any file window movement
- (void) UpdateSelectionRange
{
    if(m_SelectionInFile.location < 0 || m_SelectionInFile.length < 1)
    {
        m_SelectionInWindow = CFRangeMake(-1, 0);        
        m_SelectionInWindowUnichars = CFRangeMake(-1, 0);
        return;
    }
    
    uint64_t window_pos = m_File->WindowPos();
    uint64_t window_size = m_File->WindowSize();
    
    uint64_t start = m_SelectionInFile.location;
    uint64_t end   = start + m_SelectionInFile.length;
    
    if(end > window_pos + window_size)
        end = window_pos + window_size;
    if(start < window_pos)
        start = window_pos;
    
    if(start >= end)
    {
        m_SelectionInWindow = CFRangeMake(-1, 0);        
        m_SelectionInWindowUnichars = CFRangeMake(-1, 0);
        return;
    }
    
    const uint32_t *offset = std::lower_bound(m_DecodeBufferIndx,
                                              m_DecodeBufferIndx+m_DecodedBufferSize,
                                              start - window_pos);
    assert(offset < m_DecodeBufferIndx+m_DecodedBufferSize);
    
    const uint32_t *tail = std::lower_bound(m_DecodeBufferIndx,
                                            m_DecodeBufferIndx+m_DecodedBufferSize,
                                            end - window_pos);
    assert(tail <= m_DecodeBufferIndx+m_DecodedBufferSize);
    
    int startindex = int(offset - m_DecodeBufferIndx);
    int endindex   = int(tail - m_DecodeBufferIndx);
    assert(startindex >= 0 && startindex < m_DecodedBufferSize);
    assert(endindex >= 0 && endindex <= m_DecodedBufferSize);
    
    m_SelectionInWindow = CFRangeMake(start - window_pos, end - start);
    m_SelectionInWindowUnichars = CFRangeMake(startindex, endindex - startindex);
}

- (CFRange) SelectionWithinWindowUnichars {
    return m_SelectionInWindowUnichars;
}

- (CFRange) SelectionWithinWindow {
    return m_SelectionInWindow;
}

- (CFRange) SelectionWithinFile {
    return m_SelectionInFile;
}

- (int) ColumnOffset {
    return m_ColumnOffset;
}

- (void) SetColumnOffset:(int)_offset
{
    if(m_ColumnOffset != _offset)
    {
        m_ColumnOffset = _offset;
        [self setNeedsDisplay:true];
    }
}

- (void) mouseDown:(NSEvent *)_event
{
    if([m_ViewImpl respondsToSelector:@selector(OnMouseDown:)])
        [m_ViewImpl OnMouseDown:_event];
}

 - (void)copy:(id)sender
{
    if(m_SelectionInWindow.location >= 0 && m_SelectionInWindow.length > 0)
    {
        NSString *str = [[NSString alloc] initWithCharactersNoCopy:m_DecodeBuffer + m_SelectionInWindowUnichars.location
                                                            length:m_SelectionInWindowUnichars.length
                                                      freeWhenDone:false];
        NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
        [pasteBoard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
        [pasteBoard setString:str forType:NSStringPboardType];
    }
}

- (void)selectAll:(id)sender
{
    [self SetSelectionInFile: CFRangeMake(0, m_File->FileSize())];
}

- (void)deselectAll:(id)sender
{
    [self SetSelectionInFile: CFRangeMake(-1, 0)];
}

@end
