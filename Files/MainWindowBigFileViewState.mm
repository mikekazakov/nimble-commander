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
#import "ProcessSheetController.h"
#import "ActionsShortcutsManager.h"
#import "ByteCountFormatter.h"

static int EncodingFromXAttr(const VFSFilePtr &_f)
{
    char buf[128];
    ssize_t r = _f->XAttrGet("com.apple.TextEncoding", buf, sizeof(buf));
    if(r < 0 || r >= sizeof(buf))
        return encodings::ENCODING_INVALID;
    buf[r] = 0;
    return encodings::FromComAppleTextEncodingXAttr(buf);
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
    NSSegmentedControl  *m_ModeSelect;
    NSTextField         *m_ScrollPosition;
    NSSearchField       *m_SearchField;
    NSProgressIndicator *m_SearchIndicator;
    NSToolbar           *m_Toolbar;
    NSBox               *m_SeparatorLine;    

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

- (NSView*) windowContentView
{
    return self;
}

- (bool) needsWindowTitle
{
    return true;
}

- (void) Assigned
{
    [self.window makeFirstResponder:m_View];
    [self UpdateTitle];    
}

- (void) Resigned
{
    [self SaveFileState];
    m_SearchInFileQueue->Stop();
    m_SearchInFileQueue->Wait();
}

+ (int) fileWindowSize
{
    int file_window_size = FileWindow::DefaultWindowSize;
    int file_window_pow2x = (int)[NSUserDefaults.standardUserDefaults integerForKey:@"BigFileViewFileWindowPow2X"];
    if( file_window_pow2x >= 0 && file_window_pow2x <= 5 )
        file_window_size *= 1 << file_window_pow2x;
    return file_window_size;
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar
     itemForItemIdentifier:(NSString *)itemIdentifier
 willBeInsertedIntoToolbar:(BOOL)flag
{
    auto f = [](NSString *_id, NSView *_v) {
        NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:_id];
        item.view = _v;
        return item;
    };
#define item(a, b) if([itemIdentifier isEqualToString:a]) return f(a, b)
    item(@"bigfileview_encoding",           m_EncodingSelect);
    item(@"bigfileview_texthex",            m_ModeSelect);
    item(@"bigfileview_wordwrap",           m_WordWrap);
    item(@"bigfileview_filepos",            m_ScrollPosition);
    item(@"bigfileview_search",             m_SearchField);
    item(@"bigfileview_search_indicator",   m_SearchIndicator);
#undef item
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
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"File View - %@", "Window title for internal file viewer"),
                       path];
    
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
    [(MainWindowController*)self.window.delegate ResignAsWindowState:self];
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender
{
    [self cancelOperation:sender];
}

- (bool)OpenFile:(const char*)_fn with_fs:(shared_ptr<VFSHost>)_host
{
    VFSFilePtr origfile;
    if(_host->CreateFile(_fn, origfile, 0) < 0)
        return false;

    VFSFilePtr vfsfile;
    
    if(origfile->GetReadParadigm() < VFSFile::ReadParadigm::Random)
    { // we need to read a file into temporary mem/file storage to access it randomly
        ProcessSheetController *proc = [ProcessSheetController new];
        proc.title = NSLocalizedString(@"Opening file...", "Title for process sheet when opening a vfs file");
        [proc Show];
        
        auto wrapper = make_shared<VFSSeqToRandomROWrapperFile>(origfile);
        int res = wrapper->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock,
                                [=]{ return proc.userCancelled; },
                                [=](uint64_t _bytes, uint64_t _total) {
                                    proc.Progress.doubleValue = double(_bytes) / double(_total);
                                });
        [proc Close];
        if(res != 0)
            return false;
        
        vfsfile = wrapper;
    }
    else
    { // just open input file
        if(origfile->Open(VFSFlags::OF_Read) < 0)
            return false;
        vfsfile = origfile;
    }
    
    m_FileWindow = make_unique<FileWindow>();
    if(m_FileWindow->OpenFile(vfsfile, MainWindowBigFileViewState.fileWindowSize) != 0)
        return false;
    
    m_SearchFileWindow = make_unique<FileWindow>();
    if(m_SearchFileWindow->OpenFile(vfsfile) != 0)
        return false;
    
    m_SearchInFile = make_unique<SearchInFile>(*m_SearchFileWindow);
    m_SearchInFile->SetSearchOptions(
                                     ([NSUserDefaults.standardUserDefaults boolForKey:@"BigFileViewCaseSensitiveSearch"] ? SearchInFile::OptionCaseSensitive : 0) |
                                     ([NSUserDefaults.standardUserDefaults boolForKey:@"BigFileViewWholePhraseSearch"]   ? SearchInFile::OptionFindWholePhrase : 0) );
    
    m_FilePath = _fn;
    m_GlobalFilePath = vfsfile->ComposeVerbosePath();
        
    // try to load a saved info if any
    int encoding = 0;
    if(BigFileViewHistoryEntry *info =
        [BigFileViewHistory.sharedHistory FindEntryByPath:[NSString stringWithUTF8String:m_GlobalFilePath.c_str()]]) {
        BigFileViewHistoryOptions options = BigFileViewHistory.HistoryOptions;
        if(options.encoding && options.mode)
            [m_View SetKnownFile:m_FileWindow.get() encoding:info->encoding mode:info->view_mode];
        else {
            [m_View SetFile:m_FileWindow.get()];
            if(options.encoding)    m_View.encoding = info->encoding;
            if(options.mode)        m_View.mode = info->view_mode;
        }
        // a bit suboptimal no - may re-layout after first one
        if(options.wrapping) m_View.wordWrap = info->wrapping;
        if(options.position) m_View.verticalPositionInBytes = info->position;
        if(options.selection) m_View.selectionInFile = info->selection;
    }
    else {
        [m_View SetFile:m_FileWindow.get()];
        if([NSUserDefaults.standardUserDefaults boolForKey:@"BigFileViewRespectComAppleTextEncoding"] &&
           (encoding = EncodingFromXAttr(origfile)) != encodings::ENCODING_INVALID )
            m_View.encoding = encoding;
    }
    
    // update UI
    [m_EncodingSelect selectItemWithTag:m_View.encoding];
    [self SelectModeFromView];
    [self UpdateWordWrap];
    [self BigFileViewScrolled];
        
    return true;
}

- (void) CreateControls
{
    m_View = [[BigFileView alloc] initWithFrame:self.frame];
    m_View.translatesAutoresizingMaskIntoConstraints = false;
    m_View.focusRingType = NSFocusRingTypeNone;
    m_View.delegate = self;
    [self addSubview:m_View];
    
    m_SeparatorLine = [[NSBox alloc] initWithFrame:NSRect()];
    m_SeparatorLine.translatesAutoresizingMaskIntoConstraints = false;
    m_SeparatorLine.boxType = NSBoxSeparator;
    [self addSubview:m_SeparatorLine];    
    
    m_EncodingSelect = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 120, 20)];
    ((NSPopUpButtonCell*)m_EncodingSelect.cell).controlSize = NSSmallControlSize;
    m_EncodingSelect.target = self;
    m_EncodingSelect.action = @selector(SelectedEncoding:);
    m_EncodingSelect.font = [NSFont menuFontOfSize:10];
    
    m_ModeSelect = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(0, 0, 110, 20)];
    [m_ModeSelect.cell setControlSize:NSSmallControlSize];
    m_ModeSelect.target = self;
    m_ModeSelect.action = @selector(SelectMode:);
    m_ModeSelect.segmentStyle = NSSegmentStyleRounded;
    m_ModeSelect.segmentCount = 2;
    m_ModeSelect.font = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
    [m_ModeSelect setLabel:NSLocalizedString(@"Text", "Internal viewer mode - textual") forSegment:0];
    [m_ModeSelect setLabel:NSLocalizedString(@"Hex", "Internal viewer mode - hexadecimal") forSegment:1];
    [m_ModeSelect setWidth:52 forSegment:0];
    [m_ModeSelect setWidth:52 forSegment:1];
    
    m_WordWrap = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 80, 20)];
    ((NSButtonCell*)m_WordWrap.cell).controlSize = NSSmallControlSize;
    m_WordWrap.buttonType = NSSwitchButton;
    m_WordWrap.title = NSLocalizedString(@"Word wrap", "Internal viewer checkbox to wrap words");
    m_WordWrap.target = self;
    m_WordWrap.action = @selector(WordWrapChanged:);
    m_WordWrap.font = [NSFont menuFontOfSize:10];
    
    m_ScrollPosition = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 80, 12)];
    m_ScrollPosition.editable = false;
    m_ScrollPosition.bordered = false;
    m_ScrollPosition.drawsBackground = false;
    m_ScrollPosition.font = [NSFont menuFontOfSize:10];
    
    m_SearchField = [[NSSearchField alloc]initWithFrame:NSMakeRect(0, 0, 200, 20)];
    m_SearchField.target = self;
    m_SearchField.action = @selector(UpdateSearchFilter:);
    m_SearchField.delegate = self;
    [m_SearchField.cell setPlaceholderString:NSLocalizedString(@"Search in file", "Placeholder for search text field in internal viewer")];
    [m_SearchField.cell setSendsWholeSearchString:true];
    [m_SearchField.cell setRecentsAutosaveName:@"BigFileViewRecentSearches"];
    [m_SearchField.cell setMaximumRecents:20];
    [m_SearchField.cell setSearchMenuTemplate:self.searchMenu];
    
    m_SearchIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 16, 16)];
    m_SearchIndicator.indeterminate = true;
    m_SearchIndicator.style = NSProgressIndicatorSpinningStyle;
    m_SearchIndicator.controlSize = NSSmallControlSize;
    m_SearchIndicator.displayedWhenStopped = false;

    m_Toolbar = [[NSToolbar alloc] initWithIdentifier:@"bigfileview_toolbar"];
    m_Toolbar.delegate = self;
    m_Toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    m_Toolbar.autosavesConfiguration = true;
    m_Toolbar.showsBaselineSeparator = false;
    
    for(const auto &i: encodings::LiteralEncodingsList()) {
        [m_EncodingSelect addItemWithTitle: (__bridge NSString*)i.second];
        m_EncodingSelect.lastItem.tag = i.first;
    }
    
    NSDictionary *views = NSDictionaryOfVariableBindings(m_View, m_SeparatorLine);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(<=1)-[m_View]-(<=1)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_SeparatorLine(<=1)]-(==0)-[m_View]-(<=1)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(==0)-[m_SeparatorLine]-(==0)-|" options:0 metrics:nil views:views]];
}

- (NSToolbar*)toolbar
{
    return m_Toolbar;
}

- (void) SelectedEncoding:(id)sender
{
    m_View.encoding = (int)m_EncodingSelect.selectedTag;
    [self UpdateSearchFilter:self];
}

- (void) UpdateWordWrap
{
    m_WordWrap.state = m_View.wordWrap ? NSOnState : NSOffState;
    m_WordWrap.enabled = m_View.mode == BigFileViewModes::Text;
}

- (void) WordWrapChanged:(id)sender
{
    m_View.wordWrap = m_WordWrap.state == NSOnState;
}

- (void) SelectModeFromView
{
    m_ModeSelect.selectedSegment = (int)m_View.mode;
}

- (void) SelectMode:(id)sender
{
    m_View.mode = (BigFileViewModes)m_ModeSelect.selectedSegment;
    [self UpdateWordWrap];
}

- (void) BigFileViewScrolled
{
    NSString *s = [NSString stringWithFormat:@"%@  %.0f%%",
                   ByteCountFormatter::Instance().ToNSString(m_FileWindow->FileSize(), ByteCountFormatter::Fixed6),
                   [m_View VerticalScrollPosition]*100.];
    m_ScrollPosition.stringValue = s;
}

- (void) BigFileViewScrolledByUser
{
    m_SearchInFile->MoveCurrentPosition(m_View.verticalPositionInBytes);
}

- (void)UpdateSearchFilter:sender
{
    NSString *str = m_SearchField.stringValue;
    if(str.length == 0)
    {
        m_SearchInFileQueue->Stop(); // we should stop current search if any
        m_View.selectionInFile = CFRangeMake(-1, 0);
        return;
    }
    
    if( m_SearchInFile->TextSearchString() == NULL ||
       [str compare:(__bridge NSString*) m_SearchInFile->TextSearchString()] != NSOrderedSame ||
       m_SearchInFile->TextSearchEncoding() != m_View.encoding )
    { // user did some changes in search request
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
    else
    { // request is the same
        if(!m_SearchInFileQueue->Empty())
            return; // we're already performing this request now, nothing to do
    }
    
    m_SearchInFileQueue->Run([=]{
        uint64_t offset, len;
        
        if(m_SearchInFile->IsEOF())
            m_SearchInFile->MoveCurrentPosition(0);
        
        dispatch_to_main_queue( [=]{[self NotifySearching];});
        auto result = m_SearchInFile->Search(&offset, &len, ^{return m_SearchInFileQueue->IsStopped();});
        dispatch_to_main_queue( [=]{[self NotifySearching];});
        
        if(result == SearchInFile::Result::Found)
            dispatch_to_main_queue( [=]{
                m_View.selectionInFile = CFRangeMake(offset, len);
                [m_View ScrollToSelection];
            });
    });
}

- (void)NotifySearching
{
    if(!m_SearchInFileQueue->Empty())
        dispatch_to_main_queue_after(100ms, [=]{ // should be 100 ms of workload before user will get spinning indicator
                           if(!m_SearchInFileQueue->Empty()) // need to check if task was already done
                               [m_SearchIndicator startAnimation:self];
                       });
    else
        [m_SearchIndicator stopAnimation:self];
}

- (IBAction)performFindPanelAction:(id)sender
{
    if(!m_Toolbar.visible)
        [((MainWindowController*)self.window.delegate) OnShowToolbar:self];
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
    if(info->path == nil)
        return; // guard against malformed filenames, like an archives with invalid encoding
    info->last_viewed = NSDate.date;
    info->position = m_View.verticalPositionInBytes;
    info->wrapping = m_View.wordWrap;
    info->view_mode = m_View.mode;
    info->encoding = m_View.encoding;
    info->selection = m_View.selectionInFile;
    [[BigFileViewHistory sharedHistory] InsertEntry:info];
}

- (NSMenu*) searchMenu
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Search Menu"];
    NSMenuItem *item;
    
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Case-sensitive search", "Menu item option in internal viewer search")
                                      action:@selector(SetCaseSensitiveSearch:)
                               keyEquivalent:@""];
    item.state = [NSUserDefaults.standardUserDefaults boolForKey:@"BigFileViewCaseSensitiveSearch"];
    item.target = self;
    [menu insertItem:item atIndex:0];

    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Find whole phrase", "Menu item option in internal viewer search")
                                      action:@selector(SetWholePhrasesSearch:)
                               keyEquivalent:@""];
    item.state = [NSUserDefaults.standardUserDefaults boolForKey:@"BigFileViewWholePhraseSearch"];
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

- (IBAction)SetCaseSensitiveSearch:(NSMenuItem *)menuItem
{
    int options = m_SearchInFile->SearchOptions();
    options = (options & ~SearchInFile::OptionCaseSensitive) |
        ((options & SearchInFile::OptionCaseSensitive) ? 0 : SearchInFile::OptionCaseSensitive); // invert this option
    m_SearchInFile->SetSearchOptions(options);
    
    NSMenu* menu = ((NSSearchFieldCell*)m_SearchField.cell).searchMenuTemplate;
    [menu itemAtIndex:0].state = (options & SearchInFile::OptionCaseSensitive) != 0;
    ((NSSearchFieldCell*)m_SearchField.cell).searchMenuTemplate = menu;
    [NSUserDefaults.standardUserDefaults setBool:options&SearchInFile::OptionCaseSensitive forKey:@"BigFileViewCaseSensitiveSearch"];
}

- (IBAction)SetWholePhrasesSearch:(NSMenuItem *)menuItem
{
    int options = m_SearchInFile->SearchOptions();
    options = (options & ~SearchInFile::OptionFindWholePhrase) |
        ((options & SearchInFile::OptionFindWholePhrase) ? 0 : SearchInFile::OptionFindWholePhrase); // invert this option
    m_SearchInFile->SetSearchOptions(options);
    
    NSMenu* menu = ((NSSearchFieldCell*)m_SearchField.cell).searchMenuTemplate;
    [menu itemAtIndex:1].state = (options & SearchInFile::OptionFindWholePhrase) != 0;
    ((NSSearchFieldCell*)m_SearchField.cell).searchMenuTemplate = menu;
    [NSUserDefaults.standardUserDefaults setBool:options&SearchInFile::OptionFindWholePhrase forKey:@"BigFileViewWholePhraseSearch"];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector
{
    if(control == m_SearchField && commandSelector == NSSelectorFromString(@"cancelOperation:")) {
        [self.window makeFirstResponder:m_View];
        return true;
    }
    return false;
}

- (IBAction)performClose:(id)sender
{
    [self cancelOperation:sender];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto tag = item.tag;
    IF_MENU_TAG("menu.file.close") {
        item.title = NSLocalizedString(@"Close Viewer", "Menu item title for closing internal viewer state");
        return true;
    }
    return true;
}

@end
