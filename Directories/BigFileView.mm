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
#import "DataBlockAnalysis.h"
#import "Common.h"
#import "AppDelegate.h"
#import "NSUserDefaults+myColorSupport.h"

CGColorRef CGColorFromNSColor(NSColor *_c)
{
    const NSInteger numberOfComponents = [_c numberOfComponents];
    CGFloat components[numberOfComponents];
    CGColorSpaceRef colorSpace = [[_c colorSpace] CGColorSpace];
    
    [_c getComponents:(CGFloat *)&components];
    
    return CGColorCreate(colorSpace, components);
}

static NSArray *MyDefaultsKeys()
{
    return [NSArray arrayWithObjects:@"BigFileViewModernShouldSmoothFonts", @"BigFileViewModernShouldAntialias",
 @"BigFileViewModernBackgroundColor", @"BigFileViewModernSelectionColor", @"BigFileViewModernTextColor",
 @"BigFileViewModernFont", @"BigFileViewClassicShouldSmoothFonts", @"BigFileViewClassicShouldAntialias",
 @"BigFileViewClassicBackgroundColor", @"BigFileViewClassicSelectionColor", @"BigFileViewClassicTextColor",
 @"BigFileViewClassicFont", nil];
}

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
    bool            m_ShouldAntialias;
    bool            m_ShouldSmoothFonts;
        
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
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPaths:MyDefaultsKeys()];
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
    
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPaths:MyDefaultsKeys() options:0 context:0];
}

- (void) InitAppearanceForModernPresentation
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];    
    m_Font = (CTFontRef) CFBridgingRetain([defaults fontForKey:@"BigFileViewModernFont"]);
    m_ForegroundColor = CGColorFromNSColor([defaults colorForKey:@"BigFileViewModernTextColor"]);
    m_SelectionBkFillColor = DoubleColor([defaults colorForKey:@"BigFileViewModernSelectionColor"]);
    m_BackgroundFillColor = DoubleColor([defaults colorForKey:@"BigFileViewModernBackgroundColor"]);
    m_ShouldSmoothFonts = [defaults boolForKey:@"BigFileViewModernShouldSmoothFonts"];
    m_ShouldAntialias = [defaults boolForKey:@"BigFileViewModernShouldAntialias"];
}

- (void) InitAppearanceForClassicPresentation
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    m_Font = (CTFontRef) CFBridgingRetain([defaults fontForKey:@"BigFileViewClassicFont"]);
    m_ForegroundColor = CGColorFromNSColor([defaults colorForKey:@"BigFileViewClassicTextColor"]);
    m_SelectionBkFillColor = DoubleColor([defaults colorForKey:@"BigFileViewClassicSelectionColor"]);
    m_BackgroundFillColor = DoubleColor([defaults colorForKey:@"BigFileViewClassicBackgroundColor"]);
    m_ShouldSmoothFonts = [defaults boolForKey:@"BigFileViewClassicShouldSmoothFonts"];
    m_ShouldAntialias = [defaults boolForKey:@"BigFileViewClassicShouldAntialias"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];    
    auto skin = [(AppDelegate*)[NSApp delegate] Skin];

    if(skin == ApplicationSkin::Modern) {
        if([keyPath isEqualToString:@"BigFileViewModernBackgroundColor"])
            m_BackgroundFillColor = DoubleColor([defaults colorForKey:@"BigFileViewModernBackgroundColor"]);
        else if([keyPath isEqualToString:@"BigFileViewModernShouldSmoothFonts"])
            m_ShouldSmoothFonts = [defaults boolForKey:@"BigFileViewModernShouldSmoothFonts"];
        else if([keyPath isEqualToString:@"BigFileViewModernShouldAntialias"])
            m_ShouldAntialias = [defaults boolForKey:@"BigFileViewModernShouldAntialias"];
        else if([keyPath isEqualToString:@"BigFileViewModernSelectionColor"])
            m_SelectionBkFillColor = DoubleColor([defaults colorForKey:@"BigFileViewModernSelectionColor"]);
        else if([keyPath isEqualToString:@"BigFileViewModernTextColor"]) {
            CFRelease(m_ForegroundColor);
            m_ForegroundColor = CGColorFromNSColor([defaults colorForKey:@"BigFileViewModernTextColor"]);
            [m_ViewImpl OnFontSettingsChanged];
        }
        else if([keyPath isEqualToString:@"BigFileViewModernFont"]) {
            CFRelease(m_Font);
            m_Font = (CTFontRef) CFBridgingRetain([defaults fontForKey:@"BigFileViewModernFont"]);
            [m_ViewImpl OnFontSettingsChanged];
        }
    }
    else if(skin == ApplicationSkin::Classic) {
        if([keyPath isEqualToString:@"BigFileViewClassicBackgroundColor"])
            m_BackgroundFillColor = DoubleColor([defaults colorForKey:@"BigFileViewClassicBackgroundColor"]);
        else if([keyPath isEqualToString:@"BigFileViewClassicShouldSmoothFonts"])
            m_ShouldSmoothFonts = [defaults boolForKey:@"BigFileViewClassicShouldSmoothFonts"];
        else if([keyPath isEqualToString:@"BigFileViewClassicShouldAntialias"])
            m_ShouldAntialias = [defaults boolForKey:@"BigFileViewClassicShouldAntialias"];
        else if([keyPath isEqualToString:@"BigFileViewClassicSelectionColor"])
            m_SelectionBkFillColor = DoubleColor([defaults colorForKey:@"BigFileViewClassicSelectionColor"]);
        else if([keyPath isEqualToString:@"BigFileViewClassicTextColor"]) {
            CFRelease(m_ForegroundColor);
            m_ForegroundColor = CGColorFromNSColor([defaults colorForKey:@"BigFileViewClassicTextColor"]);
            [m_ViewImpl OnFontSettingsChanged];
        }
        else if([keyPath isEqualToString:@"BigFileViewClassicFont"]) {
            CFRelease(m_Font);
            m_Font = (CTFontRef) CFBridgingRetain([defaults fontForKey:@"BigFileViewClassicFont"]);
            [m_ViewImpl OnFontSettingsChanged];
        }
    }
    
    [self setNeedsDisplay:true];
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
    int encoding = encodings::EncodingFromName(
        [[[NSUserDefaults standardUserDefaults] stringForKey:@"BigFileViewDefaultEncoding"] UTF8String]);
    if(encoding == ENCODING_INVALID)
        encoding = ENCODING_MACOS_ROMAN_WESTERN; // this should not happen, but just to be sure

    StaticDataBlockAnalysis stat;
    DoStaticDataBlockAnalysis(_file->Window(), _file->WindowSize(), &stat);
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"BigFileViewEncodingAutoDetect"])
    {
        if(stat.likely_utf16_le)        encoding = ENCODING_UTF16LE;
        else if(stat.likely_utf16_be)   encoding = ENCODING_UTF16BE;
        else if(stat.can_be_utf8)       encoding = ENCODING_UTF8;
    }
    
    BigFileViewModes mode = stat.is_binary ? BigFileViewModes::Hex : BigFileViewModes::Text;
    
    [self SetKnownFile:_file encoding:encoding mode:mode];
}

- (void) SetKnownFile:(FileWindow*) _file encoding:(int)_encoding mode:(BigFileViewModes)_mode
{
    assert(_encoding != ENCODING_INVALID);
    
    m_File = _file;
    if(m_DecodeBuffer != 0)
        free(m_DecodeBuffer);
    if(m_DecodeBufferIndx != 0)
        free(m_DecodeBufferIndx);
    
    m_DecodeBuffer = (UniChar*) malloc(sizeof(UniChar) * m_File->WindowSize());
    m_DecodeBufferIndx = (uint32_t*) malloc(sizeof(uint32_t) * m_File->WindowSize());

    m_Encoding = _encoding;
    [self DecodeRawFileBuffer];    
    
    m_ViewImpl = _mode == BigFileViewModes::Hex ? [BigFileViewHex alloc] : [BigFileViewText alloc];    
    [m_ViewImpl InitWithWindow:m_DecodeBuffer offsets:m_DecodeBufferIndx size:m_DecodedBufferSize parent:self];
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
    if([[event charactersIgnoringModifiers] length] != 1) return;
    uint64_t was_vert_pos = [self VerticalPositionInBytes];
    switch ([[event charactersIgnoringModifiers] characterAtIndex:0]) {
        case NSHomeFunctionKey: [m_ViewImpl HandleVerticalScroll:0.0]; break;
        case NSEndFunctionKey:  [m_ViewImpl HandleVerticalScroll:1.0]; break;
        default: [super keyDown:event]; return;
    }
    if(was_vert_pos != [self VerticalPositionInBytes])
        [m_Delegate BigFileViewScrolledByUser];
}

- (void)moveUp:(id)sender{
    uint64_t was_vert_pos = [self VerticalPositionInBytes];
    [m_ViewImpl OnUpArrow];
    if(was_vert_pos != [self VerticalPositionInBytes]) [m_Delegate BigFileViewScrolledByUser];
}

- (void)moveDown:(id)sender {
    uint64_t was_vert_pos = [self VerticalPositionInBytes];
    [m_ViewImpl OnDownArrow];
    if(was_vert_pos != [self VerticalPositionInBytes]) [m_Delegate BigFileViewScrolledByUser];
}

- (void)moveLeft:(id)sender {
    uint64_t was_vert_pos = [self VerticalPositionInBytes];
    if([m_ViewImpl respondsToSelector:@selector(OnLeftArrow)]) [m_ViewImpl OnLeftArrow];
    if(was_vert_pos != [self VerticalPositionInBytes]) [m_Delegate BigFileViewScrolledByUser];
}

- (void)moveRight:(id)sender {
    uint64_t was_vert_pos = [self VerticalPositionInBytes];
    if([m_ViewImpl respondsToSelector:@selector(OnRightArrow)]) [m_ViewImpl OnRightArrow];
    if(was_vert_pos != [self VerticalPositionInBytes]) [m_Delegate BigFileViewScrolledByUser];
}

- (void)pageDown:(id)sender {
    uint64_t was_vert_pos = [self VerticalPositionInBytes];    
    [m_ViewImpl OnPageDown];
    if(was_vert_pos != [self VerticalPositionInBytes]) [m_Delegate BigFileViewScrolledByUser];
}

- (void) pageUp:(id)sender {
    uint64_t was_vert_pos = [self VerticalPositionInBytes];
    [m_ViewImpl OnPageUp];
    if(was_vert_pos != [self VerticalPositionInBytes]) [m_Delegate BigFileViewScrolledByUser];
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

- (bool) ShouldAntialias {
    return m_ShouldAntialias;
}

- (bool) ShouldSmoothFonts {
    return m_ShouldSmoothFonts;
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

- (CFRange) SelectionInFile {
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
