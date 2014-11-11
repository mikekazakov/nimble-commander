//
//  TextView.m
//  ViewerBase
//
//  Created by Michael G. Kazakov on 05.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

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

const static double g_BorderWidth = 1.0;

@implementation BigFileView
{
    FileWindow     *m_File;
    unique_ptr<BigFileViewDataBackend> m_Data;

    CTFontRef       m_Font;
    CGColorRef      m_ForegroundColor;
    DoubleColor     m_SelectionBkFillColor;
    DoubleColor     m_BackgroundFillColor;
    bool            m_ShouldAntialias;
    bool            m_ShouldSmoothFonts;
        
    // layout
    bool            m_WrapWords;
    
    unique_ptr<BigFileViewImpl> m_ViewImpl;
    __weak  id<BigFileViewDelegateProtocol> m_Delegate;
    
    NSScroller      *m_VerticalScroller;
    CFRange         m_SelectionInFile;  // in bytes, raw position within whole file
    CFRange         m_SelectionInWindow;         // in bytes, whithin current window positio
                                                 // updated when windows moves, regarding current selection in bytes
    CFRange         m_SelectionInWindowUnichars; // in UniChars, whithin current window position,
                                                 // updated when windows moves, regarding current selection in bytes
}

@synthesize delegate = m_Delegate;

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.hasBorder = false;
        m_WrapWords = true;
        m_SelectionInFile = CFRangeMake(-1, 0);
        m_SelectionInWindow = CFRangeMake(-1, 0);
        m_SelectionInWindowUnichars = CFRangeMake(-1, 0);
        m_ViewImpl = make_unique<BigFileViewImpl>(); // dummy for initialization process
        
        if( [(AppDelegate*)NSApplication.sharedApplication.delegate skin] == ApplicationSkin::Modern)
            [self InitAppearanceForModernPresentation];
        else
            [self InitAppearanceForClassicPresentation];
        
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(frameDidChange)
                                                   name:NSViewFrameDidChangeNotification
                                                 object:self];
        
        m_VerticalScroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
        m_VerticalScroller.enabled = true;
        m_VerticalScroller.target = self;
        m_VerticalScroller.action = @selector(VerticalScroll:);
        m_VerticalScroller.translatesAutoresizingMaskIntoConstraints = false;
        [self addSubview:m_VerticalScroller];
        [self layoutVerticalScroll];
        [self frameDidChange];
        
        [NSUserDefaults.standardUserDefaults addObserver:self forKeyPaths:MyDefaultsKeys() options:0 context:0];
    }
    
    return self;
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPaths:MyDefaultsKeys()];
    CFRelease(m_ForegroundColor);
    CFRelease(m_Font);
}

- (void)layoutVerticalScroll
{
    for(NSLayoutConstraint *c in self.constraints)
        if(c.firstItem == m_VerticalScroller || c.secondItem == m_VerticalScroller)
            [self removeConstraint:c];
    
    double off = self.hasBorder ? g_BorderWidth : 0;
    NSDictionary *views = NSDictionaryOfVariableBindings(m_VerticalScroller);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"[m_VerticalScroller(15)]-(==%f)-|",off]
                                                                 options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|-(==%f)-[m_VerticalScroller]-(==%f)-|",off,off]
                                                                 options:0 metrics:nil views:views]];
}

- (void) InitAppearanceForModernPresentation
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];    
    m_Font = (CTFontRef) CFBridgingRetain([defaults fontForKey:@"BigFileViewModernFont"]);
    m_ForegroundColor = [defaults colorForKey:@"BigFileViewModernTextColor"].copyCGColorRefSafe;
    m_SelectionBkFillColor = DoubleColor([defaults colorForKey:@"BigFileViewModernSelectionColor"]);
    m_BackgroundFillColor = DoubleColor([defaults colorForKey:@"BigFileViewModernBackgroundColor"]);
    m_ShouldSmoothFonts = [defaults boolForKey:@"BigFileViewModernShouldSmoothFonts"];
    m_ShouldAntialias = [defaults boolForKey:@"BigFileViewModernShouldAntialias"];
}

- (void) InitAppearanceForClassicPresentation
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    m_Font = (CTFontRef) CFBridgingRetain([defaults fontForKey:@"BigFileViewClassicFont"]);
    m_ForegroundColor = [defaults colorForKey:@"BigFileViewClassicTextColor"].copyCGColorRefSafe;
    m_SelectionBkFillColor = DoubleColor([defaults colorForKey:@"BigFileViewClassicSelectionColor"]);
    m_BackgroundFillColor = DoubleColor([defaults colorForKey:@"BigFileViewClassicBackgroundColor"]);
    m_ShouldSmoothFonts = [defaults boolForKey:@"BigFileViewClassicShouldSmoothFonts"];
    m_ShouldAntialias = [defaults boolForKey:@"BigFileViewClassicShouldAntialias"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    auto skin = [(AppDelegate*)NSApplication.sharedApplication.delegate skin];

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
            m_ForegroundColor = [defaults colorForKey:@"BigFileViewModernTextColor"].copyCGColorRefSafe;
            m_ViewImpl->OnFontSettingsChanged();
        }
        else if([keyPath isEqualToString:@"BigFileViewModernFont"]) {
            CFRelease(m_Font);
            m_Font = (CTFontRef) CFBridgingRetain([defaults fontForKey:@"BigFileViewModernFont"]);
            m_ViewImpl->OnFontSettingsChanged();
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
            m_ForegroundColor = [defaults colorForKey:@"BigFileViewClassicTextColor"].copyCGColorRefSafe;
            m_ViewImpl->OnFontSettingsChanged();
        }
        else if([keyPath isEqualToString:@"BigFileViewClassicFont"]) {
            CFRelease(m_Font);
            m_Font = (CTFontRef) CFBridgingRetain([defaults fontForKey:@"BigFileViewClassicFont"]);
            m_ViewImpl->OnFontSettingsChanged();
        }
    }
    
    [self setNeedsDisplay];
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
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    CGContextSaveGState(context);
    if(self.hasBorder)
        CGContextTranslateCTM(context, g_BorderWidth, g_BorderWidth);
    
    m_ViewImpl->DoDraw(context, dirtyRect);
    
    if(self.hasBorder) {
        CGContextTranslateCTM(context, -g_BorderWidth, -g_BorderWidth);
        NSRect rc = NSMakeRect(0, 0, self.bounds.size.width - g_BorderWidth, self.bounds.size.height - g_BorderWidth);
        CGContextSetAllowsAntialiasing(context, false);
        NSBezierPath *bp = [NSBezierPath bezierPathWithRect:rc];
        bp.lineWidth = g_BorderWidth;
        [[NSColor colorWithCalibratedWhite:184./255 alpha:1.0] set];
        [bp stroke];
        CGContextSetAllowsAntialiasing(context, true);
    }
    CGContextRestoreGState(context);
}

- (void)drawFocusRingMask
{
    NSRectFill(self.focusRingMaskBounds);
}

- (NSRect)focusRingMaskBounds
{
    return self.bounds;
}

- (void)resetCursorRects
{
    [self addCursorRect:self.frame cursor:NSCursor.IBeamCursor];
}

- (void) SetFile:(FileWindow*) _file
{
    int encoding = encodings::EncodingFromName(
        [NSUserDefaults.standardUserDefaults stringForKey:@"BigFileViewDefaultEncoding"].UTF8String);
    if(encoding == encodings::ENCODING_INVALID)
        encoding = encodings::ENCODING_MACOS_ROMAN_WESTERN; // this should not happen, but just to be sure

    StaticDataBlockAnalysis stat;
    DoStaticDataBlockAnalysis(_file->Window(), _file->WindowSize(), &stat);
    if([NSUserDefaults.standardUserDefaults boolForKey:@"BigFileViewEncodingAutoDetect"])
    {
        if(stat.likely_utf16_le)        encoding = encodings::ENCODING_UTF16LE;
        else if(stat.likely_utf16_be)   encoding = encodings::ENCODING_UTF16BE;
        else if(stat.can_be_utf8)       encoding = encodings::ENCODING_UTF8;
    }
    
    BigFileViewModes mode = stat.is_binary ? BigFileViewModes::Hex : BigFileViewModes::Text;
    
    [self SetKnownFile:_file encoding:encoding mode:mode];
}

- (void) SetKnownFile:(FileWindow*) _file encoding:(int)_encoding mode:(BigFileViewModes)_mode
{
    assert(_encoding != encodings::ENCODING_INVALID);
    
    m_File = _file;
    m_Data = make_unique<BigFileViewDataBackend>(m_File, _encoding);
    BigFileView* __weak weak_self = self;
    m_Data->SetOnDecoded(^{
        if(BigFileView *sself = weak_self) {
            [sself UpdateSelectionRange];
            sself->m_ViewImpl->OnBufferDecoded();
        }
    });
    
//    m_ViewImpl = _mode == BigFileViewModes::Hex ? [BigFileViewHex alloc] : [BigFileViewText alloc];
//    [m_ViewImpl InitWithData:m_Data.get() parent:self];
//    m_ViewImpl = _mode == BigFileViewModes::Hex ?
//        make_unique<BigFileViewHex>(m_Data.get(), self) :
//        make_unique<BigFileViewText>(m_Data.get(), self);
    if(_mode == BigFileViewModes::Hex)
        m_ViewImpl = make_unique<BigFileViewHex>(m_Data.get(), self);
    else if(_mode == BigFileViewModes::Text)
        m_ViewImpl = make_unique<BigFileViewText>(m_Data.get(), self);
}

- (void)keyDown:(NSEvent *)event
{
    if([[event charactersIgnoringModifiers] length] != 1) return;
    uint64_t was_vert_pos = self.verticalPositionInBytes;
    switch ([[event charactersIgnoringModifiers] characterAtIndex:0]) {
        case NSHomeFunctionKey: m_ViewImpl->HandleVerticalScroll(0.0); break;
        case NSEndFunctionKey:  m_ViewImpl->HandleVerticalScroll(1.0); break;
        default: [super keyDown:event]; return;
    }
    if(was_vert_pos != self.verticalPositionInBytes)
        [(id<BigFileViewDelegateProtocol>)m_Delegate BigFileViewScrolledByUser];
}

- (void)moveUp:(id)sender{
    uint64_t was_vert_pos = self.verticalPositionInBytes;
    m_ViewImpl->OnUpArrow();
    if(was_vert_pos != self.verticalPositionInBytes)
        [(id<BigFileViewDelegateProtocol>)m_Delegate BigFileViewScrolledByUser];
}

- (void)moveDown:(id)sender {
    uint64_t was_vert_pos = self.verticalPositionInBytes;
    m_ViewImpl->OnDownArrow();
    if(was_vert_pos != self.verticalPositionInBytes)
        [(id<BigFileViewDelegateProtocol>)m_Delegate BigFileViewScrolledByUser];
}

- (void)moveLeft:(id)sender {
    uint64_t was_vert_pos = self.verticalPositionInBytes;
    m_ViewImpl->OnLeftArrow();
    if(was_vert_pos != self.verticalPositionInBytes)
        [(id<BigFileViewDelegateProtocol>)m_Delegate BigFileViewScrolledByUser];
}

- (void)moveRight:(id)sender {
    uint64_t was_vert_pos = self.verticalPositionInBytes;
    m_ViewImpl->OnRightArrow();
    if(was_vert_pos != self.verticalPositionInBytes)
        [(id<BigFileViewDelegateProtocol>)m_Delegate BigFileViewScrolledByUser];
}

- (void)pageDown:(id)sender {
    uint64_t was_vert_pos = self.verticalPositionInBytes;
    m_ViewImpl->OnPageDown();
    if(was_vert_pos != self.verticalPositionInBytes)
        [(id<BigFileViewDelegateProtocol>)m_Delegate BigFileViewScrolledByUser];
}

- (void) pageUp:(id)sender {
    uint64_t was_vert_pos = self.verticalPositionInBytes;
    m_ViewImpl->OnPageUp();
    if(was_vert_pos != self.verticalPositionInBytes)
        [(id<BigFileViewDelegateProtocol>)m_Delegate BigFileViewScrolledByUser];
}

- (int) encoding
{
    if(m_Data) return m_Data->Encoding();
    return encodings::ENCODING_UTF8; // ??
}

- (void) setEncoding:(int)_encoding
{
    m_Data->SetEncoding(_encoding);
}

- (void)frameDidChange
{
    m_ViewImpl->OnFrameChanged();
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

- (void) UpdateVerticalScroll: (double) _pos prop:(double)prop
{
    [m_VerticalScroller setKnobProportion:prop];
    [m_VerticalScroller setDoubleValue:_pos];

    [(id<BigFileViewDelegateProtocol>)m_Delegate BigFileViewScrolled];
}

- (void)VerticalScroll:(id)sender
{
    uint64_t was_vert_pos = self.verticalPositionInBytes;
    switch ([m_VerticalScroller hitPart])
    {
        case NSScrollerIncrementLine:
            m_ViewImpl->OnDownArrow();
            break;
        case NSScrollerIncrementPage:
            // Include code here for the case where CTRL + down arrow is pressed, or the space the scroll knob moves in is pressed
            m_ViewImpl->OnPageDown();
            break;
        case NSScrollerDecrementLine:
            // Include code here for the case where the up arrow is pressed
            m_ViewImpl->OnUpArrow();
            break;
        case NSScrollerDecrementPage:
            // Include code here for the case where CTRL + up arrow is pressed, or the space the scroll knob moves in is pressed
            m_ViewImpl->OnPageUp();
            break;
        case NSScrollerKnob:
            // This case is when the knob itself is pressed
            m_ViewImpl->HandleVerticalScroll(m_VerticalScroller.doubleValue);
            break;
        default:
            break;
    }
    if(was_vert_pos != self.verticalPositionInBytes)
        [(id<BigFileViewDelegateProtocol>)m_Delegate BigFileViewScrolledByUser];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    uint64_t was_vert_pos = self.verticalPositionInBytes;
    m_ViewImpl->OnScrollWheel(theEvent);
    if(was_vert_pos != self.verticalPositionInBytes)
        [(id<BigFileViewDelegateProtocol>)m_Delegate BigFileViewScrolledByUser];
}

- (bool) wordWrap
{
    return m_WrapWords;
}

- (void)setWordWrap:(bool)_wrapping
{
    if(m_WrapWords != _wrapping)
    {
        m_WrapWords = _wrapping;
        m_ViewImpl->OnWordWrappingChanged();
    }
}

- (BigFileViewModes) mode
{
    if(dynamic_cast<BigFileViewText*>(m_ViewImpl.get()))
        return BigFileViewModes::Text;
    else if(dynamic_cast<BigFileViewHex*>(m_ViewImpl.get()))
        return BigFileViewModes::Hex;
    else
        assert(0);
}

- (void) setMode: (BigFileViewModes) _mode
{
    if(_mode == self.mode)
        return;
    
    uint32_t current_offset = m_ViewImpl->GetOffsetWithinWindow();
    
    switch (_mode)
    {
        case BigFileViewModes::Text:
            m_ViewImpl = make_unique<BigFileViewText>(m_Data.get(), self);
            break;
        case BigFileViewModes::Hex:
            m_ViewImpl = make_unique<BigFileViewHex>(m_Data.get(), self);
            break;
        default:
            assert(0);
    }

    m_ViewImpl->MoveOffsetWithinWindow(current_offset);
    [self setNeedsDisplay];
}

- (double) VerticalScrollPosition
{
    return  [m_VerticalScroller doubleValue];
}

- (void) ScrollToSelection
{
    if(m_SelectionInFile.location >= 0)
    {
        m_ViewImpl->ScrollToByteOffset(m_SelectionInFile.location);
        [self UpdateSelectionRange];
    }
}

- (uint64_t) verticalPositionInBytes
{
    return uint64_t(m_ViewImpl->GetOffsetWithinWindow()) + m_File->WindowPos();
}

- (void) setVerticalPositionInBytes:(uint64_t) _pos
{
    m_ViewImpl->ScrollToByteOffset(_pos);
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
    
    const uint32_t *offset = lower_bound(m_Data->UniCharToByteIndeces(),
                                              m_Data->UniCharToByteIndeces() + m_Data->UniCharsSize(),
                                              start - window_pos);
    assert(offset < m_Data->UniCharToByteIndeces() + m_Data->UniCharsSize());
    
    const uint32_t *tail = lower_bound(m_Data->UniCharToByteIndeces(),
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

- (CFRange) selectionInFile
{
    return m_SelectionInFile;
}

- (void) setSelectionInFile:(CFRange) _selection
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
        if(_selection.location + _selection.length > m_File->FileSize()) {
            if(_selection.location > m_File->FileSize()) {
                self.selectionInFile = CFRangeMake(-1, 0); // irrecoverable
                return;
            }
            _selection.length = m_File->FileSize() - _selection.location;
            if(_selection.length == 0) {
                self.selectionInFile = CFRangeMake(-1, 0); // irrecoverable
                return;
            }
        }
        
        m_SelectionInFile = _selection;
        [self UpdateSelectionRange];
    }
    [self setNeedsDisplay];
}

- (void) mouseDown:(NSEvent *)_event
{
    m_ViewImpl->OnMouseDown(_event);
}

 - (void)copy:(id)sender
{
    if(m_SelectionInWindow.location >= 0 && m_SelectionInWindow.length > 0)
    {
        NSString *str = [[NSString alloc] initWithCharacters:m_Data->UniChars() + m_SelectionInWindowUnichars.location
                                                      length:m_SelectionInWindowUnichars.length];
        NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
        [pasteBoard clearContents];
        [pasteBoard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, nil] owner:nil];
        [pasteBoard setString:str forType:NSStringPboardType];
    }
}

- (void)selectAll:(id)sender
{
    self.selectionInFile = CFRangeMake(0, m_File->FileSize());
}

- (void)deselectAll:(id)sender
{
    self.selectionInFile = CFRangeMake(-1, 0);
}

- (NSSize)contentBounds
{
    NSSize sz = self.bounds.size;
    sz.width -= [NSScroller scrollerWidthForControlSize:NSRegularControlSize scrollerStyle:NSScrollerStyleLegacy];
    if(self.hasBorder) {
        sz.width -= g_BorderWidth * 2;
        sz.height -= g_BorderWidth * 2;
    }
    return sz;
}

- (void) setHasBorder:(bool)hasBorder
{
    if(hasBorder != _hasBorder) {
        _hasBorder = hasBorder;
        [self layoutVerticalScroll];
    }
}

@end
