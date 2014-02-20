//
//  MainWindowBigFileViewState.m
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowBigFileViewState.h"
#import "BigFileView.h"
#import "FileWindow.h"
#import "MainWindowController.h"
#import "Common.h"
#import "SearchInFile.h"
#import "BigFileViewHistory.h"
#import "DispatchQueue.h"

#import "VFSFile.h"
#import "VFSNativeHost.h"
#import "VFSArchiveHost.h"
#import "VFSSeqToRandomWrapper.h"

static int FileWindowSize()
{
    int file_window_size = FileWindow::DefaultWindowSize;
    int file_window_pow2x = (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"BigFileViewFileWindowPow2X"];
    if( file_window_pow2x >= 0 && file_window_pow2x <= 5 )
        file_window_size *= 1 << file_window_pow2x;
    return file_window_size;
}

@implementation MainWindowBigFileViewState
{
    unique_ptr<FileWindow> m_FileWindow;
    unique_ptr<FileWindow> m_SearchFileWindow;
    unique_ptr<SearchInFile> m_SearchInFile;
    SerialQueue m_SearchInFileQueue;
    
    BigFileView         *m_View;
    NSPopUpButton       *m_EncodingSelect;
    NSButton            *m_WordWrap;
    NSPopUpButton       *m_ModeSelect;
    NSTextField         *m_ScrollPosition;
    NSSearchField       *m_SearchField;
    NSProgressIndicator *m_SearchIndicator;
    NSToolbar           *m_Toolbar;

    string              m_FilePath;
    string              m_GlobalFilePath;
}

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self)
    {        
        m_SearchInFileQueue = make_shared<SerialQueueT>();
        [self CreateControls];
    }
    return self;
}

- (void) dealloc
{
    if(m_FileWindow && m_FileWindow->FileOpened())
        m_FileWindow->CloseFile();
    if(m_SearchFileWindow && m_SearchFileWindow->FileOpened())
        m_SearchFileWindow->CloseFile();
}

- (NSView*) ContentView
{
    return self;
}

- (void) Assigned
{
    if(self.window.toolbar != nil)
        m_Toolbar.Visible = self.window.toolbar.isVisible;
    self.window.Toolbar = m_Toolbar;
    
    [self.window makeFirstResponder:m_View];
    [self UpdateTitle];    
}

- (void) Resigned
{
    [self SaveFileState];
    
    [m_View SetDelegate:nil];
    [m_View DoClose];
    m_SearchInFileQueue->Stop();
    m_SearchInFileQueue->Wait();
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
    if([itemIdentifier isEqualToString:@"bigfileview_encoding"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_EncodingSelect;
        return item;
    }
    
    if([itemIdentifier isEqualToString:@"bigfileview_texthex"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_ModeSelect;
        return item;
    }
    
    if([itemIdentifier isEqualToString:@"bigfileview_wordwrap"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_WordWrap;
        return item;
    }
    
    if([itemIdentifier isEqualToString:@"bigfileview_filepos"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_ScrollPosition;
        return item;
    }
    
    if([itemIdentifier isEqualToString:@"bigfileview_search"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_SearchField;
        return item;
    }
    
    if([itemIdentifier isEqualToString:@"bigfileview_search_indicator"]) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        item.view = m_SearchIndicator;
        return item;
    }
    
    return nil;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [self toolbarAllowedItemIdentifiers:toolbar];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
    return @[ @"bigfileview_encoding",
                  @"bigfileview_texthex",
                  @"bigfileview_wordwrap",
                  @"bigfileview_filepos",
                  NSToolbarFlexibleSpaceItemIdentifier,
                  @"bigfileview_search_indicator",
                  @"bigfileview_search"];
}

- (void) UpdateTitle
{
    NSString *path = [NSString stringWithUTF8String:m_GlobalFilePath.c_str()];
    if(path == nil) path = @"...";
    NSString *title = [NSString stringWithFormat:@"File View: %@", path];
    
    // find window geometry
    NSWindow* window = [self window];
    float leftEdge = NSMaxX([[window standardWindowButton:NSWindowZoomButton] frame]);
    NSButton* fsbutton = [window standardWindowButton:NSWindowFullScreenButton];
    float rightEdge = fsbutton ? [fsbutton frame].origin.x : NSMaxX([window frame]);
    
    // Leave 8 pixels of padding around the title.
    const int kTitlePadding = 8;
    float titleWidth = rightEdge - leftEdge - 2 * kTitlePadding;
    
    // Sending |titleBarFontOfSize| 0 returns default size
    NSDictionary* attributes = [NSDictionary dictionaryWithObject:[NSFont titleBarFontOfSize:0] forKey:NSFontAttributeName];
    window.title = StringByTruncatingToWidth(title, titleWidth, kTruncateAtStart, attributes);    
}

- (void)cancelOperation:(id)sender
{
    [(MainWindowController*)[[self window] delegate] ResignAsWindowState:self];
}

- (bool) OpenFile: (const char*) _fn with_fs:(shared_ptr<VFSHost>) _host
{
    shared_ptr<VFSFile> vfsfile;
    if(_host->CreateFile(_fn, &vfsfile, 0) < 0)
        return false;

    if(vfsfile->Open(VFSFile::OF_Read) < 0)
        return false;
    if(vfsfile->GetReadParadigm() < VFSFile::ReadParadigm::Random)
    {
        vfsfile = make_shared<VFSSeqToRandomROWrapperFile>(vfsfile);
        vfsfile->Open(VFSFile::OF_Read);
    }
    
    unique_ptr<FileWindow> fw(new FileWindow);
    
    if(fw->OpenFile(vfsfile, FileWindowSize()) == 0)
    {
        if(m_FileWindow != 0)
        {
            if(m_FileWindow->FileOpened())
                m_FileWindow->CloseFile();
        }
        
        m_FileWindow.swap(fw);
        m_SearchFileWindow.reset(new FileWindow);
        m_SearchFileWindow->OpenFile(vfsfile);
        m_SearchInFile.reset(new SearchInFile(m_SearchFileWindow.get()));
        m_SearchInFile->SetSearchOptions(
                                         ([[NSUserDefaults standardUserDefaults] boolForKey:@"BigFileViewCaseSensitiveSearch"] ? SearchInFile::OptionCaseSensitive : 0) |
                                         ([[NSUserDefaults standardUserDefaults] boolForKey:@"BigFileViewWholePhraseSearch"]   ? SearchInFile::OptionFindWholePhrase : 0) );
        
        m_FilePath = _fn;
        char tmp[MAXPATHLEN*8]; // danger!
        vfsfile->ComposeFullHostsPath(tmp);
        m_GlobalFilePath = tmp;
        
        // try to load a saved info if any
        if(BigFileViewHistoryEntry *info =
           [[BigFileViewHistory sharedHistory] FindEntryByPath:[NSString stringWithUTF8String:m_GlobalFilePath.c_str()]])
        {
            BigFileViewHistoryOptions options = [BigFileViewHistory HistoryOptions];
            if(options.encoding && options.mode)
                [m_View SetKnownFile:m_FileWindow.get() encoding:info->encoding mode:info->view_mode];
            else {
                [m_View SetFile:m_FileWindow.get()];
                if(options.encoding) [m_View SetEncoding:info->encoding];
                if(options.mode) [m_View SetMode:info->view_mode];
            }
            // a bit suboptimal no - may re-layout after first one
            if(options.wrapping) [m_View SetWordWrap:info->wrapping];
            if(options.position) [m_View SetVerticalPositionInBytes:info->position];
            if(options.selection)[m_View SetSelectionInFile:info->selection];
        }
        else
            [m_View SetFile:m_FileWindow.get()];
        
        // update UI
        [self SelectEncodingFromView];
        [self SelectModeFromView];
        [self UpdateWordWrap];
        [self BigFileViewScrolled];
        
        return true;
    }
    else
    {
        if(fw->FileOpened())
            fw->CloseFile();
        return false;
    }
}

- (void) CreateControls
{
    m_View = [[BigFileView alloc] initWithFrame:self.frame];
    [m_View setTranslatesAutoresizingMaskIntoConstraints:NO];
    [m_View SetDelegate:self];
    [self addSubview:m_View];
    
    m_EncodingSelect = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 120, 20)];
    [(NSPopUpButtonCell*)[m_EncodingSelect cell] setControlSize:NSSmallControlSize];
    [m_EncodingSelect setTarget:self];
    [m_EncodingSelect setAction:@selector(SelectedEncoding:)];
    [m_EncodingSelect setFont:[NSFont menuFontOfSize:10]];
    
    m_ModeSelect = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 60, 20)];
    [(NSPopUpButtonCell*)[m_ModeSelect cell] setControlSize:NSSmallControlSize];
    [m_ModeSelect setTarget:self];
    [m_ModeSelect setAction:@selector(SelectMode:)];
    [m_ModeSelect addItemWithTitle:@"Text"];
    [m_ModeSelect addItemWithTitle:@"Hex"];
    [m_ModeSelect setFont:[NSFont menuFontOfSize:10]];
    [self addSubview:m_ModeSelect];
    
    m_WordWrap = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 80, 20)];
    [[m_WordWrap cell] setControlSize:NSSmallControlSize];
    [m_WordWrap setButtonType:NSSwitchButton];
    [m_WordWrap setTitle:@"Word wrap"];
    [m_WordWrap setTarget:self];
    [m_WordWrap setAction:@selector(WordWrapChanged:)];
    [m_WordWrap setFont:[NSFont menuFontOfSize:10]];
    
    m_ScrollPosition = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 80, 12)];
    [m_ScrollPosition setEditable:false];
    [m_ScrollPosition setBordered:false];
    [m_ScrollPosition setDrawsBackground:false];
    [m_ScrollPosition setFont:[NSFont menuFontOfSize:10]];
    
    m_SearchField = [[NSSearchField alloc]initWithFrame:NSMakeRect(0, 0, 200, 20)];
    [m_SearchField setTarget:self];
    [m_SearchField setAction:@selector(UpdateSearchFilter:)];
    [[m_SearchField cell] setPlaceholderString:@"Search in file"];
    [[m_SearchField cell] setSendsWholeSearchString:true];
    [[m_SearchField cell] setRecentsAutosaveName:@"BigFileViewRecentSearches"];
    [[m_SearchField cell] setMaximumRecents:20];
    [[m_SearchField cell] setSearchMenuTemplate:[self BuildSearchMenu]];
    
    m_SearchIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    [m_SearchIndicator setIndeterminate:YES];
    [m_SearchIndicator setStyle:NSProgressIndicatorSpinningStyle];
    [m_SearchIndicator setControlSize:NSSmallControlSize];
    [m_SearchIndicator setDisplayedWhenStopped:NO];

    NSDictionary *views = NSDictionaryOfVariableBindings(m_View);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(<=1)-[m_View]-(<=1)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(<=0)-[m_View]-(<=1)-|" options:0 metrics:nil views:views]];
    
    for(const auto &i: encodings::LiteralEncodingsList())
        [m_EncodingSelect addItemWithTitle: (__bridge NSString*)i.second];
    
    m_Toolbar = [[NSToolbar alloc] initWithIdentifier:@"bigfileview_toolbar"];
    m_Toolbar.delegate = self;
    m_Toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    m_Toolbar.autosavesConfiguration = true;
    m_Toolbar.showsBaselineSeparator = true;
}

- (void) SelectEncodingFromView
{
    int current_encoding = [m_View Enconding];
    for(const auto &i: encodings::LiteralEncodingsList())
        if(i.first == current_encoding)
        {
            [m_EncodingSelect selectItemWithTitle:(__bridge NSString*)i.second];
            break;
        }
}

- (void) SelectedEncoding:(id)sender
{
    for(const auto &i: encodings::LiteralEncodingsList())
        if([(__bridge NSString*)i.second isEqualToString:[[m_EncodingSelect selectedItem] title]])
        {
            [m_View SetEncoding:i.first];
            [self UpdateSearchFilter:self];
            break;
        }
}

- (void) UpdateWordWrap
{
    [m_WordWrap setState:[m_View WordWrap] ? NSOnState : NSOffState];
    [m_WordWrap setEnabled:[m_View Mode] == BigFileViewModes::Text];
}

- (void) WordWrapChanged:(id)sender
{
    [m_View SetWordWrap: [m_WordWrap state]==NSOnState];
}

- (void) SelectModeFromView
{
    if([m_View Mode] == BigFileViewModes::Text)
        [m_ModeSelect selectItemAtIndex:0];
    else if([m_View Mode] == BigFileViewModes::Hex)
        [m_ModeSelect selectItemAtIndex:1];
    else
        assert(0);
}

- (void) SelectMode:(id)sender
{
    if([m_ModeSelect indexOfSelectedItem] == 0)
        [m_View SetMode:BigFileViewModes::Text];
    else if([m_ModeSelect indexOfSelectedItem] == 1)
        [m_View SetMode:BigFileViewModes::Hex];
    [self UpdateWordWrap];
}

- (void) BigFileViewScrolled
{
    NSString *s = [NSString stringWithFormat:@"%@  %.0f%%",
                   FormHumanReadableSizeRepresentation6(m_FileWindow->FileSize()),
                   [m_View VerticalScrollPosition]*100.];
    [m_ScrollPosition setStringValue:s];
}

- (void) BigFileViewScrolledByUser
{
    m_SearchInFile->MoveCurrentPosition([m_View VerticalPositionInBytes]);
}

- (void)UpdateSearchFilter:sender
{
    NSString *str = [m_SearchField stringValue];
    if([str length] == 0)
    {
        m_SearchInFileQueue->Stop(); // we should stop current search if any
        [m_View SetSelectionInFile:CFRangeMake(-1, 0)];
        return;
    }
    
    if( m_SearchInFile->TextSearchString() == NULL ||
       [str compare:(__bridge NSString*) m_SearchInFile->TextSearchString()] != NSOrderedSame ||
       m_SearchInFile->TextSearchEncoding() != [m_View Enconding] )
    { // user did some changes in search request
        [m_View SetSelectionInFile:CFRangeMake(-1, 0)]; // remove current selection

        uint64_t view_offset = [m_View VerticalPositionInBytes];
        int encoding = [m_View Enconding];
        
        m_SearchInFileQueue->Stop(); // we should stop current search if any
        m_SearchInFileQueue->Wait();
        m_SearchInFileQueue->Run(^{
            m_SearchInFile->MoveCurrentPosition(view_offset);
            m_SearchInFile->ToggleTextSearch((__bridge CFStringRef)str, encoding);
        });
    }
    else
    { // request is the same
        if(!m_SearchInFileQueue->Empty())
            return; // we're already performing this request now, nothing to do
    }
    
    m_SearchInFileQueue->Run(^{
        uint64_t offset, len;
        
        if(m_SearchInFile->IsEOF())
            m_SearchInFile->MoveCurrentPosition(0);
        
        dispatch_to_main_queue( ^{[self NotifySearching];});
        auto result = m_SearchInFile->Search(&offset, &len, ^{return m_SearchInFileQueue->IsStopped();});
        dispatch_to_main_queue( ^{[self NotifySearching];});
        
        if(result == SearchInFile::Result::Found)
            dispatch_to_main_queue( ^{
                [m_View SetSelectionInFile:CFRangeMake(offset, len)];
                [m_View ScrollToSelection];
            });
    });
}

- (void)NotifySearching
{
    const auto visual_spinning_delay = 100ull; // should be 100 ms of workload before user will get spinning indicator
    
    if(!m_SearchInFileQueue->Empty())
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, visual_spinning_delay * USEC_PER_SEC), dispatch_get_main_queue(), ^{
                           if(!m_SearchInFileQueue->Empty()) // need to check if task was already done
                               [m_SearchIndicator startAnimation:self];
                       });
    else
        [m_SearchIndicator stopAnimation:self];
}

- (IBAction)performFindPanelAction:(id)sender
{
    if(m_Toolbar.isVisible == false)
        m_Toolbar.Visible = true;
    
    [self.window makeFirstResponder:m_SearchField];
}

- (void)OnApplicationWillTerminate
{
    [self SaveFileState];
}

- (void) SaveFileState
{
    if(![BigFileViewHistory HistoryEnabled])
        return;
    
    // do our state persistance stuff
    BigFileViewHistoryEntry *info = [BigFileViewHistoryEntry new];
    info->path = [NSString stringWithUTF8String:m_GlobalFilePath.c_str()];
    info->last_viewed = [NSDate date];    
    info->position = [m_View VerticalPositionInBytes];
    info->wrapping = [m_View WordWrap];
    info->view_mode = [m_View Mode];
    info->encoding = [m_View Enconding];
    info->selection = [m_View SelectionInFile];
    [[BigFileViewHistory sharedHistory] InsertEntry:info];
}

- (NSMenu*) BuildSearchMenu
{
    NSMenu *cellMenu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
    NSMenuItem *item;
    
    item = [[NSMenuItem alloc] initWithTitle:@"Case-sensitive search" action:@selector(SetCaseSensitiveSearch:) keyEquivalent:@""];
    [item setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"BigFileViewCaseSensitiveSearch"]];
    [item setTarget:self];
    [cellMenu insertItem:item atIndex:0];

    item = [[NSMenuItem alloc] initWithTitle:@"Find whole phrase" action:@selector(SetWholePhrasesSearch:) keyEquivalent:@""];
    [item setState:[[NSUserDefaults standardUserDefaults] boolForKey:@"BigFileViewWholePhraseSearch"]];
    [item setTarget:self];    
    [cellMenu insertItem:item atIndex:1];
    
    item = [[NSMenuItem alloc] initWithTitle:@"Clear Recents" action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldClearRecentsMenuItemTag];
    [cellMenu insertItem:item atIndex:2];
    
    item = [NSMenuItem separatorItem];
    [item setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [cellMenu insertItem:item atIndex:3];
    
    item = [[NSMenuItem alloc] initWithTitle:@"Recent Searches" action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldRecentsTitleMenuItemTag];
    [cellMenu insertItem:item atIndex:4];
    
    item = [[NSMenuItem alloc] initWithTitle:@"Recents" action:NULL keyEquivalent:@""];
    [item setTag:NSSearchFieldRecentsMenuItemTag];
    [cellMenu insertItem:item atIndex:5];
    
    return cellMenu;
}

- (IBAction)SetCaseSensitiveSearch:(NSMenuItem *)menuItem
{
    int options = m_SearchInFile->SearchOptions();
    options = (options & ~SearchInFile::OptionCaseSensitive) |
        ((options & SearchInFile::OptionCaseSensitive) ? 0 : SearchInFile::OptionCaseSensitive); // invert this option
    m_SearchInFile->SetSearchOptions(options);
    
    NSMenu* menu = [[m_SearchField cell] searchMenuTemplate];
    [[menu itemAtIndex:0] setState:(options & SearchInFile::OptionCaseSensitive) != 0];
    [[m_SearchField cell] setSearchMenuTemplate:menu];
    [[NSUserDefaults standardUserDefaults] setBool:options&SearchInFile::OptionCaseSensitive forKey:@"BigFileViewCaseSensitiveSearch"];
}

- (IBAction)SetWholePhrasesSearch:(NSMenuItem *)menuItem
{
    int options = m_SearchInFile->SearchOptions();
    options = (options & ~SearchInFile::OptionFindWholePhrase) |
        ((options & SearchInFile::OptionFindWholePhrase) ? 0 : SearchInFile::OptionFindWholePhrase); // invert this option
    m_SearchInFile->SetSearchOptions(options);
    
    NSMenu* menu = [[m_SearchField cell] searchMenuTemplate];
    [[menu itemAtIndex:1] setState:(options & SearchInFile::OptionFindWholePhrase) != 0];
    [[m_SearchField cell] setSearchMenuTemplate:menu];
    [[NSUserDefaults standardUserDefaults] setBool:options&SearchInFile::OptionFindWholePhrase forKey:@"BigFileViewWholePhraseSearch"];
}

@end
