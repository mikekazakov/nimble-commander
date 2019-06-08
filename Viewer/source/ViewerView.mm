// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ViewerView.h"
#include <Utility/HexadecimalColor.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/DataBlockAnalysis.h>
#include <Utility/TemporaryFileStorage.h>
#include <Config/Config.h>
#include "DataBackend.h"
#include <Habanero/dispatch_cpp.h>
#include <VFS/VFS.h>
#include "Theme.h"
#include "TextModeView.h"
#include "HexModeView.h"
#include "PreviewModeView.h"

static const auto g_ConfigDefaultEncoding       = "viewer.defaultEncoding";
static const auto g_ConfigAutoDetectEncoding    = "viewer.autoDetectEncoding";

using nc::vfs::easy::CopyFileToTempStorage;
using namespace nc::viewer;

@implementation NCViewerView
{
    nc::vfs::FileWindow *m_File; // may be nullptr
    std::unique_ptr<DataBackend> m_Data; // may be nullptr

    std::optional<std::string> m_NativeStoredFile;
    
    // layout
    bool            m_WrapWords;
    
    NSView<NCViewerImplementationProtocol> *m_View;
        
    uint64_t        m_VerticalPositionInBytes;
    double          m_VerticalPositionPercentage;
    
    CFRange         m_SelectionInFile;  // in bytes, raw position within whole file
    CFRange         m_SelectionInWindow;         // in bytes, whithin current window positio
                                                 // updated when windows moves, regarding current selection in bytes
    CFRange         m_SelectionInWindowUnichars; // in UniChars, whithin current window position,
                                                 // updated when windows moves, regarding current selection in bytes
    nc::utility::TemporaryFileStorage *m_TempFileStorage;
    const nc::config::Config *m_Config;
    std::unique_ptr<nc::viewer::Theme> m_Theme;
}

@synthesize verticalPositionPercentage = m_VerticalPositionPercentage;

- (id)initWithFrame:(NSRect)frame
        tempStorage:(nc::utility::TemporaryFileStorage&)_temp_storage
             config:(const nc::config::Config&)_config
              theme:(std::unique_ptr<nc::viewer::Theme>)_theme
{
    if (self = [super initWithFrame:frame]) {
        
        m_TempFileStorage = &_temp_storage;
        m_Config = &_config;
        m_Theme = std::move(_theme);
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
    m_VerticalPositionPercentage = 0.;
    m_VerticalPositionInBytes = 0;
    m_WrapWords = true;
    m_SelectionInFile = CFRangeMake(-1, 0);
    m_SelectionInWindow = CFRangeMake(-1, 0);
    m_SelectionInWindowUnichars = CFRangeMake(-1, 0);
    
    [self reloadAppearance];

    __weak NCViewerView* weak_self = self;
    m_Theme->ObserveChanges([weak_self] {
        if( auto strong_self = weak_self )
            [strong_self reloadAppearance];
    });
}

- (void)reloadAppearance
{
    if( [m_View respondsToSelector:@selector(themeHasChanged)] )
        [m_View themeHasChanged];
}

- (BOOL)isOpaque
{
    return YES;
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

- (void) SetFile:(nc::vfs::FileWindow*) _file
{
    int encoding = encodings::EncodingFromName(m_Config->GetString(g_ConfigDefaultEncoding).c_str());
    if(encoding == encodings::ENCODING_INVALID)
        encoding = encodings::ENCODING_MACOS_ROMAN_WESTERN; // this should not happen, but just to be sure

    StaticDataBlockAnalysis stat;
    DoStaticDataBlockAnalysis(_file->Window(), _file->WindowSize(), &stat);
    if( m_Config->GetBool(g_ConfigAutoDetectEncoding) ) {
        if(stat.likely_utf16_le)        encoding = encodings::ENCODING_UTF16LE;
        else if(stat.likely_utf16_be)   encoding = encodings::ENCODING_UTF16BE;
        else if(stat.can_be_utf8)       encoding = encodings::ENCODING_UTF8;
        else                            encoding = encodings::ENCODING_MACOS_ROMAN_WESTERN;
    }
    
    ViewMode mode = stat.is_binary ? ViewMode::Hex : ViewMode::Text;
    
    [self SetKnownFile:_file encoding:encoding mode:mode];
}

- (void) SetKnownFile:(nc::vfs::FileWindow*) _file
             encoding:(int)_encoding
                 mode:(ViewMode)_mode
{
    assert(_encoding != encodings::ENCODING_INVALID);
    
    m_File = _file;
    m_Data = std::make_unique<DataBackend>(*m_File, _encoding);
    
    self.mode = _mode;
    self.verticalPositionInBytes = 0;
    self.selectionInFile = CFRangeMake(-1, 0);
    
    [self willChangeValueForKey:@"encoding"];
    [self didChangeValueForKey:@"encoding"];
}

- (void) detachFromFile
{
    dispatch_assert_main_queue();
    
    [m_View removeFromSuperview];
    m_View = nil;
    m_Data.reset();
    m_File = nullptr;
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
    
    if( [m_View respondsToSelector:@selector(backendContentHasChanged)] )
        [m_View backendContentHasChanged];
}

- (void) RequestWindowMovementAt: (uint64_t) _pos
{
    m_Data->MoveWindowSync(_pos);
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
    if( [m_View respondsToSelector:@selector(lineWrappingHasChanged)] ) {
        [m_View lineWrappingHasChanged];
    }
    [self didChangeValueForKey:@"wordWrap"];
}

- (ViewMode) mode
{
    if( [m_View isKindOfClass:NCViewerTextModeView.class] )
        return ViewMode::Text;
    if( [m_View isKindOfClass:NCViewerHexModeView.class] )
        return ViewMode::Hex;
    if( [m_View isKindOfClass:NCViewerPreviewModeView.class] )
        return ViewMode::Preview;    
    return ViewMode::Text;
}

- (void) setMode: (ViewMode)_mode
{
    if( _mode == ViewMode::Text && [m_View isKindOfClass:NCViewerTextModeView.class] )
        return;
    if( _mode == ViewMode::Hex  && [m_View isKindOfClass:NCViewerHexModeView.class] )
        return;
    if( _mode == ViewMode::Preview  && [m_View isKindOfClass:NCViewerPreviewModeView.class] )
        return;
    
    const auto is_first_responder = m_View && self.window && self.window.firstResponder == m_View;
    
    [self willChangeValueForKey:@"mode"];    
    
    if( m_View ) {
        [m_View removeFromSuperview];
    }
    
    if( _mode == ViewMode::Text ) {
        auto view = [[NCViewerTextModeView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)
                                                        backend:*m_Data
                                                          theme:*m_Theme];
        view.delegate = self;
        [self addFillingSubview:view];
        m_View = view;
    }
    if( _mode == ViewMode::Hex ) {
        auto view = [[NCViewerHexModeView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)
                                                       backend:*m_Data
                                                         theme:*m_Theme];
        view.delegate = self;
        [self addFillingSubview:view];
        m_View = view;
    }
    if( _mode == ViewMode::Preview ) {
        auto view = [[NCViewerPreviewModeView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)
                                                              path:[self previewPath]
                                                             theme:*m_Theme];
        [self addFillingSubview:view];
        m_View = view;
    }    
    
    if( [m_View respondsToSelector:@selector(scrollToGlobalBytesOffset:)] )    
        [m_View scrollToGlobalBytesOffset:(int64_t)m_VerticalPositionInBytes];
    
    [self didChangeValueForKey:@"mode"];    
    
    if( is_first_responder )
        [self.window makeFirstResponder:m_View];
    
    [m_View setFocusRingType:self.focusRingType];
}

- (void) addFillingSubview:(NSView*)_view
{
    [self addSubview:_view];
    NSDictionary *views = NSDictionaryOfVariableBindings(_view);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                          @"|-(==0)-[_view]-(==0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:
                          @"V:|-(==0)-[_view]-(==0)-|" options:0 metrics:nil views:views]];
}

- (std::string) previewPath
{

    if( m_File->File()->Host()->IsNativeFS() ) {
        return m_File->File()->Path();
    }
    else {
        if( !m_NativeStoredFile )
            m_NativeStoredFile = CopyFileToTempStorage(m_File->File()->Path(),
                                                       *m_File->File()->Host(),
                                                       *m_TempFileStorage);
        if( m_NativeStoredFile )
            return *m_NativeStoredFile;
        return "";
    }    
}

- (void) setFocusRingType:(NSFocusRingType)focusRingType
{
    if( self.focusRingType == focusRingType )
        return;
    [super setFocusRingType:focusRingType];
    [m_View setFocusRingType:focusRingType];
}

- (void) scrollToSelection
{
    if( m_SelectionInFile.location >= 0 ) {
        if( [m_View respondsToSelector:@selector(scrollToGlobalBytesOffset:)] ) {
            [m_View scrollToGlobalBytesOffset:m_SelectionInFile.location];
        }
    }
}

- (uint64_t) verticalPositionInBytes
{
    // should always be = uint64_t(m_ViewImpl->GetOffsetWithinWindow()) + m_File->WindowPos()
    return m_VerticalPositionInBytes;
}

- (void) setVerticalPositionInBytes:(uint64_t) _pos
{
    if( _pos == m_VerticalPositionInBytes )
        return;
    
    if( [m_View respondsToSelector:@selector(scrollToGlobalBytesOffset:)] )
        [m_View scrollToGlobalBytesOffset:(int64_t)_pos];
}

- (void)scrollToVerticalPosition:(double)_p
{    
    if( [m_View respondsToSelector:@selector(scrollToGlobalBytesOffset:)] ) {
        const auto offset = int64_t(double(m_File->FileSize()) * _p);
        [m_View scrollToGlobalBytesOffset:offset];
    }
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
    
    if( [m_View respondsToSelector:@selector(selectionHasChanged)] )
        [m_View selectionHasChanged];
    
    [self setNeedsDisplay];
}

 - (void)copy:(id)[[maybe_unused]]_sender
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

- (void)selectAll:(id)[[maybe_unused]]_sender
{
    if( !m_Data )
        return;

    self.selectionInFile = CFRangeMake(0, m_File->FileSize());
}

- (void)deselectAll:(id)[[maybe_unused]]_sender
{
    self.selectionInFile = CFRangeMake(-1, 0);
}

- (void)setVerticalPositionPercentage:(double)_percentage
{
    if( _percentage != m_VerticalPositionPercentage ) {
        [self willChangeValueForKey:@"verticalPositionPercentage"];
        m_VerticalPositionPercentage = _percentage;
        [self didChangeValueForKey:@"verticalPositionPercentage"];
    }
}

-(void)setVerticalPositionInBytesFromImpl:(int64_t)_position
{
    if( _position != (int64_t)m_VerticalPositionInBytes ) {
        [self willChangeValueForKey:@"verticalPositionInBytes"];
        m_VerticalPositionInBytes = _position;
        [self didChangeValueForKey:@"verticalPositionInBytes"];
    }
}

- (int) textModeView:(NCViewerTextModeView*)[[maybe_unused]]_view
requestsSyncBackendWindowMovementAt:(int64_t)_position
{
    return [self moveBackendWindowSyncAt:_position
                              notifyView:false];
}

- (int) hexModeView:(NCViewerHexModeView*)[[maybe_unused]]_view
requestsSyncBackendWindowMovementAt:(int64_t)_position
{
    return [self moveBackendWindowSyncAt:_position
                              notifyView:false];
}

- (int)moveBackendWindowSyncAt:(int64_t)_position
                    notifyView:(bool)_notify_view
{
    const auto rc = m_Data->MoveWindowSync(_position);
    if( rc != VFSError::Ok ) {
        // ... callout
        if( _notify_view ) {
            if( [m_View respondsToSelector:@selector(backendContentHasChanged)] )
                [m_View backendContentHasChanged];
        }
    }
    return rc;
}

- (void) textModeView:(NCViewerTextModeView*)[[maybe_unused]]_view
didScrollAtGlobalBytePosition:(int64_t)_position
withScrollerPosition:(double)_scroller_position
{
    [self setVerticalPositionInBytesFromImpl:_position];
    [self setVerticalPositionPercentage:_scroller_position];
}

- (void) hexModeView:(NCViewerHexModeView*)[[maybe_unused]]_view
didScrollAtGlobalBytePosition:(int64_t)_position
 withScrollerPosition:(double)_scroller_position
{
    [self setVerticalPositionInBytesFromImpl:_position];
    [self setVerticalPositionPercentage:_scroller_position];
}

- (CFRange) textModeViewProvideSelection:(NCViewerTextModeView*)[[maybe_unused]]_view
{
    return [self selectionInFile];
}

- (CFRange) hexModeViewProvideSelection:(NCViewerHexModeView*)[[maybe_unused]]_view
{
    return [self selectionInFile];    
}

- (void) textModeView:(NCViewerTextModeView*)[[maybe_unused]]_view
         setSelection:(CFRange)_selection
{
    self.selectionInFile = _selection;
}

- (void) hexModeView:(NCViewerHexModeView*)[[maybe_unused]]_view
         setSelection:(CFRange)_selection
{
    self.selectionInFile = _selection;
}

- (bool) textModeViewProvideLineWrapping:(NCViewerTextModeView*)[[maybe_unused]]_view
{
    return m_WrapWords;
}

- (NSResponder *) keyboardResponder
{
    return m_View;
}

- (BOOL)performKeyEquivalent:(NSEvent *)_event
{
    if( NSResponder *responder = self.hotkeyDelegate ) {
        if( [responder performKeyEquivalent:_event] )
            return true;
    }
    return [super performKeyEquivalent:_event];
}

@end
