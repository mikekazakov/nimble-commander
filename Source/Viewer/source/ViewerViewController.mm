// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ViewerViewController.h"
#include <Viewer/Log.h>
#include <VFS/VFS.h>
#include <CUI/ProcessSheetController.h>
#include <Config/Config.h>
#include <VFS/SearchInFile.h>
#include <Utility/ByteCountFormatter.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <Utility/ActionShortcut.h>
#include "History.h"
#include <Base/SerialQueue.h>
#include "Internal.h"

using namespace std::literals;
using namespace nc::viewer;

static const auto g_ConfigRespectComAppleTextEncoding = "viewer.respectComAppleTextEncoding";
static const auto g_ConfigSearchCaseSensitive = "viewer.searchCaseSensitive";
static const auto g_ConfigSearchForWholePhrase = "viewer.searchForWholePhrase";
static const auto g_ConfigWindowSize = "viewer.fileWindowSize";
static const auto g_ConfigAutomaticRefresh = "viewer.automaticRefresh";
static const auto g_AutomaticRefreshDelay = std::chrono::milliseconds(200);

static int EncodingFromXAttr(const VFSFilePtr &_f)
{
    char buf[128];
    ssize_t r = _f->XAttrGet("com.apple.TextEncoding", buf, sizeof(buf));
    if( r < 0 || r >= static_cast<ssize_t>(sizeof(buf)) )
        return encodings::ENCODING_INVALID;
    buf[r] = 0;
    return encodings::FromComAppleTextEncodingXAttr(buf);
}

static int InvertBitFlag(int _value, int _flag)
{
    return (_value & ~_flag) | (~_value & _flag);
}

@interface NCViewerVerticalPostionToStringTransformer : NSValueTransformer
@end
@implementation NCViewerVerticalPostionToStringTransformer
+ (Class)transformedValueClass
{
    return NSString.class;
}
- (id)transformedValue:(id)value
{
    if( auto number = nc::objc_cast<NSNumber>(value) )
        return [NSString stringWithFormat:@"%2.0f%%", 100.0 * number.doubleValue];
    else
        return @"";
}
@end

namespace nc::viewer {

struct BackgroundFileOpener {
    int Open(VFSHostPtr _vfs,
             const std::string &_path,
             const nc::config::Config &_config,
             int _window_size);

    VFSFilePtr original_file;
    VFSSeqToRandomROWrapperFilePtr seq_wrapper;
    VFSFilePtr work_file;
    std::shared_ptr<nc::vfs::FileWindow> viewer_file_window;
    std::shared_ptr<nc::vfs::FileWindow> search_file_window;
    std::shared_ptr<nc::vfs::SearchInFile> search_in_file;
};

}

@interface NCViewerViewController ()

@property(nonatomic) IBOutlet NSPopover *goToPositionPopover;
@property(nonatomic) IBOutlet NSTextField *goToPositionValueTextField;
@property(nonatomic) IBOutlet NSPopUpButton *goToPositionKindButton;

@end

@implementation NCViewerViewController {
    std::string m_Path;
    std::string m_GlobalFilePath;
    VFSHostPtr m_VFS;
    VFSFilePtr m_OriginalFile;                   // may be not opened if SeqWrapper is used
    VFSSeqToRandomROWrapperFilePtr m_SeqWrapper; // may be nullptr if underlying VFS supports ReadAt
    VFSFilePtr m_WorkFile;                       // the one actually used
    nc::vfs::FileObservationToken m_FileObservationToken;
    std::atomic_bool m_AutomaticFileRefreshScheduled;
    std::shared_ptr<nc::vfs::FileWindow> m_ViewerFileWindow;
    std::shared_ptr<nc::vfs::FileWindow> m_SearchFileWindow;
    std::shared_ptr<nc::vfs::SearchInFile> m_SearchInFile;
    nc::base::SerialQueue m_SearchInFileQueue;
    nc::viewer::History *m_History;
    nc::config::Config *m_Config;
    std::function<nc::utility::ActionShortcut(std::string_view _name)> m_Shortcuts;

    // UI
    NCViewerView *m_View;
    NSSearchField *m_SearchField;
    NSProgressIndicator *m_SearchProgressIndicator;
    NSPopUpButton *m_EncodingsPopUp;
    NSPopUpButton *m_ModePopUp;
    NSButton *m_PositionButton;
    NSTextField *m_FileSizeLabel;
    NSString *m_VerboseTitle;
    NSButton *m_WordWrappingCheckBox;
}

@synthesize view = m_View;
@synthesize searchField = m_SearchField;
@synthesize searchProgressIndicator = m_SearchProgressIndicator;
@synthesize encodingsPopUp = m_EncodingsPopUp;
@synthesize modePopUp = m_ModePopUp;
@synthesize positionButton = m_PositionButton;
@synthesize fileSizeLabel = m_FileSizeLabel;
@synthesize verboseTitle = m_VerboseTitle;
@synthesize filePath = m_Path;
@synthesize fileVFS = m_VFS;
@synthesize wordWrappingCheckBox = m_WordWrappingCheckBox;
@synthesize settingsButton;
@synthesize goToPositionPopover;
@synthesize goToPositionValueTextField;
@synthesize goToPositionKindButton;

- (instancetype)initWithHistory:(nc::viewer::History &)_history
                         config:(nc::config::Config &)_config
              shortcutsProvider:
                  (std::function<nc::utility::ActionShortcut(std::string_view _name)>)_shortcuts
{
    self = [super init];
    if( self ) {
        Log::Debug(SPDLOC, "created new NCViewerViewController {}", nc::objc_bridge_cast<void>(self));
        m_History = &_history;
        m_Config = &_config;
        m_Shortcuts = _shortcuts;
        m_AutomaticFileRefreshScheduled = false;
        __weak NCViewerViewController *weak_self = self;
        m_SearchInFileQueue.SetOnChange([=] {
            [static_cast<NCViewerViewController *>(weak_self) onSearchInFileQueueStateChanged];
        });

        NSNib *mynib = [[NSNib alloc] initWithNibNamed:@"InternalViewerController" bundle:Bundle()];
        [mynib instantiateWithOwner:self topLevelObjects:nil];
    }
    return self;
}

- (void)dealloc
{
    dispatch_assert_main_queue();
    Log::Debug(SPDLOC, "deallocating NCViewerViewController {}", nc::objc_bridge_cast<void>(self));
    [self clear];
}

- (void)clear
{
    dispatch_assert_main_queue();
    m_SearchInFileQueue.Stop();
    m_SearchInFileQueue.Wait();

    [m_View detachFromFile];
    m_SearchInFile.reset();
    m_ViewerFileWindow.reset();
    m_SearchFileWindow.reset();
    m_WorkFile.reset();
    m_SeqWrapper.reset();
    m_OriginalFile.reset();
    m_VFS.reset();
    m_Path.clear();
    m_GlobalFilePath.clear();
    m_FileObservationToken.reset();
}

- (void)setFile:(std::string)path at:(VFSHostPtr)vfs
{
    //    dispatch_assert_main_queue();
    // current state checking?

    if( path.empty() || !vfs )
        throw std::logic_error("invalid args for - (void) setFile:(string)path at:(VFSHostPtr)vfs");

    m_Path = path;
    m_VFS = vfs;
}

- (bool)performBackgroundOpening
{
    dispatch_assert_background_queue();

    BackgroundFileOpener opener;
    const int open_err = opener.Open(m_VFS, m_Path, *m_Config, self.fileWindowSize);
    if( open_err != VFSError::Ok )
        return false;
    m_OriginalFile = std::move(opener.original_file);
    m_SeqWrapper = std::move(opener.seq_wrapper);
    m_WorkFile = std::move(opener.work_file);
    m_ViewerFileWindow = std::move(opener.viewer_file_window);
    m_SearchFileWindow = std::move(opener.search_file_window);
    m_SearchInFile = std::move(opener.search_in_file);
    m_GlobalFilePath = m_WorkFile->ComposeVerbosePath();

    [self buildTitle];

    if( m_Config->GetBool(g_ConfigAutomaticRefresh) ) {
        assert(m_VFS);
        __weak NCViewerViewController *weak_self = self;
        m_FileObservationToken = m_VFS->ObserveFileChanges(m_Path.c_str(), [weak_self] {
            if( NCViewerViewController *strong_self = weak_self )
                [strong_self onFileChanged];
        });
    }

    return true;
}

- (void)show
{
    dispatch_assert_main_queue();
    assert(self.view != nil);

    // try to load a saved info if any
    if( auto info = m_History->EntryByPath(m_GlobalFilePath) ) {
        auto options = m_History->Options();
        if( options.encoding && options.mode ) {
            [m_View setKnownFile:m_ViewerFileWindow encoding:info->encoding mode:info->view_mode];
        }
        else {
            [m_View setFile:m_ViewerFileWindow];
            if( options.encoding )
                m_View.encoding = info->encoding;
            if( options.mode )
                m_View.mode = info->view_mode;
        }
        // a bit suboptimal no - may re-layout after first one
        if( options.wrapping )
            m_View.wordWrap = info->wrapping;
        if( options.position )
            m_View.verticalPositionInBytes = info->position;
        if( options.selection )
            m_View.selectionInFile = info->selection;
    }
    else {
        [m_View setFile:m_ViewerFileWindow];
        int encoding = 0;
        if( m_Config->GetBool(g_ConfigRespectComAppleTextEncoding) &&
            (encoding = EncodingFromXAttr(m_OriginalFile)) != encodings::ENCODING_INVALID )
            m_View.encoding = encoding;
    }

    m_FileSizeLabel.stringValue = ByteCountFormatter::Instance().ToNSString(
        m_ViewerFileWindow->FileSize(), ByteCountFormatter::Fixed6);

    m_View.hotkeyDelegate = self;
}

- (void)saveFileState
{
    if( !m_History->Enabled() )
        return;

    if( m_GlobalFilePath.empty() ) // are we actually loaded?
        return;

    // do our state persistance stuff
    nc::viewer::History::Entry info;
    info.path = m_GlobalFilePath;
    info.position = m_View.verticalPositionInBytes;
    info.wrapping = m_View.wordWrap;
    info.view_mode = m_View.mode;
    info.encoding = m_View.encoding;
    info.selection = m_View.selectionInFile;
    m_History->AddEntry(std::move(info));
}

- (unsigned)fileWindowSize
{
    unsigned file_window_size = nc::vfs::FileWindow::DefaultWindowSize;
    unsigned file_window_pow2x = m_Config->GetInt(g_ConfigWindowSize);
    if( file_window_pow2x <= 5 )
        file_window_size *= 1 << file_window_pow2x;
    return file_window_size;
}

- (void)setView:(NCViewerView *)view
{
    if( m_View == view )
        return;

    m_View = view;
}

- (void)setSearchField:(NSSearchField *)searchField
{
    if( m_SearchField == searchField )
        return;

    m_SearchField = searchField;
    m_SearchField.target = self;
    m_SearchField.action = @selector(onSearchFieldAction:);
    m_SearchField.delegate = self;
    auto cell = static_cast<NSSearchFieldCell *>(m_SearchField.cell);
    cell.placeholderString = NSLocalizedString(
        @"Search in file", "Placeholder for search text field in internal viewer");
    cell.sendsWholeSearchString = true;
    cell.recentsAutosaveName = @"BigFileViewRecentSearches";
    cell.maximumRecents = 20;
    cell.searchMenuTemplate = self.searchFieldMenu;
}

- (BOOL)control:(NSControl *)control
               textView:(NSTextView *) [[maybe_unused]] _text_view
    doCommandBySelector:(SEL)commandSelector
{
    if( control == m_SearchField && commandSelector == @selector(cancelOperation:) ) {
        [m_View.window makeFirstResponder:m_View.keyboardResponder];
        return true;
    }
    return false;
}

- (NSMenu *)searchFieldMenu
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
    NSMenuItem *item;

    item = [[NSMenuItem alloc]
        initWithTitle:NSLocalizedString(@"Case-sensitive search",
                                        "Menu item option in internal viewer search")
               action:@selector(onSearchFieldMenuCaseSensitiveAction:)
        keyEquivalent:@""];
    item.state = m_Config->GetBool(g_ConfigSearchCaseSensitive);
    item.target = self;
    [menu insertItem:item atIndex:0];

    item = [[NSMenuItem alloc]
        initWithTitle:NSLocalizedString(@"Find whole phrase",
                                        "Menu item option in internal viewer search")
               action:@selector(onSearchFiledMenuWholePhraseSearch:)
        keyEquivalent:@""];
    item.state = m_Config->GetBool(g_ConfigSearchForWholePhrase);
    item.target = self;
    [menu insertItem:item atIndex:1];

    item = [[NSMenuItem alloc]
        initWithTitle:NSLocalizedString(@"Clear Recents",
                                        "Menu item title in internal viewer search")
               action:NULL
        keyEquivalent:@""];
    item.tag = NSSearchFieldClearRecentsMenuItemTag;
    [menu insertItem:item atIndex:2];

    item = [NSMenuItem separatorItem];
    item.tag = NSSearchFieldRecentsTitleMenuItemTag;
    [menu insertItem:item atIndex:3];

    item = [[NSMenuItem alloc]
        initWithTitle:NSLocalizedString(@"Recent Searches",
                                        "Menu item title in internal viewer search")
               action:NULL
        keyEquivalent:@""];
    item.tag = NSSearchFieldRecentsTitleMenuItemTag;
    [menu insertItem:item atIndex:4];

    item = [[NSMenuItem alloc]
        initWithTitle:NSLocalizedString(@"Recents", "Menu item title in internal viewer search")
               action:NULL
        keyEquivalent:@""];
    item.tag = NSSearchFieldRecentsMenuItemTag;
    [menu insertItem:item atIndex:5];

    return menu;
}

- (IBAction)onMainMenuPerformFindAction:(id) [[maybe_unused]] _sender
{
    [self.view.window makeFirstResponder:m_SearchField];
}

- (IBAction)onMainMenuPerformFindNextAction:(id) [[maybe_unused]] _sender
{
    [self onSearchFieldAction:self];
}

- (void)onSearchFieldAction:(id) [[maybe_unused]] _sender
{
    NSString *str = m_SearchField.stringValue;
    if( str.length == 0 ) {
        m_SearchInFileQueue.Stop(); // we should stop current search if any
        m_View.selectionInFile = CFRangeMake(-1, 0);
        return;
    }

    if( m_SearchInFile->TextSearchString() == NULL ||
        [str compare:(__bridge NSString *)m_SearchInFile->TextSearchString()] != NSOrderedSame ||
        m_SearchInFile->TextSearchEncoding() != m_View.encoding ) {
        // user did some changes in search request
        m_View.selectionInFile = CFRangeMake(-1, 0); // remove current selection

        uint64_t view_offset = m_View.verticalPositionInBytes;
        int encoding = m_View.encoding;

        m_SearchInFileQueue.Stop(); // we should stop current search if any
        m_SearchInFileQueue.Wait();
        m_SearchInFileQueue.Run([=] {
            m_SearchInFile->MoveCurrentPosition(view_offset);
            m_SearchInFile->ToggleTextSearch((__bridge CFStringRef)str, encoding);
        });
    }
    else {
        // request is the same
        if( !m_SearchInFileQueue.Empty() )
            return; // we're already performing this request now, nothing to do
    }

    m_SearchInFileQueue.Run([=] {
        if( m_SearchInFile->IsEOF() )
            m_SearchInFile->MoveCurrentPosition(0);

        const auto result =
            m_SearchInFile->Search([self] { return m_SearchInFileQueue.IsStopped(); });

        if( result.response == nc::vfs::SearchInFile::Response::Found ) {
            const auto range = CFRangeMake(result.location->offset, result.location->bytes_len);
            dispatch_to_main_queue([=] {
                m_View.selectionInFile = range;
                [m_View scrollToSelection];
            });
        }
    });
}

- (void)onSearchInFileQueueStateChanged
{
    if( m_SearchInFileQueue.Empty() )
        dispatch_to_main_queue([=] { [m_SearchProgressIndicator stopAnimation:self]; });
    else
        dispatch_to_main_queue_after(
            100ms, [=] { // should be 100 ms of workload before user will get spinning indicator
                if( !m_SearchInFileQueue.Empty() ) // need to check if task was already done
                    [m_SearchProgressIndicator startAnimation:self];
            });
}

- (void)onSearchFieldMenuCaseSensitiveAction:(id) [[maybe_unused]] _sender
{
    using nc::vfs::SearchInFile;
    using Options = SearchInFile::Options;
    const auto options =
        static_cast<Options>(InvertBitFlag(static_cast<int>(m_SearchInFile->SearchOptions()),
                                           static_cast<int>(Options::CaseSensitive)));
    m_SearchInFile->SetSearchOptions(options);

    auto cell = static_cast<NSSearchFieldCell *>(m_SearchField.cell);
    NSMenu *menu = cell.searchMenuTemplate;
    [menu itemAtIndex:0].state = (options & Options::CaseSensitive) != Options::None;
    cell.searchMenuTemplate = menu;
    m_Config->Set(g_ConfigSearchCaseSensitive, bool(options & Options::CaseSensitive));
}

- (void)onSearchFiledMenuWholePhraseSearch:(id) [[maybe_unused]] _sender
{
    using nc::vfs::SearchInFile;
    using Options = SearchInFile::Options;
    const auto options =
        static_cast<Options>(InvertBitFlag(static_cast<int>(m_SearchInFile->SearchOptions()),
                                           static_cast<int>(Options::FindWholePhrase)));
    m_SearchInFile->SetSearchOptions(options);

    auto cell = static_cast<NSSearchFieldCell *>(m_SearchField.cell);
    NSMenu *menu = cell.searchMenuTemplate;
    [menu itemAtIndex:1].state = (options & Options::FindWholePhrase) != Options::None;
    cell.searchMenuTemplate = menu;
    m_Config->Set(g_ConfigSearchForWholePhrase, bool(options & Options::FindWholePhrase));
}

- (void)setSearchProgressIndicator:(NSProgressIndicator *)searchProgressIndicator
{
    dispatch_assert_main_queue();
    if( m_SearchProgressIndicator == searchProgressIndicator )
        return;

    m_SearchProgressIndicator = searchProgressIndicator;
    m_SearchProgressIndicator.indeterminate = true;
    m_SearchProgressIndicator.style = NSProgressIndicatorStyleSpinning;
    m_SearchProgressIndicator.displayedWhenStopped = false;
}

- (void)setEncodingsPopUp:(NSPopUpButton *)encodingsPopUp
{
    dispatch_assert_main_queue();
    assert(m_View != nil);
    if( m_EncodingsPopUp == encodingsPopUp )
        return;
    m_EncodingsPopUp = encodingsPopUp;
    m_EncodingsPopUp.target = self;
    m_EncodingsPopUp.action = @selector(onEncodingsPopUpChanged:);
    [m_EncodingsPopUp removeAllItems];
    for( const auto &i : encodings::LiteralEncodingsList() ) {
        [m_EncodingsPopUp addItemWithTitle:(__bridge NSString *)i.second];
        m_EncodingsPopUp.lastItem.tag = i.first;
    }
    [m_EncodingsPopUp bind:@"selectedTag" toObject:m_View withKeyPath:@"encoding" options:nil];
}

- (void)onEncodingsPopUpChanged:(id) [[maybe_unused]] _sender
{
    dispatch_assert_main_queue();
    [self onSearchFieldAction:self];
}

- (void)setModePopUp:(NSPopUpButton *)modePopUp
{
    dispatch_assert_main_queue();
    if( m_ModePopUp == modePopUp )
        return;

    m_ModePopUp = modePopUp;
    m_ModePopUp.target = self;
    m_ModePopUp.action = @selector(onModePopUpChanged:);
    [m_ModePopUp removeAllItems];
    [m_ModePopUp addItemWithTitle:@"Text"];
    m_ModePopUp.lastItem.tag = static_cast<int>(ViewMode::Text);
    [m_ModePopUp addItemWithTitle:@"Hex"];
    m_ModePopUp.lastItem.tag = static_cast<int>(ViewMode::Hex);
    [m_ModePopUp addItemWithTitle:@"Preview"];
    m_ModePopUp.lastItem.tag = static_cast<int>(ViewMode::Preview);
    [m_ModePopUp bind:@"selectedTag" toObject:m_View withKeyPath:@"mode" options:nil];
}

- (void)onModePopUpChanged:(id) [[maybe_unused]] _sender
{
    dispatch_assert_main_queue();
}

- (void)setPositionButton:(NSButton *)positionButton
{
    dispatch_assert_main_queue();
    if( m_PositionButton == positionButton )
        return;

    m_PositionButton = positionButton;
    m_PositionButton.target = self;
    m_PositionButton.action = @selector(onPositionButtonClicked:);
    [m_PositionButton
               bind:@"title"
           toObject:m_View
        withKeyPath:@"verticalPositionPercentage"
            options:@{
                NSValueTransformerBindingOption: [NCViewerVerticalPostionToStringTransformer new]
            }];
}

- (void)onPositionButtonClicked:(id)sender
{
    [self.goToPositionPopover showRelativeToRect:nc::objc_cast<NSButton>(sender).bounds
                                          ofView:nc::objc_cast<NSButton>(sender)
                                   preferredEdge:NSMaxYEdge];
}

- (void)popoverWillShow:(NSNotification *) [[maybe_unused]] _notification
{
    [self.goToPositionValueTextField.window
        setInitialFirstResponder:self.goToPositionValueTextField];
    [self.goToPositionValueTextField.window makeFirstResponder:self.goToPositionValueTextField];
}

- (IBAction)onGoToPositionActionClicked:(id) [[maybe_unused]] _sender
{
    [self.goToPositionPopover close];
    const auto string = [self.goToPositionValueTextField stringValue];
    if( self.goToPositionKindButton.selectedTag == 0 ) {
        const double pos = string.doubleValue / 100.;
        [m_View scrollToVerticalPosition:std::clamp(pos, 0., 1.)];
    }
    if( self.goToPositionKindButton.selectedTag == 1 ) {
        const long pos = string.integerValue;
        m_View.verticalPositionInBytes = std::clamp(pos, 0l, m_WorkFile->Size());
    }
}

- (void)setFileSizeLabel:(NSTextField *)fileSizeLabel
{
    dispatch_assert_main_queue();
    if( m_FileSizeLabel == fileSizeLabel )
        return;
    m_FileSizeLabel = fileSizeLabel;
}

- (void)buildTitle
{
    NSString *path = [NSString stringWithUTF8StdString:m_GlobalFilePath];
    if( path == nil )
        path = @"...";
    NSString *title =
        [NSString stringWithFormat:NSLocalizedString(@"File View - %@",
                                                     "Window title for internal file viewer"),
                                   path];

    [self willChangeValueForKey:@"verboseTitle"];
    m_VerboseTitle = title;
    [self didChangeValueForKey:@"verboseTitle"];
}

- (void)markSelection:(CFRange)_selection forSearchTerm:(std::string)_request
{
    dispatch_assert_main_queue();

    m_SearchInFileQueue.Stop(); // we should stop current search if any

    self.view.selectionInFile = _selection;
    [self.view scrollToSelection];

    NSString *search_request = [NSString stringWithUTF8StdString:_request];
    m_SearchField.stringValue = search_request;

    if( _selection.location + _selection.length <
        static_cast<int64_t>(m_SearchFileWindow->FileSize()) )
        m_SearchInFile->MoveCurrentPosition(_selection.location + _selection.length);
    else
        m_SearchInFile->MoveCurrentPosition(0);
    m_SearchInFile->ToggleTextSearch((__bridge CFStringRef)search_request, m_View.encoding);
}

- (void)setWordWrappingCheckBox:(NSButton *)wordWrappingCheckBox
{
    dispatch_assert_main_queue();
    if( m_WordWrappingCheckBox == wordWrappingCheckBox )
        return;
    m_WordWrappingCheckBox = wordWrappingCheckBox;
    [m_WordWrappingCheckBox bind:@"value" toObject:m_View withKeyPath:@"wordWrap" options:nil];
}

- (bool)isOpened
{
    return m_WorkFile != nullptr;
}

- (void)commitRefresh:(BackgroundFileOpener &)_opener
{
    dispatch_assert_main_queue();

    [m_View replaceFile:_opener.viewer_file_window];

    m_OriginalFile = std::move(_opener.original_file);
    m_SeqWrapper = std::move(_opener.seq_wrapper);
    m_WorkFile = std::move(_opener.work_file);
    m_ViewerFileWindow = std::move(_opener.viewer_file_window);
    m_SearchFileWindow = std::move(_opener.search_file_window);
    m_SearchInFile = std::move(_opener.search_in_file);

    m_FileSizeLabel.stringValue = ByteCountFormatter::Instance().ToNSString(
        m_ViewerFileWindow->FileSize(), ByteCountFormatter::Fixed6);
}

- (void)onRefresh
{
    Log::Debug(SPDLOC, "refresh called");
    __weak NCViewerViewController *weak_self = self;
    dispatch_to_background([weak_self] {
        NCViewerViewController *strong_self = weak_self;
        if( !strong_self )
            return;

        auto opener = std::make_unique<BackgroundFileOpener>();
        const int open_err = opener->Open(strong_self->m_VFS,
                                          strong_self->m_Path,
                                          *strong_self->m_Config,
                                          strong_self.fileWindowSize);
        if( open_err != VFSError::Ok ) {
            Log::Warn(
                SPDLOC, "failed to open a path {}, vfs_error: {}", strong_self->m_Path, open_err);
            return;
        }

        dispatch_to_main_queue([weak_self, opener = std::move(opener)] {
            NCViewerViewController *strong_self = weak_self;
            if( !strong_self )
                return;
            [strong_self commitRefresh:*opener];
        });
    });
}

- (void)onFileChanged
{
    if( m_AutomaticFileRefreshScheduled )
        return;
    m_AutomaticFileRefreshScheduled = true;
    __weak NCViewerViewController *weak_self = self;
    dispatch_to_main_queue_after(g_AutomaticRefreshDelay, [weak_self]{
        if( NCViewerViewController *strong_self = weak_self ) {
            strong_self->m_AutomaticFileRefreshScheduled = false;
            [strong_self onRefresh];
        }
    });
}

- (BOOL)performKeyEquivalent:(NSEvent *)_event
{
    const auto event_data = nc::utility::ActionShortcut::EventData(_event);
    const auto is = [&](std::string_view _action_name) { return m_Shortcuts(_action_name).IsKeyDown(event_data); };
    if( is("viewer.toggle_text") ) {
        [m_View setMode:ViewMode::Text];
        return true;
    }
    if( is("viewer.toggle_hex") ) {
        [m_View setMode:ViewMode::Hex];
        return true;
    }
    if( is("viewer.toggle_preview") ) {
        [m_View setMode:ViewMode::Preview];
        return true;
    }
    if( is("viewer.show_settings") ) {
        [self.settingsButton performClick:self];
        return true;
    }
    if( is("viewer.show_goto") ) {
        [self.positionButton performClick:self];
        return true;
    }
    if( is("viewer.refresh") ) {
        [self onRefresh];
        return true;
    }
    return false;
}

@end

namespace nc::viewer {

int BackgroundFileOpener::Open(VFSHostPtr _vfs,
                               const std::string &_path,
                               const nc::config::Config &_config,
                               int _window_size)
{
    dispatch_assert_background_queue();
    assert(_vfs);
    if( int vfs_err = _vfs->CreateFile(_path.c_str(), original_file, 0); vfs_err != VFSError::Ok )
        return vfs_err;

    if( original_file->GetReadParadigm() < VFSFile::ReadParadigm::Random ) {
        // we need to read a file into temporary mem/file storage to access it randomly
        ProcessSheetController *proc = [ProcessSheetController new];
        proc.title = NSLocalizedString(@"Opening file...",
                                       "Title for process sheet when opening a vfs file");
        [proc Show];

        auto wrapper = std::make_shared<VFSSeqToRandomROWrapperFile>(original_file);
        const int open_err = wrapper->Open(
            VFSFlags::OF_Read | VFSFlags::OF_ShLock,
            [=] { return proc.userCancelled; },
            [=](uint64_t _bytes, uint64_t _total) {
                proc.progress = double(_bytes) / double(_total);
            });
        [proc Close];
        if( open_err != VFSError::Ok )
            return open_err;

        seq_wrapper = wrapper;
        work_file = wrapper;
    }
    else { // just open input file
        if( int open_err = original_file->Open(VFSFlags::OF_Read); open_err != VFSError::Ok )
            return open_err;
        work_file = original_file;
    }
    viewer_file_window = std::make_shared<nc::vfs::FileWindow>();
    if( int attach_err = viewer_file_window->Attach(work_file, _window_size);
        attach_err != VFSError::Ok )
        return attach_err;

    search_file_window = std::make_shared<nc::vfs::FileWindow>();
    if( int attach_err = search_file_window->Attach(work_file); attach_err != 0 )
        return attach_err;

    using nc::vfs::SearchInFile;
    search_in_file = std::make_shared<SearchInFile>(*search_file_window);

    const auto search_options = [&] {
        using Options = SearchInFile::Options;
        auto opts = Options::None;
        if( _config.GetBool(g_ConfigSearchCaseSensitive) )
            opts |= Options::CaseSensitive;
        if( _config.GetBool(g_ConfigSearchForWholePhrase) )
            opts |= Options::FindWholePhrase;
        return opts;
    }();
    search_in_file->SetSearchOptions(search_options);

    return VFSError::Ok;
}

}
