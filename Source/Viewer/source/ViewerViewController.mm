// Copyright (C) 2016-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ViewerViewController.h"
#include "ViewerFooter.h"
#include "ViewerSearchView.h"
#include <Viewer/Log.h>
#include <VFS/VFS.h>
#include <CUI/ProcessSheetController.h>
#include <Config/Config.h>
#include <VFS/SearchInFile.h>
#include <Utility/ByteCountFormatter.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <Utility/ActionsShortcutsManager.h>
#include "History.h"
#include <Base/SerialQueue.h>
#include "Internal.h"

using namespace std::literals;
using namespace nc;
using namespace nc::viewer;

static const auto g_ConfigRespectComAppleTextEncoding = "viewer.respectComAppleTextEncoding";
static const auto g_ConfigSearchCaseSensitive = "viewer.searchCaseSensitive";
static const auto g_ConfigSearchForWholePhrase = "viewer.searchForWholePhrase";
static const auto g_ConfigWindowSize = "viewer.fileWindowSize";
static const auto g_ConfigAutomaticRefresh = "viewer.automaticRefresh";
static const auto g_AutomaticRefreshDelay = std::chrono::milliseconds(200);

static utility::Encoding EncodingFromXAttr(const VFSFilePtr &_f)
{
    char buf[128];
    const ssize_t r = _f->XAttrGet("com.apple.TextEncoding", buf, sizeof(buf));
    if( r < 0 || r >= static_cast<ssize_t>(sizeof(buf)) )
        return utility::Encoding::ENCODING_INVALID;
    buf[r] = 0;
    return utility::FromComAppleTextEncodingXAttr(buf);
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
    std::expected<void, Error>
    Open(VFSHostPtr _vfs, const std::string &_path, const nc::config::Config &_config, int _window_size);

    VFSFilePtr original_file;
    VFSSeqToRandomROWrapperFilePtr seq_wrapper;
    VFSFilePtr work_file;
    std::shared_ptr<nc::vfs::FileWindow> viewer_file_window;
    std::shared_ptr<nc::vfs::FileWindow> search_file_window;
    std::shared_ptr<nc::vfs::SearchInFile> search_in_file;
};

} // namespace nc::viewer

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
    const nc::utility::ActionsShortcutsManager *m_Shortcuts;

    // UI
    NCViewerView *m_View;
    NSSearchField *m_SearchField;
    NSProgressIndicator *m_SearchProgressIndicator;
    NSString *m_VerboseTitle;
}

@synthesize view = m_View;
@synthesize verboseTitle = m_VerboseTitle;
@synthesize filePath = m_Path;
@synthesize fileVFS = m_VFS;
@synthesize goToPositionPopover;
@synthesize goToPositionValueTextField;
@synthesize goToPositionKindButton;

- (instancetype)initWithHistory:(nc::viewer::History &)_history
                         config:(nc::config::Config &)_config
                      shortcuts:(const nc::utility::ActionsShortcutsManager &)_shortcuts
{
    self = [super init];
    if( self ) {
        Log::Debug("created new NCViewerViewController {}", nc::objc_bridge_cast<void>(self));
        m_History = &_history;
        m_Config = &_config;
        m_Shortcuts = &_shortcuts;
        m_AutomaticFileRefreshScheduled = false;
        __weak NCViewerViewController *weak_self = self;
        m_SearchInFileQueue.SetOnChange(
            [=] { [static_cast<NCViewerViewController *>(weak_self) onSearchInFileQueueStateChanged]; });

        NSNib *mynib = [[NSNib alloc] initWithNibNamed:@"InternalViewerController" bundle:Bundle()];
        [mynib instantiateWithOwner:self topLevelObjects:nil];
    }
    return self;
}

- (void)dealloc
{
    dispatch_assert_main_queue();
    Log::Debug("deallocating NCViewerViewController {}", nc::objc_bridge_cast<void>(self));
    [m_View removeObserver:self forKeyPath:@"verticalPositionPercentage"];
    [m_View.footer removeObserver:self forKeyPath:@"mode"];
    [m_View.footer removeObserver:self forKeyPath:@"encoding"];
    [m_View.footer removeObserver:self forKeyPath:@"wrapLines"];
    [m_View.footer removeObserver:self forKeyPath:@"highlightingLanguage"];
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
    const std::expected<void, Error> open_err = opener.Open(m_VFS, m_Path, *m_Config, self.fileWindowSize);
    if( !open_err )
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
        m_FileObservationToken = m_VFS->ObserveFileChanges(m_Path, [weak_self] {
            if( NCViewerViewController *const strong_self = weak_self )
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
        const std::optional<std::string> language = options.language ? info->language : std::nullopt;
        if( options.encoding && options.mode ) {
            [m_View setKnownFile:m_ViewerFileWindow encoding:info->encoding mode:info->view_mode language:language];
        }
        else {
            [m_View setFile:m_ViewerFileWindow];
            if( options.encoding )
                m_View.encoding = info->encoding;
            if( options.mode )
                m_View.mode = info->view_mode;
        }
        // a bit suboptimal now - may re-layout after first one
        if( options.wrapping )
            m_View.wordWrap = info->wrapping;
        if( options.position )
            m_View.verticalPositionInBytes = info->position;
        if( options.selection )
            m_View.selectionInFile = info->selection;
        if( language )
            m_View.language = language.value();
    }
    else {
        [m_View setFile:m_ViewerFileWindow];
        if( m_Config->GetBool(g_ConfigRespectComAppleTextEncoding) ) {
            if( const utility::Encoding encoding = EncodingFromXAttr(m_OriginalFile);
                encoding != utility::Encoding::ENCODING_INVALID ) {
                m_View.encoding = encoding;
            }
        }
    }

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
    info.language = m_View.language;
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
    [m_View addObserver:self forKeyPath:@"verticalPositionPercentage" options:0 context:nullptr];
    [m_View.footer addObserver:self forKeyPath:@"mode" options:0 context:nullptr];
    [m_View.footer addObserver:self forKeyPath:@"encoding" options:0 context:nullptr];
    [m_View.footer addObserver:self forKeyPath:@"wrapLines" options:0 context:nullptr];
    [m_View.footer addObserver:self forKeyPath:@"highlightingLanguage" options:0 context:nullptr];
    m_View.footer.filePositionClickTarget = self;
    m_View.footer.filePositionClickAction = @selector(onPositionButtonClicked:);

    [self setSearchField:m_View.searchView.searchField];
    [self setSearchProgressIndicator:m_View.searchView.progressIndicator];
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
    cell.placeholderString =
        NSLocalizedString(@"Search in file", "Placeholder for search text field in internal viewer");
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
        m_View.searchView.hidden = true;
        return true;
    }
    return false;
}

- (NSMenu *)searchFieldMenu
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
    NSMenuItem *item;

    item = [[NSMenuItem alloc]
        initWithTitle:NSLocalizedString(@"Case-sensitive search", "Menu item option in internal viewer search")
               action:@selector(onSearchFieldMenuCaseSensitiveAction:)
        keyEquivalent:@""];
    item.state = m_Config->GetBool(g_ConfigSearchCaseSensitive);
    item.target = self;
    [menu insertItem:item atIndex:0];

    item = [[NSMenuItem alloc]
        initWithTitle:NSLocalizedString(@"Find whole phrase", "Menu item option in internal viewer search")
               action:@selector(onSearchFiledMenuWholePhraseSearch:)
        keyEquivalent:@""];
    item.state = m_Config->GetBool(g_ConfigSearchForWholePhrase);
    item.target = self;
    [menu insertItem:item atIndex:1];

    item = [[NSMenuItem alloc]
        initWithTitle:NSLocalizedString(@"Clear Recents", "Menu item title in internal viewer search")
               action:nullptr
        keyEquivalent:@""];
    item.tag = NSSearchFieldClearRecentsMenuItemTag;
    [menu insertItem:item atIndex:2];

    item = [NSMenuItem separatorItem];
    item.tag = NSSearchFieldRecentsTitleMenuItemTag;
    [menu insertItem:item atIndex:3];

    item = [[NSMenuItem alloc]
        initWithTitle:NSLocalizedString(@"Recent Searches", "Menu item title in internal viewer search")
               action:nullptr
        keyEquivalent:@""];
    item.tag = NSSearchFieldRecentsTitleMenuItemTag;
    [menu insertItem:item atIndex:4];

    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recents", "Menu item title in internal viewer search")
                                      action:nullptr
                               keyEquivalent:@""];
    item.tag = NSSearchFieldRecentsMenuItemTag;
    [menu insertItem:item atIndex:5];

    return menu;
}

- (IBAction)onMainMenuPerformFindAction:(id) [[maybe_unused]] _sender
{
    self.view.searchView.hidden = false;
    [self.view.window makeFirstResponder:m_SearchField];
}

- (IBAction)onMainMenuPerformFindNextAction:(id) [[maybe_unused]] _sender
{
    self.view.searchView.hidden = false;
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

    if( m_SearchInFile->TextSearchString() == nullptr ||
        [str compare:(__bridge NSString *)m_SearchInFile->TextSearchString()] != NSOrderedSame ||
        m_SearchInFile->TextSearchEncoding() != m_View.encoding ) {
        // user did some changes in search request
        m_View.selectionInFile = CFRangeMake(-1, 0); // remove current selection

        uint64_t view_offset = m_View.verticalPositionInBytes;
        utility::Encoding encoding = m_View.encoding;

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

        const auto result = m_SearchInFile->Search([self] { return m_SearchInFileQueue.IsStopped(); });

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
        dispatch_to_main_queue_after(100ms,
                                     [=] { // should be 100 ms of workload before user will get spinning indicator
                                         if( !m_SearchInFileQueue.Empty() ) // need to check if task was already done
                                             [m_SearchProgressIndicator startAnimation:self];
                                     });
}

- (void)onSearchFieldMenuCaseSensitiveAction:(id) [[maybe_unused]] _sender
{
    using nc::vfs::SearchInFile;
    using Options = SearchInFile::Options;
    const auto options = static_cast<Options>(
        InvertBitFlag(static_cast<int>(m_SearchInFile->SearchOptions()), static_cast<int>(Options::CaseSensitive)));
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
    const auto options = static_cast<Options>(
        InvertBitFlag(static_cast<int>(m_SearchInFile->SearchOptions()), static_cast<int>(Options::FindWholePhrase)));
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
}

- (void)onPositionButtonClicked:(id)_sender
{
    [self.goToPositionPopover showRelativeToRect:nc::objc_cast<NSView>(_sender).bounds
                                          ofView:nc::objc_cast<NSView>(_sender)
                                   preferredEdge:/*NSMaxYEdge*/ NSMinYEdge];
}

- (void)popoverWillShow:(NSNotification *) [[maybe_unused]] _notification
{
    [self.goToPositionValueTextField.window setInitialFirstResponder:self.goToPositionValueTextField];
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

- (void)buildTitle
{
    NSString *path = [NSString stringWithUTF8StdString:m_GlobalFilePath];
    if( path == nil )
        path = @"...";
    NSString *title =
        [NSString stringWithFormat:NSLocalizedString(@"File View - %@", "Window title for internal file viewer"), path];

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

    if( _selection.location + _selection.length < static_cast<int64_t>(m_SearchFileWindow->FileSize()) )
        m_SearchInFile->MoveCurrentPosition(_selection.location + _selection.length);
    else
        m_SearchInFile->MoveCurrentPosition(0);
    m_SearchInFile->ToggleTextSearch((__bridge CFStringRef)search_request, m_View.encoding);
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
}

- (void)onRefresh
{
    Log::Debug("refresh called");
    __weak NCViewerViewController *weak_self = self;
    dispatch_to_background([weak_self] {
        NCViewerViewController *const strong_self = weak_self;
        if( !strong_self )
            return;

        auto opener = std::make_unique<BackgroundFileOpener>();
        const std::expected<void, Error> open_rc =
            opener->Open(strong_self->m_VFS, strong_self->m_Path, *strong_self->m_Config, strong_self.fileWindowSize);
        if( !open_rc ) {
            Log::Warn("failed to open a path {}, vfs_error: {}", strong_self->m_Path, open_rc.error());
            return;
        }

        dispatch_to_main_queue([weak_self, opener = std::move(opener)] {
            NCViewerViewController *const strong_self = weak_self;
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
    dispatch_to_main_queue_after(g_AutomaticRefreshDelay, [weak_self] {
        if( NCViewerViewController *const strong_self = weak_self ) {
            strong_self->m_AutomaticFileRefreshScheduled = false;
            [strong_self onRefresh];
        }
    });
}

- (BOOL)performKeyEquivalent:(NSEvent *)_event
{
    struct Tags {
        int toggle_text;
        int toggle_hex;
        int toggle_preview;
        int show_goto;
        int refresh;
    };
    static const Tags tags = [&] {
        Tags t;
        t.toggle_text = m_Shortcuts->TagFromAction("viewer.toggle_text").value();
        t.toggle_hex = m_Shortcuts->TagFromAction("viewer.toggle_hex").value();
        t.toggle_preview = m_Shortcuts->TagFromAction("viewer.toggle_preview").value();
        t.show_goto = m_Shortcuts->TagFromAction("viewer.show_goto").value();
        t.refresh = m_Shortcuts->TagFromAction("viewer.refresh").value();
        return t;
    }();

    const auto event_shortcut = nc::utility::ActionShortcut(nc::utility::ActionShortcut::EventData(_event));
    const std::optional<int> event_action_tag = m_Shortcuts->FirstOfActionTagsFromShortcut(
        {reinterpret_cast<const int *>(&tags), sizeof(tags) / sizeof(int)}, event_shortcut, "viewer.");

    if( event_action_tag == tags.toggle_text ) {
        [m_View setMode:ViewMode::Text];
        return true;
    }
    if( event_action_tag == tags.toggle_hex ) {
        [m_View setMode:ViewMode::Hex];
        return true;
    }
    if( event_action_tag == tags.toggle_preview ) {
        [m_View setMode:ViewMode::Preview];
        return true;
    }
    if( event_action_tag == tags.show_goto ) {
        [m_View.footer performFilePositionClick:self];
        return true;
    }
    if( event_action_tag == tags.refresh ) {
        [self onRefresh];
        return true;
    }
    return false;
}

- (void)observeValueForKeyPath:(NSString *)_key_path
                      ofObject:(id)_object
                        change:(NSDictionary *) [[maybe_unused]] _change
                       context:(void *) [[maybe_unused]] _context
{
    dispatch_assert_main_queue();
    if( _object == m_View.footer ) {
        if( [_key_path isEqualToString:@"mode"] ) {
            m_View.mode = m_View.footer.mode;
        }
        if( [_key_path isEqualToString:@"encoding"] ) {
            m_View.encoding = m_View.footer.encoding;
        }
        if( [_key_path isEqualToString:@"wrapLines"] ) {
            m_View.wordWrap = m_View.footer.wrapLines;
        }
        if( [_key_path isEqualToString:@"highlightingLanguage"] ) {
            m_View.language = m_View.footer.highlightingLanguage;
        }
    }
    else if( _object == m_View ) {
        if( [_key_path isEqualToString:@"verticalPositionPercentage"] ) {
            m_View.footer.filePosition =
                [NSString stringWithFormat:@"%2.0f%%", 100.0 * m_View.verticalPositionPercentage];
        }
    }
}

@end

namespace nc::viewer {

std::expected<void, Error> BackgroundFileOpener::Open(VFSHostPtr _vfs,
                                                      const std::string &_path,
                                                      const nc::config::Config &_config,
                                                      int _window_size)
{
    dispatch_assert_background_queue();
    assert(_vfs);
    if( const std::expected<std::shared_ptr<VFSFile>, Error> exp = _vfs->CreateFile(_path); exp )
        original_file = *exp;
    else
        return std::unexpected(exp.error());

    if( original_file->GetReadParadigm() < VFSFile::ReadParadigm::Random ) {
        // we need to read a file into temporary mem/file storage to access it randomly
        ProcessSheetController *const proc = [ProcessSheetController new];
        proc.title = NSLocalizedString(@"Opening file...", "Title for process sheet when opening a vfs file");
        [proc Show];

        auto wrapper = std::make_shared<VFSSeqToRandomROWrapperFile>(original_file);
        const int open_err = wrapper->Open(
            VFSFlags::OF_Read | VFSFlags::OF_ShLock,
            [=] { return proc.userCancelled; },
            [=](uint64_t _bytes, uint64_t _total) { proc.progress = double(_bytes) / double(_total); });
        [proc Close];
        if( open_err != VFSError::Ok )
            return std::unexpected(VFSError::ToError(open_err));

        seq_wrapper = wrapper;
        work_file = wrapper;
    }
    else { // just open input file
        if( const int open_err = original_file->Open(VFSFlags::OF_Read); open_err != VFSError::Ok )
            return std::unexpected(VFSError::ToError(open_err));
        work_file = original_file;
    }
    viewer_file_window = std::make_shared<nc::vfs::FileWindow>();
    if( const std::expected<void, Error> res = viewer_file_window->Attach(work_file, _window_size); !res )
        return std::unexpected(res.error());

    search_file_window = std::make_shared<nc::vfs::FileWindow>();
    if( const std::expected<void, Error> res = search_file_window->Attach(work_file); !res )
        return std::unexpected(res.error());

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

    return {};
}

} // namespace nc::viewer
