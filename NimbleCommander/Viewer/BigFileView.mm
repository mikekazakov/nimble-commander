// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/HexadecimalColor.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/DataBlockAnalysis.h>
#include "../Bootstrap/AppDelegate.h"
#include "../Bootstrap/Config.h"
#include <NimbleCommander/Core/TemporaryNativeFileStorage.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/Theming/Theme.h>
#include <NimbleCommander/Core/Theming/ThemesManager.h>
#include "BigFileView.h"
#include "BigFileViewText.h"
#include "BigFileViewHex.h"
#include "InternalViewerViewPreviewMode.h"
#include "BigFileViewDataBackend.h"

static const auto g_ConfigDefaultEncoding       = "viewer.defaultEncoding";
static const auto g_ConfigAutoDetectEncoding    = "viewer.autoDetectEncoding";
/*static const auto g_ConfigModernShouldAntialias = "viewer.modern.shouldAntialiasText";
static const auto g_ConfigModernShouldSmooth    = "viewer.modern.shouldSmoothText";
static const auto g_ConfigModernTextColor       = "viewer.modern.textColor";
static const auto g_ConfigModernSelectionColor  = "viewer.modern.selectionColor";
static const auto g_ConfigModernBackgroundColor = "viewer.modern.backgroundColor";
static const auto g_ConfigModernFont            = "viewer.modern.font";
static const auto g_ConfigClassicShouldAntialias= "viewer.classic.shouldAntialiasText";
static const auto g_ConfigClassicShouldSmooth   = "viewer.classic.shouldSmoothText";
static const auto g_ConfigClassicTextColor      = "viewer.classic.textColor";
static const auto g_ConfigClassicSelectionColor = "viewer.classic.selectionColor";
static const auto g_ConfigClassicBackgroundColor= "viewer.classic.backgroundColor";
static const auto g_ConfigClassicFont           = "viewer.classic.font";*/

const static double g_BorderWidth = 1.0;

@implementation BigFileView
{
    FileWindow     *m_File; // may be nullptr
    unique_ptr<BigFileViewDataBackend> m_Data; // may be nullptr

    optional<string> m_NativeStoredFile;
    
    // layout
    bool            m_WrapWords;
    
    unique_ptr<BigFileViewImpl> m_ViewImpl; // view impl can be nullptr in case of view shut down
    
    NSScroller      *m_VerticalScroller;
    
    uint64_t        m_VerticalPositionInBytes;
    
    CFRange         m_SelectionInFile;  // in bytes, raw position within whole file
    CFRange         m_SelectionInWindow;         // in bytes, whithin current window positio
                                                 // updated when windows moves, regarding current selection in bytes
    CFRange         m_SelectionInWindowUnichars; // in UniChars, whithin current window position,
                                                 // updated when windows moves, regarding current selection in bytes
//    vector<GenericConfig::ObservationTicket> m_ConfigObservations;
    ThemesManager::ObservationTicket    m_ThemeObservation;    
}

- (id)initWithFrame:(NSRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    
    return self;
}

- (void) awakeFromNib
{
    [self commonInit];
}

- (void) commonInit
{
    self.hasBorder = false;
    m_VerticalPositionInBytes = 0;
    m_WrapWords = true;
    m_SelectionInFile = CFRangeMake(-1, 0);
    m_SelectionInWindow = CFRangeMake(-1, 0);
    m_SelectionInWindowUnichars = CFRangeMake(-1, 0);
    m_ViewImpl = make_unique<BigFileViewImpl>(); // dummy for initialization process
    
    [self reloadAppearance];
    
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
    [self bind:@"verticalPositionPercentage" toObject:m_VerticalScroller withKeyPath:@"doubleValue" options:nil];    
    
/*    __weak BigFileView* weak_self = self;
    GlobalConfig().ObserveMany(m_ConfigObservations,
                               [=]{ [(BigFileView*)weak_self reloadAppearance]; },
                               initializer_list<const char *>{  g_ConfigClassicFont,
                                   g_ConfigClassicShouldAntialias,
                                   g_ConfigClassicShouldSmooth,
                                   g_ConfigClassicTextColor,
                                   g_ConfigClassicSelectionColor,
                                   g_ConfigClassicBackgroundColor,
                                   g_ConfigModernFont,
                                   g_ConfigModernShouldAntialias,
                                   g_ConfigModernShouldSmooth,
                                   g_ConfigModernTextColor,
                                   g_ConfigModernSelectionColor,
                                   g_ConfigModernBackgroundColor   }
                               );
                               */
    
    __weak BigFileView* weak_self = self;
    m_ThemeObservation = NCAppDelegate.me.themesManager.ObserveChanges(
        ThemesManager::Notifications::Viewer, [weak_self]{
            if( auto strong_self = weak_self )
                [strong_self reloadAppearance];
        });
}

- (void) dealloc
{
    [self unbind:@"verticalPositionPercentage"];
    [NSNotificationCenter.defaultCenter removeObserver:self];
//    CFRelease(m_ForegroundColor);
//    CFRelease(m_Font);
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

- (void)reloadAppearance
{
//    auto skin = AppDelegate.me.skin;
//    if(skin == ApplicationSkin::Modern) {
//        m_ShouldSmoothFonts = GlobalConfig().GetBool(g_ConfigModernShouldSmooth);
//        m_ShouldAntialias = GlobalConfig().GetBool(g_ConfigModernShouldAntialias);

//        m_BackgroundFillColor = HexadecimalColorStringToRGBA(GlobalConfig().GetString(g_ConfigModernBackgroundColor).value_or(""));
//        m_SelectionBkFillColor = HexadecimalColorStringToRGBA(GlobalConfig().GetString(g_ConfigModernSelectionColor).value_or(""));
        // todo: switch to NSColor!
//        if(m_ForegroundColor) CFRelease(m_ForegroundColor);
//        m_ForegroundColor = CGColorCreateCopy([NSColor colorWithRGBA:HexadecimalColorStringToRGBA(GlobalConfig().GetString(g_ConfigModernTextColor).value_or(""))].CGColor);
        
        
//        if(m_Font) CFRelease(m_Font);
//        m_Font = (CTFontRef) CFBridgingRetain([NSFont fontWithStringDescription:[NSString stringWithUTF8StdString:GlobalConfig().GetString(g_ConfigModernFont).value_or("")]]);
//    }
//    else if(skin == ApplicationSkin::Classic) {
//        m_ShouldSmoothFonts = GlobalConfig().GetBool(g_ConfigClassicShouldSmooth);
//        m_ShouldAntialias = GlobalConfig().GetBool(g_ConfigClassicShouldAntialias);
//
//        m_BackgroundFillColor = HexadecimalColorStringToRGBA(GlobalConfig().GetString(g_ConfigClassicBackgroundColor).value_or(""));
//        m_SelectionBkFillColor = HexadecimalColorStringToRGBA(GlobalConfig().GetString(g_ConfigClassicSelectionColor).value_or(""));
//        // todo: switch to NSColor!
//        if(m_ForegroundColor) CFRelease(m_ForegroundColor);
//        m_ForegroundColor = CGColorCreateCopy([NSColor colorWithRGBA:HexadecimalColorStringToRGBA(GlobalConfig().GetString(g_ConfigClassicTextColor).value_or(""))].CGColor);
//        
//        if(m_Font) CFRelease(m_Font);
//        m_Font = (CTFontRef) CFBridgingRetain([NSFont fontWithStringDescription:[NSString stringWithUTF8StdString:GlobalConfig().GetString(g_ConfigClassicFont).value_or("")]]);
//    }
    if( m_ViewImpl )
        m_ViewImpl->OnFontSettingsChanged();
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
    if( !m_ViewImpl )
        return;
    
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
    int encoding = encodings::EncodingFromName(GlobalConfig().GetString(g_ConfigDefaultEncoding).value_or("").c_str());
    if(encoding == encodings::ENCODING_INVALID)
        encoding = encodings::ENCODING_MACOS_ROMAN_WESTERN; // this should not happen, but just to be sure

    StaticDataBlockAnalysis stat;
    DoStaticDataBlockAnalysis(_file->Window(), _file->WindowSize(), &stat);
    if( GlobalConfig().GetBool(g_ConfigAutoDetectEncoding) ) {
        if(stat.likely_utf16_le)        encoding = encodings::ENCODING_UTF16LE;
        else if(stat.likely_utf16_be)   encoding = encodings::ENCODING_UTF16BE;
        else if(stat.can_be_utf8)       encoding = encodings::ENCODING_UTF8;
        else                            encoding = encodings::ENCODING_MACOS_ROMAN_WESTERN;
    }
    
    BigFileViewModes mode = stat.is_binary ? BigFileViewModes::Hex : BigFileViewModes::Text;
    
    [self SetKnownFile:_file encoding:encoding mode:mode];
}

- (void) SetKnownFile:(FileWindow*) _file encoding:(int)_encoding mode:(BigFileViewModes)_mode
{
    assert(_encoding != encodings::ENCODING_INVALID);
    
    m_File = _file;
    m_Data = make_unique<BigFileViewDataBackend>(*m_File, _encoding);
    BigFileView* __weak weak_self = self;
    m_Data->SetOnDecoded(^{
        if(BigFileView *sself = weak_self) {
            [sself UpdateSelectionRange];
            sself->m_ViewImpl->OnBufferDecoded();
        }
    });
    
    self.mode = _mode;
    self.verticalPositionInBytes = 0;
    self.selectionInFile = CFRangeMake(-1, 0);
    
    [self willChangeValueForKey:@"encoding"];
    [self didChangeValueForKey:@"encoding"];
}

- (void) detachFromFile
{
    dispatch_assert_main_queue();
    
    m_ViewImpl.reset();
    m_Data.reset();
    m_File = nullptr;
}

- (void)keyDown:(NSEvent *)event
{
    if( !m_ViewImpl )
        return;
    
    if( event.charactersIgnoringModifiers.length != 1 )
        return;
    switch( [event.charactersIgnoringModifiers characterAtIndex:0] ) {
        case NSHomeFunctionKey: m_ViewImpl->HandleVerticalScroll(0.0); break;
        case NSEndFunctionKey:  m_ViewImpl->HandleVerticalScroll(1.0); break;
        default: [super keyDown:event]; return;
    }
    [self syncVerticalPositionInBytes];
}

- (void)moveUp:(id)sender
{
    if( !m_ViewImpl )
        return;
    
    m_ViewImpl->OnUpArrow();
    [self syncVerticalPositionInBytes];
}

- (void)moveDown:(id)sender
{
    if( !m_ViewImpl )
        return;
    
    m_ViewImpl->OnDownArrow();
    [self syncVerticalPositionInBytes];
}

- (void)moveLeft:(id)sender
{
    if( !m_ViewImpl )
        return;
    
    m_ViewImpl->OnLeftArrow();
    [self syncVerticalPositionInBytes];
}

- (void)moveRight:(id)sender
{
    if( !m_ViewImpl )
        return;
    
    m_ViewImpl->OnRightArrow();
    [self syncVerticalPositionInBytes];
}

- (void)pageDown:(id)sender
{
    if( !m_ViewImpl )
        return;
    
    m_ViewImpl->OnPageDown();
    [self syncVerticalPositionInBytes];
}

- (void) pageUp:(id)sender
{
    if( !m_ViewImpl )
        return;

    m_ViewImpl->OnPageUp();
    [self syncVerticalPositionInBytes];
}

- (int) encoding
{
    if(m_Data) return m_Data->Encoding();
    return encodings::ENCODING_UTF8; // ??
}

- (void) setEncoding:(int)_encoding
{
    if( !m_Data || m_Data->Encoding() == _encoding )
        return; // nothing to do

    [self willChangeValueForKey:@"encoding"];
    m_Data->SetEncoding(_encoding);
    [self didChangeValueForKey:@"encoding"];
}

- (void)frameDidChange
{
    if( !m_ViewImpl )
        return;
    
    m_ViewImpl->OnFrameChanged();
    [self syncVerticalScrollerState];
}

- (CTFontRef) TextFont{
    return (__bridge CTFontRef)CurrentTheme().ViewerFont();
}

- (CGColorRef) TextForegroundColor{
    return CurrentTheme().ViewerTextColor().CGColor;
}

- (CGColorRef) SelectionBkFillColor{
  return CurrentTheme().ViewerSelectionColor().CGColor;
}

- (CGColorRef) BackgroundFillColor{
    return CurrentTheme().ViewerBackgroundColor().CGColor;
}

- (void) RequestWindowMovementAt: (uint64_t) _pos
{
    m_Data->MoveWindowSync(_pos);
}

- (void)VerticalScroll:(id)sender
{
    if( !m_ViewImpl )
        return;
    
    switch( m_VerticalScroller.hitPart )
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
    [self syncVerticalPositionInBytes];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    if( !m_ViewImpl )
        return;
    
    m_ViewImpl->OnScrollWheel(theEvent);
    [self syncVerticalPositionInBytes];
}

- (bool)wordWrap
{
    return m_WrapWords;
}

- (void)setWordWrap:(bool)_wrapping
{
    if( m_WrapWords == _wrapping )
        return;
    
    [self willChangeValueForKey:@"wordWrap"];
    m_WrapWords = _wrapping;
    m_ViewImpl->OnWordWrappingChanged();
    [self didChangeValueForKey:@"wordWrap"];
}

- (BigFileViewModes) mode
{
    if(dynamic_cast<BigFileViewText*>(m_ViewImpl.get()))
        return BigFileViewModes::Text;
    else if(dynamic_cast<BigFileViewHex*>(m_ViewImpl.get()))
        return BigFileViewModes::Hex;
    else if(dynamic_cast<InternalViewerViewPreviewMode*>(m_ViewImpl.get()))
        return BigFileViewModes::Preview;
    else
//        assert(0);
        // in case of doubt - say we're in text mode (uninitialized really)
        return BigFileViewModes::Text;
    // TODO: make Text move be default
}

- (void) setMode: (BigFileViewModes) _mode
{
    if( _mode == BigFileViewModes::Text    && dynamic_cast<BigFileViewText*>(m_ViewImpl.get()))
        return;
    if( _mode == BigFileViewModes::Hex     && dynamic_cast<BigFileViewHex*>(m_ViewImpl.get()))
        return;
    if( _mode == BigFileViewModes::Preview && dynamic_cast<InternalViewerViewPreviewMode*>(m_ViewImpl.get()))
        return;
    
//    if( _mode == self.mode )
//        return;
//    
    [self willChangeValueForKey:@"mode"];
    
    uint32_t current_offset = m_ViewImpl ? m_ViewImpl->GetOffsetWithinWindow() : 0;
    
    switch (_mode)
    {
        case BigFileViewModes::Text:
            m_ViewImpl = make_unique<BigFileViewText>(m_Data.get(), self);
            break;
        case BigFileViewModes::Hex:
            m_ViewImpl = make_unique<BigFileViewHex>(m_Data.get(), self);
            break;
        case BigFileViewModes::Preview:
        {
            string path;
            if( m_File->File()->Host()->IsNativeFS() )
                path = m_File->File()->Path();
            else {
                if( !m_NativeStoredFile )
                    m_NativeStoredFile = TemporaryNativeFileStorage::Instance().CopySingleFile(m_File->File()->Path(), *m_File->File()->Host());
                if( m_NativeStoredFile )
                    path = *m_NativeStoredFile;
            }
            m_ViewImpl = make_unique<InternalViewerViewPreviewMode>(path, self);
            break;
        }
        default:
            assert(0);
    }
    
    m_ViewImpl->MoveOffsetWithinWindow(current_offset);
    m_VerticalScroller.hidden = !m_ViewImpl->NeedsVerticalScroller();
    [self setNeedsDisplay];
    
    [self didChangeValueForKey:@"mode"];
    
    [self syncVerticalPositionInBytes];
    [self syncVerticalScrollerState];    
}

- (double) VerticalScrollPosition
{
    return m_VerticalScroller.doubleValue;
}

- (void) ScrollToSelection
{
    if( !m_ViewImpl )
        return;
    
    if( m_SelectionInFile.location >= 0 ) {
        m_ViewImpl->ScrollToByteOffset(m_SelectionInFile.location);
        [self UpdateSelectionRange];
        [self syncVerticalScrollerState];
    }
}

- (void) syncVerticalScrollerState
{
    if( !m_ViewImpl )
        return;
    
    double scroll_pos = 0.0;
    double scroll_prop = 1.0;
    m_ViewImpl->CalculateScrollPosition(scroll_pos, scroll_prop);
    m_VerticalScroller.doubleValue = scroll_pos;
    m_VerticalScroller.knobProportion = scroll_prop;
}

- (void) syncVerticalPositionInBytes
{
    if( !m_ViewImpl )
        return;
    
//    dispatch_assert_main_queue();
    uint64_t value = uint64_t(m_ViewImpl->GetOffsetWithinWindow()) + m_File->WindowPos();
    if( value == m_VerticalPositionInBytes )
        return;
    
    [self willChangeValueForKey:@"verticalPositionInBytes"];
    m_VerticalPositionInBytes = value;
    [self didChangeValueForKey:@"verticalPositionInBytes"];

    [self syncVerticalScrollerState];
}

//- (double) verticalPositionPercentage
//{
//    return m_VerticalScroller.doubleValue; // guaranteed to be in sync????
//}

- (uint64_t) verticalPositionInBytes
{
    // should always be = uint64_t(m_ViewImpl->GetOffsetWithinWindow()) + m_File->WindowPos()
    return m_VerticalPositionInBytes;
    
//    return uint64_t(m_ViewImpl->GetOffsetWithinWindow()) + m_File->WindowPos();
}

- (void) setVerticalPositionInBytes:(uint64_t) _pos
{
    if( _pos == m_VerticalPositionInBytes )
        return;
    
    m_ViewImpl->ScrollToByteOffset(_pos);
//    m_VerticalPositionInBytes = uint64_t(m_ViewImpl->GetOffsetWithinWindow()) + m_File->WindowPos();
    [self syncVerticalPositionInBytes];
}

- (void)scrollToVerticalPosition:(double)_p
{
    if( !m_ViewImpl )
        return;
    
    m_ViewImpl->HandleVerticalScroll(_p);
    [self syncVerticalPositionInBytes];
}

// searching for selected UniChars in file window if there's any overlapping of
// selected bytes in file on current window position
// this method should be called on any file window movement
- (void) UpdateSelectionRange
{
    if( !m_Data )
        return;
    
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
    assert(startindex >= 0 && startindex < (long)m_Data->UniCharsSize());
    assert(endindex >= 0 && endindex <= (long)m_Data->UniCharsSize());
    
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
    if( !m_Data )
        return;
    
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
        if(_selection.location + _selection.length > (long)m_File->FileSize()) {
            if(_selection.location > (long)m_File->FileSize()) {
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
    if( !m_ViewImpl )
        return;

    m_ViewImpl->OnMouseDown(_event);
}

 - (void)copy:(id)sender
{
    if( !m_Data )
        return;
    
    if(m_SelectionInWindow.location >= 0 && m_SelectionInWindow.length > 0) {
        NSString *str = [[NSString alloc] initWithCharacters:m_Data->UniChars() + m_SelectionInWindowUnichars.location
                                                      length:m_SelectionInWindowUnichars.length];
        NSPasteboard *pasteBoard = NSPasteboard.generalPasteboard;
        [pasteBoard clearContents];
        [pasteBoard declareTypes:@[NSStringPboardType] owner:nil];
        [pasteBoard setString:str forType:NSStringPboardType];
    }
}

- (void)selectAll:(id)sender
{
    if( !m_Data )
        return;

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
