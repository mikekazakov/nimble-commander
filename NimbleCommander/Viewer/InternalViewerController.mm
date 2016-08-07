#include "../../Files/vfs/VFS.h"
#include "../../Files/ProcessSheetController.h"
#include "../../Files/Config.h"
#include "../../Files/SearchInFile.h"
#include "InternalViewerController.h"

static const auto g_ConfigSearchCaseSensitive           = "viewer.searchCaseSensitive";
static const auto g_ConfigSearchForWholePhrase          = "viewer.searchForWholePhrase";
static const auto g_ConfigWindowSize                    = "viewer.fileWindowSize";

@interface InternalViewerControllerVerticalPostionToStringTransformer : NSValueTransformer
@end
@implementation InternalViewerControllerVerticalPostionToStringTransformer
+ (Class)transformedValueClass
{
    return NSString.class;
}
- (id)transformedValue:(id)value
{
    return value ? [NSString stringWithFormat:@"%2.0f%%", 100.0 * objc_cast<NSNumber>(value).doubleValue] : @"";
}
@end

@implementation InternalViewerController
{
    string                          m_Path;
    VFSHostPtr                      m_VFS;
    VFSFilePtr                      m_OriginalFile; // may be not opened if SeqWrapper is used
    VFSSeqToRandomROWrapperFilePtr  m_SeqWrapper; // may be nullptr if underlying VFS supports ReadAt
    VFSFilePtr                      m_WorkFile; // the one actually used
    unique_ptr<FileWindow>          m_ViewerFileWindow;
    unique_ptr<FileWindow>          m_SearchFileWindow;
    unique_ptr<SearchInFile>        m_SearchInFile;
    SerialQueue                     m_SearchInFileQueue;
    
    // UI
    BigFileView                    *m_View;
    NSSearchField                  *m_SearchField;
    NSProgressIndicator            *m_SearchProgressIndicator;
    NSPopUpButton                  *m_EncodingsPopUp;
    NSPopUpButton                  *m_ModePopUp;
    NSButton                       *m_PositionButton;
}

@synthesize view = m_View;
@synthesize searchField = m_SearchField;
@synthesize searchProgressIndicator = m_SearchProgressIndicator;
@synthesize encodingsPopUp = m_EncodingsPopUp;
@synthesize modePopUp = m_ModePopUp;
@synthesize positionButton = m_PositionButton;

- (id) init
{
    self = [super init];
    if( self ) {
        m_SearchInFileQueue = make_shared<SerialQueueT>();
        __weak InternalViewerController* weak_self = self;
        m_SearchInFileQueue->OnChange([=]{ [(InternalViewerController*)weak_self onSearchInFileQueueStateChanged]; });
    }
    return self;
}

- (void) setFile:(string)path at:(VFSHostPtr)vfs
{
//    dispatch_assert_main_queue();
    // current state checking?
    
    if( path.empty() || !vfs )
        throw logic_error("invalid args for - (void) setFile:(string)path at:(VFSHostPtr)vfs");
    
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
        
        auto wrapper = make_shared<VFSSeqToRandomROWrapperFile>(origin_file);
        int res = wrapper->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock,
                                [=]{ return proc.userCancelled; },
                                [=](uint64_t _bytes, uint64_t _total) {
                                    proc.Progress.doubleValue = double(_bytes) / double(_total);
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
    
    
    auto window = make_unique<FileWindow>();
    if( window->OpenFile(work_file, InternalViewerController.fileWindowSize) != 0 )
        return false;
    m_ViewerFileWindow = move(window);
    
    window = make_unique<FileWindow>();
    if( window->OpenFile(work_file) != 0 )
        return false;
    m_SearchFileWindow = move(window);
    
    m_SearchInFile = make_unique<SearchInFile>(*m_SearchFileWindow);
    m_SearchInFile->SetSearchOptions((GlobalConfig().GetBool(g_ConfigSearchCaseSensitive)  ? SearchInFile::OptionCaseSensitive   : 0) |
                                     (GlobalConfig().GetBool(g_ConfigSearchForWholePhrase) ? SearchInFile::OptionFindWholePhrase : 0) );
    
    
    return true;
    
}

- (void) show
{
    dispatch_assert_main_queue();
    assert(self.view != nil );
    
    [self.view SetFile:m_ViewerFileWindow.get()];
}

+ (unsigned) fileWindowSize
{
    unsigned file_window_size = FileWindow::DefaultWindowSize;
    unsigned file_window_pow2x = GlobalConfig().GetInt(g_ConfigWindowSize);
    if( file_window_pow2x <= 5 )
        file_window_size *= 1 << file_window_pow2x;
    return file_window_size;
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

- (NSMenu*) searchFieldMenu
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
    NSMenuItem *item;
    
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Case-sensitive search", "Menu item option in internal viewer search")
                                      action:@selector(onSearchFieldMenuCaseSensitiveAction:)
                               keyEquivalent:@""];
    item.state = GlobalConfig().GetBool(g_ConfigSearchCaseSensitive);
    item.target = self;
    [menu insertItem:item atIndex:0];
    
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Find whole phrase", "Menu item option in internal viewer search")
                                      action:@selector(onSearchFiledMenuWholePhraseSearch:)
                               keyEquivalent:@""];
    item.state = GlobalConfig().GetBool(g_ConfigSearchForWholePhrase);
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

- (void)onSearchFieldAction:(id)sender
{
    NSString *str = m_SearchField.stringValue;
    if( str.length == 0 ) {
        m_SearchInFileQueue->Stop(); // we should stop current search if any
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
        
        m_SearchInFileQueue->Stop(); // we should stop current search if any
        m_SearchInFileQueue->Wait();
        m_SearchInFileQueue->Run([=]{
            m_SearchInFile->MoveCurrentPosition(view_offset);
            m_SearchInFile->ToggleTextSearch((__bridge CFStringRef)str, encoding);
        });
    }
    else {
        // request is the same
        if(!m_SearchInFileQueue->Empty())
            return; // we're already performing this request now, nothing to do
    }
    
    m_SearchInFileQueue->Run([=]{
        uint64_t offset, len;
        
        if( m_SearchInFile->IsEOF() )
            m_SearchInFile->MoveCurrentPosition(0);
        
        auto result = m_SearchInFile->Search(&offset, &len, ^{return m_SearchInFileQueue->IsStopped();});
        
        if(result == SearchInFile::Result::Found)
            dispatch_to_main_queue( [=]{
                m_View.selectionInFile = CFRangeMake(offset, len);
                [m_View ScrollToSelection];
            });
    });
}

- (void) onSearchInFileQueueStateChanged
{
    if( m_SearchInFileQueue->Empty() )
        dispatch_to_main_queue([=]{
            [m_SearchProgressIndicator stopAnimation:self];
        });
    else
        dispatch_to_main_queue_after(100ms, [=]{ // should be 100 ms of workload before user will get spinning indicator
            if( !m_SearchInFileQueue->Empty() ) // need to check if task was already done
                [m_SearchProgressIndicator startAnimation:self];
        });
}



- (void)onSearchFieldMenuCaseSensitiveAction:(id)sender
{
    
}

- (void)onSearchFiledMenuWholePhraseSearch:(id)sender
{
    
    
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

- (void)onEncodingsPopUpChanged:(id)sender
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
    m_ModePopUp.lastItem.tag = (int)BigFileViewModes::Text;
    [m_ModePopUp addItemWithTitle:@"Hex"];
    m_ModePopUp.lastItem.tag = (int)BigFileViewModes::Hex;
    [m_ModePopUp bind:@"selectedTag" toObject:m_View withKeyPath:@"mode" options:nil];
}

- (void)onModePopUpChanged:(id)sender
{
    dispatch_assert_main_queue();
}

- (void)setPositionButton:(NSButton *)positionButton
{
    dispatch_assert_main_queue();
    if( m_PositionButton == positionButton )
        return;
    
    m_PositionButton = positionButton;
    [m_PositionButton bind:@"title"
                  toObject:m_View
               withKeyPath:@"verticalPositionPercentage"
                   options:@{NSValueTransformerBindingOption:[InternalViewerControllerVerticalPostionToStringTransformer new]}];
}

@end