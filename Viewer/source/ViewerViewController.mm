// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ViewerViewController.h"
#include <VFS/VFS.h>
#include <CUI/ProcessSheetController.h>
#include <Config/Config.h>
#include <VFS/SearchInFile.h>
#include <Utility/ByteCountFormatter.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <Utility/ActionShortcut.h>
#include "History.h"
#include <Habanero/SerialQueue.h>
#include "Internal.h"

using namespace std::literals;
using namespace nc::viewer;

static const auto g_ConfigRespectComAppleTextEncoding   = "viewer.respectComAppleTextEncoding";
static const auto g_ConfigSearchCaseSensitive           = "viewer.searchCaseSensitive";
static const auto g_ConfigSearchForWholePhrase          = "viewer.searchForWholePhrase";
static const auto g_ConfigWindowSize                    = "viewer.fileWindowSize";

static int EncodingFromXAttr(const VFSFilePtr &_f)
{
    char buf[128];
    ssize_t r = _f->XAttrGet("com.apple.TextEncoding", buf, sizeof(buf));
    if(r < 0 || r >= (ssize_t)sizeof(buf))
        return encodings::ENCODING_INVALID;
    buf[r] = 0;
    return encodings::FromComAppleTextEncodingXAttr(buf);
}

static int InvertBitFlag( int _value, int _flag )
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
    if( auto number = objc_cast<NSNumber>(value) )
        return [NSString stringWithFormat:@"%2.0f%%", 100.0 * number.doubleValue];
    else
        return @"";
}
@end

@interface NCViewerViewController()

@property (nonatomic) IBOutlet NSPopover *goToPositionPopover;
@property (nonatomic) IBOutlet NSTextField *goToPositionValueTextField;
@property (nonatomic) IBOutlet NSString *goToPositionValueTextFieldValue;
@property (nonatomic) IBOutlet NSPopUpButton *goToPositionKindButton;

@end

@implementation NCViewerViewController
{
    std::string                     m_Path;
    std::string                     m_GlobalFilePath;
    VFSHostPtr                      m_VFS;
    VFSFilePtr                      m_OriginalFile; // may be not opened if SeqWrapper is used
    VFSSeqToRandomROWrapperFilePtr  m_SeqWrapper; // may be nullptr if underlying VFS supports ReadAt
    VFSFilePtr                      m_WorkFile; // the one actually used
    std::unique_ptr<nc::vfs::FileWindow> m_ViewerFileWindow;
    std::unique_ptr<nc::vfs::FileWindow> m_SearchFileWindow;
    std::unique_ptr<nc::vfs::SearchInFile> m_SearchInFile;
    SerialQueue                     m_SearchInFileQueue;
    nc::viewer::History            *m_History;
    nc::config::Config             *m_Config;
    std::function<nc::utility::ActionShortcut(const std::string &_name)> m_Shortcuts;
    
    // UI
    NCViewerView                    *m_View;
    NSSearchField                  *m_SearchField;
    NSProgressIndicator            *m_SearchProgressIndicator;
    NSPopUpButton                  *m_EncodingsPopUp;
    NSPopUpButton                  *m_ModePopUp;
    NSButton                       *m_PositionButton;
    NSTextField                    *m_FileSizeLabel;
    NSString                       *m_VerboseTitle;
    NSButton                       *m_WordWrappingCheckBox;
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

- (instancetype) initWithHistory:(nc::viewer::History&)_history
                          config:(nc::config::Config&)_config
               shortcutsProvider:(std::function<nc::utility::ActionShortcut(const std::string &_name)>)_shortcuts
{
    self = [super init];
    if( self ) {
        m_History = &_history;
        m_Config = &_config;
        m_Shortcuts = _shortcuts;
        __weak NCViewerViewController* weak_self = self;
        m_SearchInFileQueue.SetOnChange([=]{
            [(NCViewerViewController*)weak_self onSearchInFileQueueStateChanged];
        });
        
        NSNib *mynib = [[NSNib alloc]
                        initWithNibNamed:@"InternalViewerController"
                        bundle:[NSBundle bundleForClass:NCViewerViewController.class]];
        [mynib instantiateWithOwner:self topLevelObjects:nil];
    }
    return self;
}

- (void) dealloc
{
    dispatch_assert_main_queue();
    [self clear];
}

- (void) clear
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
}

- (void) setFile:(std::string)path at:(VFSHostPtr)vfs
{
//    dispatch_assert_main_queue();
    // current state checking?
    
    if( path.empty() || !vfs )
        throw std::logic_error("invalid args for - (void) setFile:(string)path at:(VFSHostPtr)vfs");
    
    m_Path = path;
    m_VFS = vfs;
}


- (bool) performBackgroundOpening
{
    dispatch_assert_background_queue();
    
    VFSFilePtr origin_file;
    if( m_VFS->CreateFile(m_Path.c_str(), origin_file, 0) < 0 )
        return false;
    
    VFSFilePtr work_file;
    if( origin_file->GetReadParadigm() < VFSFile::ReadParadigm::Random ) {
        // we need to read a file into temporary mem/file storage to access it randomly
        ProcessSheetController *proc = [ProcessSheetController new];
        proc.title = NSLocalizedString(@"Opening file...", "Title for process sheet when opening a vfs file");
        [proc Show];
        
        auto wrapper = std::make_shared<VFSSeqToRandomROWrapperFile>(origin_file);
        int res = wrapper->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock,
                                [=]{ return proc.userCancelled; },
                                [=](uint64_t _bytes, uint64_t _total) {
                                    proc.progress = double(_bytes) / double(_total);
                                });
        [proc Close];
        if(res != 0)
            return false;
        
        m_SeqWrapper = wrapper;
        work_file = wrapper;
    }
    else { // just open input file
        if( origin_file->Open(VFSFlags::OF_Read) < 0 )
            return false;
        work_file = origin_file;
    }
    m_OriginalFile = origin_file;
    m_WorkFile = work_file;
    m_GlobalFilePath = work_file->ComposeVerbosePath();
    
    auto window = std::make_unique<nc::vfs::FileWindow>();
    if( window->Attach(work_file, [self fileWindowSize]) != 0 )
        return false;
    m_ViewerFileWindow = std::move(window);
    
    window = std::make_unique<nc::vfs::FileWindow>();
    if( window->Attach(work_file) != 0 )
        return false;
    m_SearchFileWindow = move(window);
    
    using nc::vfs::SearchInFile;
    m_SearchInFile = std::make_unique<SearchInFile>(*m_SearchFileWindow);
    
    const auto search_options = [&]{
        using Options = SearchInFile::Options;
        auto opts = Options::None;
        if( m_Config->GetBool(g_ConfigSearchCaseSensitive) ) opts |= Options::CaseSensitive;
        if( m_Config->GetBool(g_ConfigSearchForWholePhrase) ) opts |= Options::FindWholePhrase;
        return opts;
    }();
    m_SearchInFile->SetSearchOptions( search_options );
    
    [self buildTitle];
    
    return true;
    
}

- (bool) performSyncOpening
{
    dispatch_assert_main_queue();
    VFSFilePtr origin_file;
    if( m_VFS->CreateFile(m_Path.c_str(), origin_file, 0) < 0 )
        return false;
    
    VFSFilePtr work_file;
    if( origin_file->GetReadParadigm() < VFSFile::ReadParadigm::Random ) {
        // we need to read a file into temporary mem/file storage to access it randomly
        ProcessSheetController *proc = [ProcessSheetController new];
        proc.title = NSLocalizedString(@"Opening file...", "Title for process sheet when opening a vfs file");
        [proc Show];
        
        auto wrapper = std::make_shared<VFSSeqToRandomROWrapperFile>(origin_file);
        int res = wrapper->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock,
                                [=]{ return proc.userCancelled; },
                                [=](uint64_t _bytes, uint64_t _total) {
                                    proc.progress = double(_bytes) / double(_total);
                                });
        [proc Close];
        if(res != 0)
            return false;
        
        m_SeqWrapper = wrapper;
        work_file = wrapper;
    }
    else { // just open input file
        if( origin_file->Open(VFSFlags::OF_Read) < 0 )
            return false;
        work_file = origin_file;
    }
    m_OriginalFile = origin_file;
    m_WorkFile = work_file;
    m_GlobalFilePath = work_file->ComposeVerbosePath();
    
    auto window = std::make_unique<nc::vfs::FileWindow>();
    if( window->Attach(work_file, [self fileWindowSize]) != 0 )
        return false;
    m_ViewerFileWindow = move(window);
    
    window = std::make_unique<nc::vfs::FileWindow>();
    if( window->Attach(work_file) != 0 )
        return false;
    m_SearchFileWindow = move(window);
    
    using nc::vfs::SearchInFile;
    m_SearchInFile = std::make_unique<SearchInFile>(*m_SearchFileWindow);
    
    const auto search_options = [&]{
        using Options = SearchInFile::Options;
        auto opts = Options::None;
        if( m_Config->GetBool(g_ConfigSearchCaseSensitive) ) opts |= Options::CaseSensitive;
        if( m_Config->GetBool(g_ConfigSearchForWholePhrase) ) opts |= Options::FindWholePhrase;
        return opts;
    }();
    m_SearchInFile->SetSearchOptions( search_options );
    
    [self buildTitle];
    
    return true;
    
}

- (void) show
{
    dispatch_assert_main_queue();
    assert(self.view != nil );
    
    // try to load a saved info if any
    if( auto info = m_History->EntryByPath(m_GlobalFilePath) ) {
        auto options = m_History->Options();
        if( options.encoding && options.mode ) {
            [m_View SetKnownFile:m_ViewerFileWindow.get() encoding:info->encoding mode:info->view_mode];
        }
        else {
            [m_View SetFile:m_ViewerFileWindow.get()];
            if( options.encoding )  m_View.encoding = info->encoding;
            if( options.mode )      m_View.mode = info->view_mode;
        }
        // a bit suboptimal no - may re-layout after first one
        if( options.wrapping )      m_View.wordWrap = info->wrapping;
        if( options.position )      m_View.verticalPositionInBytes = info->position;
        if( options.selection )     m_View.selectionInFile = info->selection;
    }
    else {
        [m_View SetFile:m_ViewerFileWindow.get()];
        int encoding = 0;
        if( m_Config->GetBool(g_ConfigRespectComAppleTextEncoding) &&
           (encoding = EncodingFromXAttr(m_OriginalFile)) != encodings::ENCODING_INVALID )
            m_View.encoding = encoding;
    }
    
    m_FileSizeLabel.stringValue =
        ByteCountFormatter::Instance().ToNSString(m_ViewerFileWindow->FileSize(),
                                                  ByteCountFormatter::Fixed6);
    
    m_View.hotkeyDelegate = self;
}

- (void) saveFileState
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
    m_History->AddEntry( std::move(info) );
}

- (unsigned) fileWindowSize
{
    unsigned file_window_size = nc::vfs::FileWindow::DefaultWindowSize;
    unsigned file_window_pow2x = m_Config->GetInt(g_ConfigWindowSize);
    if( file_window_pow2x <= 5 )
        file_window_size *= 1 << file_window_pow2x;
    return file_window_size;
}

- (void) setView:(NCViewerView *)view
{
    if( m_View == view )
        return;
    
    m_View = view;
}

- (void) setSearchField:(NSSearchField *)searchField
{
    if( m_SearchField == searchField )
        return;
    
    m_SearchField = searchField;
    m_SearchField.target = self;
    m_SearchField.action = @selector(onSearchFieldAction:);
    m_SearchField.delegate = self;
    ((NSSearchFieldCell*)m_SearchField.cell).placeholderString = NSLocalizedString(@"Search in file", "Placeholder for search text field in internal viewer");
    ((NSSearchFieldCell*)m_SearchField.cell).sendsWholeSearchString = true;
    ((NSSearchFieldCell*)m_SearchField.cell).recentsAutosaveName = @"BigFileViewRecentSearches";
    ((NSSearchFieldCell*)m_SearchField.cell).maximumRecents = 20;
    ((NSSearchFieldCell*)m_SearchField.cell).searchMenuTemplate = self.searchFieldMenu;
}

- (BOOL)control:(NSControl *)control
       textView:(NSTextView *)[[maybe_unused]]_text_view
doCommandBySelector:(SEL)commandSelector
{
    if( control == m_SearchField && commandSelector == @selector(cancelOperation:) ) {
        [m_View.window makeFirstResponder:m_View.keyboardResponder];
        return true;
    }
    return false;
}

- (NSMenu*) searchFieldMenu
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
    NSMenuItem *item;
    
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Case-sensitive search", "Menu item option in internal viewer search")
                                      action:@selector(onSearchFieldMenuCaseSensitiveAction:)
                               keyEquivalent:@""];
    item.state = m_Config->GetBool(g_ConfigSearchCaseSensitive);
    item.target = self;
    [menu insertItem:item atIndex:0];
    
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Find whole phrase", "Menu item option in internal viewer search")
                                      action:@selector(onSearchFiledMenuWholePhraseSearch:)
                               keyEquivalent:@""];
    item.state = m_Config->GetBool(g_ConfigSearchForWholePhrase);
    item.target = self;
    [menu insertItem:item atIndex:1];
    
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Clear Recents", "Menu item title in internal viewer search")
                                      action:NULL
                               keyEquivalent:@""];
    item.tag = NSSearchFieldClearRecentsMenuItemTag;
    [menu insertItem:item atIndex:2];
    
    item = [NSMenuItem separatorItem];
    item.tag = NSSearchFieldRecentsTitleMenuItemTag;
    [menu insertItem:item atIndex:3];
    
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recent Searches", "Menu item title in internal viewer search")
                                      action:NULL
                               keyEquivalent:@""];
    item.tag = NSSearchFieldRecentsTitleMenuItemTag;
    [menu insertItem:item atIndex:4];
    
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Recents", "Menu item title in internal viewer search")
                                      action:NULL
                               keyEquivalent:@""];
    item.tag = NSSearchFieldRecentsMenuItemTag;
    [menu insertItem:item atIndex:5];
    
    return menu;
}

- (IBAction)onMainMenuPerformFindAction:(id)[[maybe_unused]]_sender
{
    [self.view.window makeFirstResponder:m_SearchField];
}

- (IBAction)onMainMenuPerformFindNextAction:(id)[[maybe_unused]]_sender
{
    [self onSearchFieldAction:self];
}

- (void)onSearchFieldAction:(id)[[maybe_unused]]_sender
{
    NSString *str = m_SearchField.stringValue;
    if( str.length == 0 ) {
        m_SearchInFileQueue.Stop(); // we should stop current search if any
        m_View.selectionInFile = CFRangeMake(-1, 0);
        return;
    }
    
    if( m_SearchInFile->TextSearchString() == NULL ||
       [str compare:(__bridge NSString*) m_SearchInFile->TextSearchString()] != NSOrderedSame ||
       m_SearchInFile->TextSearchEncoding() != m_View.encoding ) {
        // user did some changes in search request
        m_View.selectionInFile = CFRangeMake(-1, 0); // remove current selection
        
        uint64_t view_offset = m_View.verticalPositionInBytes;
        int encoding = m_View.encoding;
        
        m_SearchInFileQueue.Stop(); // we should stop current search if any
        m_SearchInFileQueue.Wait();
        m_SearchInFileQueue.Run([=]{
            m_SearchInFile->MoveCurrentPosition(view_offset);
            m_SearchInFile->ToggleTextSearch((__bridge CFStringRef)str, encoding);
        });
    }
    else {
        // request is the same
        if(!m_SearchInFileQueue.Empty())
            return; // we're already performing this request now, nothing to do
    }
    
    m_SearchInFileQueue.Run([=]{
        
        if( m_SearchInFile->IsEOF() )
            m_SearchInFile->MoveCurrentPosition(0);
        
        const auto result = m_SearchInFile->Search
            ([self]{return m_SearchInFileQueue.IsStopped();});
        
        if( result.response == nc::vfs::SearchInFile::Response::Found ) {
            const auto range = CFRangeMake(result.location->offset, result.location->bytes_len);
            dispatch_to_main_queue( [=]{
                m_View.selectionInFile = range;
                [m_View scrollToSelection];
            });
        }
    });
}

- (void) onSearchInFileQueueStateChanged
{
    if( m_SearchInFileQueue.Empty() )
        dispatch_to_main_queue([=]{
            [m_SearchProgressIndicator stopAnimation:self];
        });
    else
        dispatch_to_main_queue_after(100ms, [=]{ // should be 100 ms of workload before user will get spinning indicator
            if( !m_SearchInFileQueue.Empty() ) // need to check if task was already done
                [m_SearchProgressIndicator startAnimation:self];
        });
}



- (void)onSearchFieldMenuCaseSensitiveAction:(id)[[maybe_unused]]_sender
{
    using nc::vfs::SearchInFile;
    using Options = SearchInFile::Options;
    const auto options = (Options)InvertBitFlag( (int)m_SearchInFile->SearchOptions(),
                                                 (int)Options::CaseSensitive );
    m_SearchInFile->SetSearchOptions(options);
    
    NSMenu* menu = ((NSSearchFieldCell*)m_SearchField.cell).searchMenuTemplate;
    [menu itemAtIndex:0].state = (options & Options::CaseSensitive) != Options::None;
    ((NSSearchFieldCell*)m_SearchField.cell).searchMenuTemplate = menu;
    m_Config->Set( g_ConfigSearchCaseSensitive, bool(options & Options::CaseSensitive) );
}

- (void)onSearchFiledMenuWholePhraseSearch:(id)[[maybe_unused]]_sender
{
    using nc::vfs::SearchInFile;
    using Options = SearchInFile::Options;
    const auto options = (Options)InvertBitFlag( (int)m_SearchInFile->SearchOptions(),
                                                 (int)Options::FindWholePhrase );
    m_SearchInFile->SetSearchOptions(options);
    
    NSMenu* menu = ((NSSearchFieldCell*)m_SearchField.cell).searchMenuTemplate;
    [menu itemAtIndex:1].state = (options & Options::FindWholePhrase) != Options::None;
    ((NSSearchFieldCell*)m_SearchField.cell).searchMenuTemplate = menu;
    m_Config->Set( g_ConfigSearchForWholePhrase, bool(options & Options::FindWholePhrase) );
}

- (void)setSearchProgressIndicator:(NSProgressIndicator *)searchProgressIndicator
{
    dispatch_assert_main_queue();
    if( m_SearchProgressIndicator == searchProgressIndicator )
        return;

    m_SearchProgressIndicator = searchProgressIndicator;
    m_SearchProgressIndicator.indeterminate = true;
    m_SearchProgressIndicator.style = NSProgressIndicatorSpinningStyle;
    m_SearchProgressIndicator.displayedWhenStopped = false;
}

- (void)setEncodingsPopUp:(NSPopUpButton *)encodingsPopUp
{
    dispatch_assert_main_queue();
    assert( m_View != nil );
    if( m_EncodingsPopUp == encodingsPopUp )
        return;
    m_EncodingsPopUp = encodingsPopUp;
    m_EncodingsPopUp.target = self;
    m_EncodingsPopUp.action = @selector(onEncodingsPopUpChanged:);
    [m_EncodingsPopUp removeAllItems];
    for( const auto &i: encodings::LiteralEncodingsList() ) {
        [m_EncodingsPopUp addItemWithTitle: (__bridge NSString*)i.second];
        m_EncodingsPopUp.lastItem.tag = i.first;
    }
    [m_EncodingsPopUp bind:@"selectedTag" toObject:m_View withKeyPath:@"encoding" options:nil];
}

- (void)onEncodingsPopUpChanged:(id)[[maybe_unused]]_sender
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
    m_ModePopUp.lastItem.tag = (int)ViewMode::Text;
    [m_ModePopUp addItemWithTitle:@"Hex"];
    m_ModePopUp.lastItem.tag = (int)ViewMode::Hex;
    [m_ModePopUp addItemWithTitle:@"Preview"];
    m_ModePopUp.lastItem.tag = (int)ViewMode::Preview;
    [m_ModePopUp bind:@"selectedTag" toObject:m_View withKeyPath:@"mode" options:nil];
}

- (void)onModePopUpChanged:(id)[[maybe_unused]]_sender
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
    [m_PositionButton bind:@"title"
                  toObject:m_View
               withKeyPath:@"verticalPositionPercentage"
                   options:@{NSValueTransformerBindingOption:[NCViewerVerticalPostionToStringTransformer new]}];
}

- (void)onPositionButtonClicked:(id)sender
{
    [self.goToPositionPopover showRelativeToRect:objc_cast<NSButton>(sender).bounds
                                          ofView:objc_cast<NSButton>(sender)
                                   preferredEdge:NSMaxYEdge];
}

- (void)popoverWillShow:(NSNotification *)[[maybe_unused]]_notification
{
    [self.goToPositionValueTextField.window setInitialFirstResponder:self.goToPositionValueTextField];
    [self.goToPositionValueTextField.window makeFirstResponder:self.goToPositionValueTextField];
}

- (IBAction)onGoToPositionActionClicked:(id)[[maybe_unused]]_sender
{
    [self.goToPositionPopover close];
    const auto string = self.goToPositionValueTextFieldValue;
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

- (void) buildTitle
{
    NSString *path = [NSString stringWithUTF8StdString:m_GlobalFilePath];
    if( path == nil )
        path = @"...";
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"File View - %@", "Window title for internal file viewer"), path];
    
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
    
    if( _selection.location + _selection.length < (int64_t)m_SearchFileWindow->FileSize() )
        m_SearchInFile->MoveCurrentPosition( _selection.location + _selection.length );
    else
        m_SearchInFile->MoveCurrentPosition( 0 );
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

- (bool) isOpened
{
    return m_WorkFile != nullptr;
}

- (BOOL)performKeyEquivalent:(NSEvent *)_event
{
    if( const auto chars = [_event charactersIgnoringModifiers]; chars.length == 1 ) {
        const auto unicode = [chars characterAtIndex:0];
        const auto modifiers = [_event modifierFlags];
        const auto is = [&](const std::string &_action_name) {
            return m_Shortcuts(_action_name).IsKeyDown(unicode, modifiers);
        };
        if( is( "viewer.toggle_text" ) ) {
            [m_View setMode:ViewMode::Text];
            return true;
        }
        if( is( "viewer.toggle_hex" ) ) {
            [m_View setMode:ViewMode::Hex];
            return true;
        }        
        if( is( "viewer.toggle_preview" ) ) {
            [m_View setMode:ViewMode::Preview];
            return true;
        }
        if( is( "viewer.show_settings" ) ) {
            [self.settingsButton performClick:self];
            return true;
        }
        if( is( "viewer.show_goto") ) {
            [self.positionButton performClick:self];
            return true;
        }        
    }
    return false;
}

@end
