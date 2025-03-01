// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ViewerView.h"
#include "Highlighting/SettingsStorage.h"
#include <Utility/HexadecimalColor.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/DataBlockAnalysis.h>
#include <Utility/TemporaryFileStorage.h>
#include <Utility/ObjCpp.h>
#include <Config/Config.h>
#include "DataBackend.h"
#include <Base/dispatch_cpp.h>
#include <VFS/VFS.h>

#include "HexModeView.h"
#include "PreviewModeView.h"
#include "TextModeView.h"
#include "Theme.h"
#include "ViewerFooter.h"
#include "ViewerSearchView.h"
#include <algorithm>

static const auto g_ConfigDefaultEncoding = "viewer.defaultEncoding";
static const auto g_ConfigAutoDetectEncoding = "viewer.autoDetectEncoding";
static const auto g_ConfigStickToBottomOnRefresh = "viewer.stickToBottomOnRefresh";
static const auto g_ConfigEnableSyntaxHighlighting = "viewer.enableHighlighting";

using nc::vfs::easy::CopyFileToTempStorage;
using namespace nc;
using namespace nc::viewer;

@implementation NCViewerView {
    std::shared_ptr<nc::vfs::FileWindow> m_File; // may be nullptr
    std::shared_ptr<DataBackend> m_Data;         // may be nullptr

    std::optional<std::filesystem::path> m_NativeStoredFile;

    // layout
    bool m_WrapWords;

    NSView<NCViewerImplementationProtocol> *m_View;
    NCViewerFooter *m_Footer;
    NCViewerSearchView *m_SearchView;

    uint64_t m_VerticalPositionInBytes;
    double m_VerticalPositionPercentage;

    CFRange m_SelectionInFile;           // in bytes, raw position within whole file
    CFRange m_SelectionInWindow;         // in bytes, whithin current window positio
                                         // updated when windows moves, regarding current selection in bytes
    CFRange m_SelectionInWindowUnichars; // in UniChars, whithin current window position,
                                         // updated when windows moves, regarding current selection
                                         // in bytes
    std::string m_HighlightingLanguage;
    nc::utility::TemporaryFileStorage *m_TempFileStorage;
    nc::config::Config *m_Config;
    nc::viewer::hl::SettingsStorage *m_HighlightingSettings;
    std::unique_ptr<nc::viewer::Theme> m_Theme;
    std::array<nc::config::Token, 1> m_ConfigObservers;
}

@synthesize verticalPositionPercentage = m_VerticalPositionPercentage;
@synthesize hotkeyDelegate;

- (id)initWithFrame:(NSRect)frame
             tempStorage:(nc::utility::TemporaryFileStorage &)_temp_storage
                  config:(nc::config::Config &)_config
                   theme:(std::unique_ptr<nc::viewer::Theme>)_theme
    highlightingSettings:(nc::viewer::hl::SettingsStorage &)_hl_settings
{
    self = [super initWithFrame:frame];
    if( self ) {

        m_TempFileStorage = &_temp_storage;
        m_Config = &_config;
        m_HighlightingSettings = &_hl_settings;
        m_Theme = std::move(_theme);
        [self commonInit];
    }

    return self;
}

- (void)awakeFromNib
{
    [self commonInit];
}

- (void)commonInit
{
    m_VerticalPositionPercentage = 0.;
    m_VerticalPositionInBytes = 0;
    m_WrapWords = true;
    m_SelectionInFile = CFRangeMake(-1, 0);
    m_SelectionInWindow = CFRangeMake(-1, 0);
    m_SelectionInWindowUnichars = CFRangeMake(-1, 0);

    [self reloadAppearance];

    __weak NCViewerView *weak_self = self;
    m_Theme->ObserveChanges([weak_self] {
        if( auto strong_self = weak_self )
            [strong_self reloadAppearance];
    });

    m_ConfigObservers[0] =
        m_Config->Observe(g_ConfigEnableSyntaxHighlighting,
                          nc::objc_callback_to_main_queue(self, @selector(configEnableSyntaxHighlightingChanged)));

    m_Footer = [[NCViewerFooter alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)
                        andHighlightingSyntaxStorage:*m_HighlightingSettings];
    m_Footer.translatesAutoresizingMaskIntoConstraints = false;
    [self addSubview:m_Footer];

    m_SearchView = [[NCViewerSearchView alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    m_SearchView.translatesAutoresizingMaskIntoConstraints = false;
    m_SearchView.hidden = true;
    [self addSubview:m_SearchView positioned:NSWindowAbove relativeTo:nil];

    const auto views = NSDictionaryOfVariableBindings(m_Footer, m_SearchView);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_Footer]-(==0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[m_Footer(==20)]-(==0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(>=20)-[m_SearchView]-(==34)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==12)-[m_SearchView]"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
}

- (void)reloadAppearance
{
    if( [m_View respondsToSelector:@selector(themeHasChanged)] )
        [m_View themeHasChanged];
}

- (void)configEnableSyntaxHighlightingChanged
{
    if( [m_View respondsToSelector:@selector(syntaxHighlightingEnabled:)] )
        [m_View syntaxHighlightingEnabled:m_Config->GetBool(g_ConfigEnableSyntaxHighlighting)];
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
    if( m_View ) {
        [self addCursorRect:m_View.frame cursor:NSCursor.IBeamCursor];
    }
}

- (void)setFile:(std::shared_ptr<nc::vfs::FileWindow>)_file
{
    utility::Encoding encoding = utility::EncodingFromName(m_Config->GetString(g_ConfigDefaultEncoding).c_str());
    if( encoding == utility::Encoding::ENCODING_INVALID )
        encoding = utility::Encoding::ENCODING_MACOS_ROMAN_WESTERN; // this should not happen, but just to be sure

    StaticDataBlockAnalysis stat;
    DoStaticDataBlockAnalysis(_file->Window(), _file->WindowSize(), &stat);
    if( m_Config->GetBool(g_ConfigAutoDetectEncoding) ) {
        if( stat.likely_utf16_le )
            encoding = utility::Encoding::ENCODING_UTF16LE;
        else if( stat.likely_utf16_be )
            encoding = utility::Encoding::ENCODING_UTF16BE;
        else if( stat.can_be_utf8 )
            encoding = utility::Encoding::ENCODING_UTF8;
        else
            encoding = utility::Encoding::ENCODING_MACOS_ROMAN_WESTERN;
    }

    ViewMode mode = stat.is_binary ? ViewMode::Hex : ViewMode::Text;

    [self setKnownFile:_file encoding:encoding mode:mode language:std::nullopt];
}

- (void)setKnownFile:(std::shared_ptr<nc::vfs::FileWindow>)_file
            encoding:(utility::Encoding)_encoding
                mode:(ViewMode)_mode
            language:(const std::optional<std::string> &)_language
{
    assert(_encoding != utility::Encoding::ENCODING_INVALID);

    m_File = _file;
    m_Data = std::make_shared<DataBackend>(m_File, _encoding);

    self.mode = _mode;
    self.verticalPositionInBytes = 0;
    self.selectionInFile = CFRangeMake(-1, 0);
    self.language =
        _language ? _language.value() : m_HighlightingSettings->Language(m_Data->FileName().native()).value_or("");

    [self willChangeValueForKey:@"encoding"];
    [self didChangeValueForKey:@"encoding"];

    m_Footer.fileSize = m_File->FileSize();
    m_Footer.encoding = m_Data->Encoding();
    m_Footer.wrapLines = m_WrapWords;
}

- (void)detachFromFile
{
    dispatch_assert_main_queue();

    [m_View removeFromSuperview];
    m_View = nil;
    m_Data = nullptr;
    m_File = nullptr;
}

- (void)replaceFile:(std::shared_ptr<nc::vfs::FileWindow>)_file
{
    const uint64_t current_position = self.verticalPositionInBytes;
    const bool attach_to_bottom = m_Config->GetBool(g_ConfigStickToBottomOnRefresh) &&
                                  [m_View respondsToSelector:@selector(isAtTheEnd)] && [m_View isAtTheEnd];

    m_File = _file;
    m_Data = std::make_shared<DataBackend>(m_File, m_Data->Encoding());
    m_NativeStoredFile = std::nullopt;
    m_Footer.fileSize = m_File->FileSize();
    if( [m_View respondsToSelector:@selector(attachToNewBackend:)] ) {
        [m_View attachToNewBackend:m_Data];

        const uint64_t new_position =
            attach_to_bottom ? m_Data->FileSize() : std::min(current_position, m_Data->FileSize());

        if( [m_View respondsToSelector:@selector(scrollToGlobalBytesOffset:)] )
            [m_View scrollToGlobalBytesOffset:new_position];
    }
    else if( [m_View respondsToSelector:@selector(attachToNewFilepath:)] ) {
        [m_View attachToNewFilepath:self.previewPath];
    }
}

- (utility::Encoding)encoding
{
    if( m_Data )
        return m_Data->Encoding();
    return utility::Encoding::ENCODING_UTF8; // ??
}

- (void)setEncoding:(utility::Encoding)_encoding
{
    if( !m_Data || m_Data->Encoding() == _encoding )
        return; // nothing to do

    [self willChangeValueForKey:@"encoding"];
    m_Data->SetEncoding(_encoding);
    [self didChangeValueForKey:@"encoding"];

    if( [m_View respondsToSelector:@selector(backendContentHasChanged)] )
        [m_View backendContentHasChanged];

    m_Footer.encoding = m_Data->Encoding();
}

- (void)RequestWindowMovementAt:(uint64_t)_pos
{
    // TODO: what to do if this fails?
    std::ignore = m_Data->MoveWindowSync(_pos);
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

    m_Footer.wrapLines = m_WrapWords;
}

- (ViewMode)mode
{
    if( [m_View isKindOfClass:NCViewerTextModeView.class] )
        return ViewMode::Text;
    if( [m_View isKindOfClass:NCViewerHexModeView.class] )
        return ViewMode::Hex;
    if( [m_View isKindOfClass:NCViewerPreviewModeView.class] )
        return ViewMode::Preview;
    return ViewMode::Text;
}

- (void)setMode:(ViewMode)_mode
{
    if( _mode == ViewMode::Text && [m_View isKindOfClass:NCViewerTextModeView.class] )
        return;
    if( _mode == ViewMode::Hex && [m_View isKindOfClass:NCViewerHexModeView.class] )
        return;
    if( _mode == ViewMode::Preview && [m_View isKindOfClass:NCViewerPreviewModeView.class] )
        return;

    const auto is_first_responder = m_View && self.window && self.window.firstResponder == m_View;

    [self willChangeValueForKey:@"mode"];

    if( m_View ) {
        [m_View removeFromSuperview];
    }

    if( _mode == ViewMode::Text ) {
        auto view = [[NCViewerTextModeView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)
                                                        backend:m_Data
                                                          theme:*m_Theme
                                           highlightingSettings:*m_HighlightingSettings
                                             enableHighlighting:m_Config->GetBool(g_ConfigEnableSyntaxHighlighting)];
        view.delegate = self;
        [self addFillingSubview:view];
        m_View = view;
    }
    if( _mode == ViewMode::Hex ) {
        auto view = [[NCViewerHexModeView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)
                                                       backend:m_Data
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
        [m_View scrollToGlobalBytesOffset:static_cast<int64_t>(m_VerticalPositionInBytes)];

    if( [m_View respondsToSelector:@selector(setHighlightingLanguage:)] )
        [m_View setHighlightingLanguage:m_HighlightingLanguage];

    [self didChangeValueForKey:@"mode"];

    if( is_first_responder )
        [self.window makeFirstResponder:m_View];

    [m_View setFocusRingType:self.focusRingType];
    m_Footer.mode = _mode;
}

- (void)addFillingSubview:(NSView *)_view
{
    [self addSubview:_view positioned:NSWindowBelow relativeTo:nil];

    NSDictionary *views = NSDictionaryOfVariableBindings(_view, m_Footer);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[_view]-(==0)-|"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[_view]-(==0)-[m_Footer]"
                                                                 options:0
                                                                 metrics:nil
                                                                   views:views]];
}

- (std::filesystem::path)previewPath
{
    if( m_File->File()->Host()->IsNativeFS() ) {
        return m_File->File()->Path();
    }
    else {
        if( !m_NativeStoredFile )
            m_NativeStoredFile =
                CopyFileToTempStorage(m_File->File()->Path(), *m_File->File()->Host(), *m_TempFileStorage);
        if( m_NativeStoredFile )
            return *m_NativeStoredFile;
        return {};
    }
}

- (void)setFocusRingType:(NSFocusRingType)focusRingType
{
    if( self.focusRingType == focusRingType )
        return;
    [super setFocusRingType:focusRingType];
    [m_View setFocusRingType:focusRingType];
}

- (void)scrollToSelection
{
    if( m_SelectionInFile.location >= 0 ) {
        if( [m_View respondsToSelector:@selector(scrollToGlobalBytesOffset:)] ) {
            [m_View scrollToGlobalBytesOffset:m_SelectionInFile.location];
        }
    }
}

- (uint64_t)verticalPositionInBytes
{
    // should always be = uint64_t(m_ViewImpl->GetOffsetWithinWindow()) + m_File->WindowPos()
    return m_VerticalPositionInBytes;
}

- (void)setVerticalPositionInBytes:(uint64_t)_pos
{
    if( _pos == m_VerticalPositionInBytes )
        return;

    if( [m_View respondsToSelector:@selector(scrollToGlobalBytesOffset:)] )
        [m_View scrollToGlobalBytesOffset:static_cast<int64_t>(_pos)];
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
- (void)UpdateSelectionRange
{
    if( !m_Data )
        return;

    if( m_SelectionInFile.location < 0 || m_SelectionInFile.length < 1 ) {
        m_SelectionInWindow = CFRangeMake(-1, 0);
        m_SelectionInWindowUnichars = CFRangeMake(-1, 0);
        return;
    }

    uint64_t window_pos = m_File->WindowPos();
    uint64_t window_size = m_File->WindowSize();

    uint64_t start = m_SelectionInFile.location;
    uint64_t end = start + m_SelectionInFile.length;

    end = std::min(end, window_pos + window_size);
    start = std::max(start, window_pos);

    if( start >= end ) {
        m_SelectionInWindow = CFRangeMake(-1, 0);
        m_SelectionInWindowUnichars = CFRangeMake(-1, 0);
        return;
    }

    const uint32_t *offset = std::lower_bound(
        m_Data->UniCharToByteIndeces(), m_Data->UniCharToByteIndeces() + m_Data->UniCharsSize(), start - window_pos);
    assert(offset < m_Data->UniCharToByteIndeces() + m_Data->UniCharsSize());

    const uint32_t *tail = std::lower_bound(
        m_Data->UniCharToByteIndeces(), m_Data->UniCharToByteIndeces() + m_Data->UniCharsSize(), end - window_pos);
    assert(tail <= m_Data->UniCharToByteIndeces() + m_Data->UniCharsSize());

    int startindex = int(offset - m_Data->UniCharToByteIndeces());
    int endindex = int(tail - m_Data->UniCharToByteIndeces());
    assert(startindex >= 0 && startindex < static_cast<long>(m_Data->UniCharsSize()));
    assert(endindex >= 0 && endindex <= static_cast<long>(m_Data->UniCharsSize()));

    m_SelectionInWindow = CFRangeMake(start - window_pos, end - start);
    m_SelectionInWindowUnichars = CFRangeMake(startindex, endindex - startindex);
}

- (CFRange)SelectionWithinWindowUnichars
{
    return m_SelectionInWindowUnichars;
}

- (CFRange)SelectionWithinWindow
{
    return m_SelectionInWindow;
}

- (CFRange)SelectionInFile
{
    return m_SelectionInFile;
}

- (CFRange)selectionInFile
{
    return m_SelectionInFile;
}

- (void)setSelectionInFile:(CFRange)_selection
{
    if( !m_Data )
        return;

    if( _selection.location == m_SelectionInFile.location && _selection.length == m_SelectionInFile.length )
        return;

    if( _selection.location < 0 ) {
        m_SelectionInFile = CFRangeMake(-1, 0);
        m_SelectionInWindow = CFRangeMake(-1, 0);
        m_SelectionInWindowUnichars = CFRangeMake(-1, 0);
    }
    else {
        if( _selection.location + _selection.length > static_cast<long>(m_File->FileSize()) ) {
            if( _selection.location > static_cast<long>(m_File->FileSize()) ) {
                self.selectionInFile = CFRangeMake(-1, 0); // irrecoverable
                return;
            }
            _selection.length = m_File->FileSize() - _selection.location;
            if( _selection.length == 0 ) {
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

- (void)copy:(id) [[maybe_unused]] _sender
{
    if( !m_Data )
        return;

    if( m_SelectionInWindow.location >= 0 && m_SelectionInWindow.length > 0 ) {
        NSString *str = [[NSString alloc] initWithCharacters:m_Data->UniChars() + m_SelectionInWindowUnichars.location
                                                      length:m_SelectionInWindowUnichars.length];
        NSPasteboard *pasteBoard = NSPasteboard.generalPasteboard;
        [pasteBoard clearContents];
        [pasteBoard declareTypes:@[NSPasteboardTypeString] owner:nil];
        [pasteBoard setString:str forType:NSPasteboardTypeString];
    }
}

- (void)selectAll:(id) [[maybe_unused]] _sender
{
    if( !m_Data )
        return;

    self.selectionInFile = CFRangeMake(0, m_File->FileSize());
}

- (void)deselectAll:(id) [[maybe_unused]] _sender
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

- (void)setVerticalPositionInBytesFromImpl:(int64_t)_position
{
    if( _position != static_cast<int64_t>(m_VerticalPositionInBytes) ) {
        [self willChangeValueForKey:@"verticalPositionInBytes"];
        m_VerticalPositionInBytes = _position;
        [self didChangeValueForKey:@"verticalPositionInBytes"];
    }
}

- (std::expected<void, nc::Error>)textModeView:(NCViewerTextModeView *) [[maybe_unused]] _view
           requestsSyncBackendWindowMovementAt:(int64_t)_position
{
    return [self moveBackendWindowSyncAt:_position notifyView:false];
}

- (std::expected<void, nc::Error>)hexModeView:(NCViewerHexModeView *) [[maybe_unused]] _view
          requestsSyncBackendWindowMovementAt:(int64_t)_position
{
    return [self moveBackendWindowSyncAt:_position notifyView:false];
}

- (std::expected<void, Error>)moveBackendWindowSyncAt:(int64_t)_position notifyView:(bool)_notify_view
{
    const auto rc = m_Data->MoveWindowSync(_position);
    if( rc ) {
        // ... callout
        if( _notify_view ) {
            if( [m_View respondsToSelector:@selector(backendContentHasChanged)] )
                [m_View backendContentHasChanged];
        }
    }
    return rc;
}

- (void)textModeView:(NCViewerTextModeView *) [[maybe_unused]] _view
    didScrollAtGlobalBytePosition:(int64_t)_position
             withScrollerPosition:(double)_scroller_position
{
    [self setVerticalPositionInBytesFromImpl:_position];
    [self setVerticalPositionPercentage:_scroller_position];
}

- (void)hexModeView:(NCViewerHexModeView *) [[maybe_unused]] _view
    didScrollAtGlobalBytePosition:(int64_t)_position
             withScrollerPosition:(double)_scroller_position
{
    [self setVerticalPositionInBytesFromImpl:_position];
    [self setVerticalPositionPercentage:_scroller_position];
}

- (CFRange)textModeViewProvideSelection:(NCViewerTextModeView *) [[maybe_unused]] _view
{
    return [self selectionInFile];
}

- (CFRange)hexModeViewProvideSelection:(NCViewerHexModeView *) [[maybe_unused]] _view
{
    return [self selectionInFile];
}

- (void)textModeView:(NCViewerTextModeView *) [[maybe_unused]] _view setSelection:(CFRange)_selection
{
    self.selectionInFile = _selection;
}

- (void)hexModeView:(NCViewerHexModeView *) [[maybe_unused]] _view setSelection:(CFRange)_selection
{
    self.selectionInFile = _selection;
}

- (bool)textModeViewProvideLineWrapping:(NCViewerTextModeView *) [[maybe_unused]] _view
{
    return m_WrapWords;
}

- (NSResponder *)keyboardResponder
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

- (NCViewerFooter *)footer
{
    return m_Footer;
}

- (NCViewerSearchView *)searchView
{
    return m_SearchView;
}

- (std::string)language
{
    return m_HighlightingLanguage;
}

- (void)setLanguage:(std::string)_language
{
    if( m_HighlightingLanguage == _language ) {
        return;
    }
    m_HighlightingLanguage = _language;

    if( m_View && [m_View respondsToSelector:@selector(setHighlightingLanguage:)] ) {
        [m_View setHighlightingLanguage:m_HighlightingLanguage];
    }
    m_Footer.highlightingLanguage = m_HighlightingLanguage;
}

@end
