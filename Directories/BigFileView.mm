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
#import "BigFileViewDataBackend.h"

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
    std::shared_ptr<BigFileViewDataBackend> m_Data;

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
}

- (void) DoInit
{
    m_WrapWords = true;
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
    m_ForegroundColor = [[defaults colorForKey:@"BigFileViewModernTextColor"] SafeCGColorRef];
    m_SelectionBkFillColor = DoubleColor([defaults colorForKey:@"BigFileViewModernSelectionColor"]);
    m_BackgroundFillColor = DoubleColor([defaults colorForKey:@"BigFileViewModernBackgroundColor"]);
    m_ShouldSmoothFonts = [defaults boolForKey:@"BigFileViewModernShouldSmoothFonts"];
    m_ShouldAntialias = [defaults boolForKey:@"BigFileViewModernShouldAntialias"];
}

- (void) InitAppearanceForClassicPresentation
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    m_Font = (CTFontRef) CFBridgingRetain([defaults fontForKey:@"BigFileViewClassicFont"]);
    m_ForegroundColor = [[defaults colorForKey:@"BigFileViewClassicTextColor"] SafeCGColorRef];
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
            m_ForegroundColor = [[defaults colorForKey:@"BigFileViewModernTextColor"] SafeCGColorRef];
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
            m_ForegroundColor = [[defaults colorForKey:@"BigFileViewClassicTextColor"] SafeCGColorRef];
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
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    [m_ViewImpl DoDraw:context dirty:dirtyRect]; // m_ViewImpl can be nil
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
    m_Data = std::make_shared<BigFileViewDataBackend>(m_File, _encoding);
    BigFileView* __weak weak_self = self;
    m_Data->SetOnDecoded(^{
        if(weak_self) {
            BigFileView *__strong strong_self = weak_self;
            [strong_self UpdateSelectionRange];
            if(strong_self->m_ViewImpl)
                [strong_self->m_ViewImpl OnBufferDecoded];
        }
    });
    
    m_ViewImpl = _mode == BigFileViewModes::Hex ? [BigFileViewHex alloc] : [BigFileViewText alloc];    
    [m_ViewImpl InitWithData:m_Data.get() parent:self];
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
    if(m_Data.get()) return m_Data->Encoding();
    return ENCODING_UTF8; // ??
}

- (void) SetEncoding:(int)_encoding
{
    m_Data->SetEncoding(_encoding);
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

- (void) RequestWindowMovementAt: (uint64_t) _pos
{
    m_Data->MoveWindowSync(_pos);
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
    [m_ViewImpl OnScrollWheel:theEvent];
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
    
    uint32_t current_offset = [m_ViewImpl GetOffsetWithinWindow];
    
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

    [m_ViewImpl InitWithData:m_Data.get() parent:self];
    [m_ViewImpl MoveOffsetWithinWindow:current_offset];
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
    
    const uint32_t *offset = std::lower_bound(m_Data->UniCharToByteIndeces(),
                                              m_Data->UniCharToByteIndeces() + m_Data->UniCharsSize(),
                                              start - window_pos);
    assert(offset < m_Data->UniCharToByteIndeces() + m_Data->UniCharsSize());
    
    const uint32_t *tail = std::lower_bound(m_Data->UniCharToByteIndeces(),
                                            m_Data->UniCharToByteIndeces() + m_Data->UniCharsSize(),
                                            end - window_pos);
    assert(tail <= m_Data->UniCharToByteIndeces() + m_Data->UniCharsSize());
    
    int startindex = int(offset - m_Data->UniCharToByteIndeces());
    int endindex   = int(tail - m_Data->UniCharToByteIndeces());
    assert(startindex >= 0 && startindex < m_Data->UniCharsSize());
    assert(endindex >= 0 && endindex <= m_Data->UniCharsSize());
    
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

- (void) mouseDown:(NSEvent *)_event
{
    if([m_ViewImpl respondsToSelector:@selector(OnMouseDown:)])
        [m_ViewImpl OnMouseDown:_event];
}

 - (void)copy:(id)sender
{
    if(m_SelectionInWindow.location >= 0 && m_SelectionInWindow.length > 0)
    {
        NSString *str = [[NSString alloc] initWithCharactersNoCopy:m_Data->UniChars() + m_SelectionInWindowUnichars.location
                                                            length:m_SelectionInWindowUnichars.length
                                                      freeWhenDone:false];
        NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
        [pasteBoard clearContents];
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
