// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/dispatch_cpp.h>
#include <Habanero/DispatchGroup.h>
#include <Utility/NSTimer+Tolerance.h>
#include <Utility/SheetWithHotkeys.h>
#include <Utility/Encodings.h>
#include <Utility/PathManip.h>
#include <NimbleCommander/Viewer/BigFileViewSheet.h>
#include <NimbleCommander/Viewer/InternalViewerWindowController.h>
#include <NimbleCommander/Core/SearchForFiles.h>
#include <Utility/ByteCountFormatter.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/rapidjson.h>
#include <NimbleCommander/States/FilePanels/PanelAux.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/VFSInstanceManager.h>
#include <NimbleCommander/Core/VFSInstancePromise.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "FindFilesSheetController.h"

static const auto g_StateMaskHistory = "filePanel.findFilesSheet.maskHistory";
static const auto g_StateTextHistory = "filePanel.findFilesSheet.textHistory";
static const int g_MaximumSearchResults = 262144;

static const auto g_ConfigModalInternalViewer = "viewer.modalMode";

static string ensure_tr_slash( string _str )
{
    if(_str.empty() || _str.back() != '/')
        _str += '/';
    return _str;
}

static string ensure_no_tr_slash( string _str )
{
    if( _str.empty() || _str == "/" )
        return _str;
    
    if( _str.back() == '/' )
        _str.pop_back();
    
    return _str;
}

static string to_relative_path( const VFSHostPtr &_in_host, string _path, const string& _base_path )
{
    VFSHostPtr a = _in_host;
    while( a ) {
        _path.insert(0, a->JunctionPath());
        a = a->Parent();
    }
    
    if( _base_path.length() > 1 && _path.find(_base_path) == 0)
        _path.replace(0, _base_path.length(), "./");
    return _path;
}

class FindFilesSheetComboHistory : public vector<string>
{
public:
    FindFilesSheetComboHistory(int _max, const char *_config_path):
        m_Path(_config_path),
        m_Max(_max)
    {
        auto arr = StateConfig().Get(m_Path);
        if( arr.GetType() == rapidjson::kArrayType )
            for( auto i = arr.Begin(), e = arr.End(); i != e; ++i )
                if( i->GetType() == rapidjson::kStringType )
                    emplace_back( i->GetString() );
    }
    
    ~FindFilesSheetComboHistory()
    {
        GenericConfig::ConfigValue arr(rapidjson::kArrayType);
        for( auto &s: *this )
            arr.PushBack(GenericConfig::ConfigValue(s.c_str(), GenericConfig::g_CrtAllocator),
                         GenericConfig::g_CrtAllocator );
        StateConfig().Set(m_Path, arr);
    }
    
    void insert_unique( const string &_value )
    {
        erase( remove_if(begin(), end(), [&](auto &_s) { return _s == _value; }), end() );
        insert( begin(), _value );
        while( size() > (size_t)m_Max ) pop_back();
    }
    
private:
    const int   m_Max;
    const char *m_Path;
};

@interface FindFilesSheetFoundItem : NSObject
@property (nonatomic, readonly) FindFilesSheetControllerFoundItem *data;
@property (nonatomic, readonly) NSString *location;
@property (nonatomic, readonly) NSString *filename;
@property (nonatomic, readonly) uint64_t size;
@property (nonatomic, readonly) uint64_t mdate;
@end

@implementation FindFilesSheetFoundItem
{
    FindFilesSheetControllerFoundItem m_Data;
    NSString *m_Location;
    NSString *m_Filename;
}

@synthesize location = m_Location;
@synthesize filename = m_Filename;

- (id) initWithFoundItem:(FindFilesSheetControllerFoundItem&&)_item
{
    self = [super init];
    if(self) {
        m_Data = move(_item);
        m_Location = [NSString stringWithUTF8StdString:m_Data.rel_path];
        m_Filename = [NSString stringWithUTF8StdString:m_Data.filename];
    }
    return self;
}

- (uint64_t) size {
    return m_Data.st.size;
}

- (uint64_t) mdate {
    return m_Data.st.mtime.tv_sec;
}

- (FindFilesSheetControllerFoundItem*) data {
    return &m_Data;
}

@end

@interface FindFilesSheetSizeToStringTransformer : NSValueTransformer
@end
@implementation FindFilesSheetSizeToStringTransformer
+ (Class)transformedValueClass
{
	return NSString.class;
}
- (id)transformedValue:(id)value
{
    return (value == nil) ? nil : ByteCountFormatter::Instance().ToNSString([value unsignedLongLongValue], ByteCountFormatter::Fixed6);
}
@end

@interface FindFilesSheetTimeToStringTransformer : NSValueTransformer
@end
@implementation FindFilesSheetTimeToStringTransformer
+ (Class)transformedValueClass
{
	return NSString.class;
}
- (id)transformedValue:(id)value
{
    static NSDateFormatter *formatter;
    static once_flag once;
    call_once(once, []{
        formatter = [NSDateFormatter new];
        formatter.locale = NSLocale.currentLocale;
        formatter.dateStyle = NSDateFormatterShortStyle;
    });
    
    if(value == nil)
        return nil;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[value unsignedLongLongValue]];
    return [formatter stringFromDate:date];
}
@end


@interface FindFilesSheetController()

@property (nonatomic) bool didAnySearchStarted;
@property (nonatomic) bool searchingNow;

@property (nonatomic) IBOutlet NSButton            *CloseButton;
@property (nonatomic) IBOutlet NSButton            *SearchButton;
@property (nonatomic) IBOutlet NSButton            *GoToButton;
@property (nonatomic) IBOutlet NSButton            *ViewButton;
@property (nonatomic) IBOutlet NSButton            *PanelButton;
@property (nonatomic) IBOutlet NSComboBox          *MaskComboBox;
@property (nonatomic)          NSString            *MaskComboBoxValue;
@property (nonatomic) IBOutlet NSComboBox          *TextComboBox;
@property (nonatomic)          NSString            *TextComboBoxValue;
@property (nonatomic) IBOutlet NSTextField         *LookingIn;
@property (nonatomic) IBOutlet NSTableView         *TableView;
@property (nonatomic) IBOutlet NSButton            *CaseSensitiveButton;
@property (nonatomic) IBOutlet NSButton            *WholePhraseButton;
@property (nonatomic) IBOutlet NSArrayController   *ArrayController;
@property (nonatomic) IBOutlet NSPopUpButton       *SizeRelationPopUp;
@property (nonatomic) IBOutlet NSTextField         *SizeTextField;
@property (nonatomic)          NSString            *SizeTextFieldValue;
@property (nonatomic) IBOutlet NSPopUpButton       *SizeMetricPopUp;
@property (nonatomic) IBOutlet NSButton            *SearchInSubDirsButton;
@property (nonatomic) IBOutlet NSButton            *SearchInArchivesButton;
@property (nonatomic) IBOutlet NSPopUpButton       *EncodingsPopUp;
@property (nonatomic) IBOutlet NSPopUpButton       *searchForPopup;
@property (nonatomic) NSMutableArray            *FoundItems;
@property (nonatomic) FindFilesSheetFoundItem   *focusedItem; // may be nullptr

@end

@implementation FindFilesSheetController
{
    shared_ptr<VFSHost>         m_Host;
    string                      m_Path;
    unique_ptr<SearchForFiles>  m_FileSearch;
    NSDateFormatter            *m_DateFormatter;
    
    bool                        m_UIChanged;
    NSMutableArray             *m_FoundItems; // is controlled by ArrayController
    unique_ptr<FindFilesSheetComboHistory>  m_MaskHistory;
    unique_ptr<FindFilesSheetComboHistory>  m_TextHistory;
    
    NSMutableArray             *m_FoundItemsBatch;
    NSTimer                    *m_BatchDrainTimer;
    SerialQueue                 m_BatchQueue;
    DispatchGroup               m_StatGroup; // for native VFS
    SerialQueue                 m_StatQueue; // for custom VFS

    string                      m_LookingInPath;
    spinlock                    m_LookingInPathGuard;
    NSTimer                    *m_LookingInPathUpdateTimer;
    
    FindFilesSheetFoundItem    *m_DoubleClickedItem;
    function<void(const vector<VFSPath> &_filepaths)> m_OnPanelize;
}

@synthesize FoundItems = m_FoundItems;
@synthesize host = m_Host;
@synthesize path = m_Path;
@synthesize onPanelize = m_OnPanelize;

- (id) init
{
    self = [super init];
    if(self){
        m_FileSearch = make_unique<SearchForFiles>();
        m_FoundItems = [[NSMutableArray alloc] initWithCapacity:4096];
        m_FoundItemsBatch = [[NSMutableArray alloc] initWithCapacity:4096];

        m_MaskHistory = make_unique<FindFilesSheetComboHistory>(16, g_StateMaskHistory);
        m_TextHistory = make_unique<FindFilesSheetComboHistory>(16, g_StateTextHistory);
        
        self.focusedItem = nil;
        self.didAnySearchStarted = false;
        self.searchingNow = false;
        m_UIChanged = true;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    
    self.TableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    [self.TableView sizeToFit];
    
    self.ArrayController.sortDescriptors = @[
                                             [NSSortDescriptor sortDescriptorWithKey:@"location" ascending:YES],
                                             [NSSortDescriptor sortDescriptorWithKey:@"filename" ascending:YES],
                                             [NSSortDescriptor sortDescriptorWithKey:@"size" ascending:YES],
                                             [NSSortDescriptor sortDescriptorWithKey:@"mdate" ascending:YES]
                                             ];
    
    for(const auto &i: encodings::LiteralEncodingsList()) {
        NSMenuItem *item = [NSMenuItem new];
        item.title = (__bridge NSString*)i.second;
        item.tag = i.first;
        [self.EncodingsPopUp.menu addItem:item];
    }
    [self.EncodingsPopUp selectItemWithTag:encodings::ENCODING_UTF8];
    
    self.MaskComboBox.stringValue = m_MaskHistory->empty() ? @"*" : [NSString stringWithUTF8StdString:m_MaskHistory->front()];
    self.TextComboBox.stringValue = @"";
    
    // wire up hotkeys
    SheetWithHotkeys *sheet = (SheetWithHotkeys *)self.window;
    sheet.onCtrlT = [sheet makeFocusHotkey:self.TextComboBox];
    sheet.onCtrlM = [sheet makeFocusHotkey:self.MaskComboBox];
    sheet.onCtrlS = [sheet makeFocusHotkey:self.SizeTextField];
    sheet.onCtrlP = [sheet makeClickHotkey:self.PanelButton];
    sheet.onCtrlG = [sheet makeClickHotkey:self.GoToButton];
    sheet.onCtrlV = [sheet makeClickHotkey:self.ViewButton];
    
    if( !ActivationManager::Instance().HasTemporaryPanels() ) {
        [self.PanelButton unbind:@"enabled2"];
        [self.PanelButton unbind:@"enabled"];
        self.PanelButton.enabled = false;
    }
    if( !ActivationManager::Instance().HasInternalViewer() ) {
        [self.ViewButton unbind:@"enabled"];
        self.ViewButton.enabled = false;
    }
    if( !ActivationManager::Instance().HasArchivesBrowsing() ) {
        [self.SearchInArchivesButton  unbind:@"enabled"];
        self.SearchInArchivesButton.enabled = false;
    }
    
    GA().PostScreenView("Find Files");
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    try {
        if( item.action == @selector(OnFileInternalBigViewCommand:) )
            return [self Predicate_OnFileInternalBigViewCommand];
    }
    catch(exception &e) {
        cout << "Exception caught: " << e.what() << endl;
    }
    catch(...) {
        cout << "Caught an unhandled exception!" << endl;
    }
    return true;
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox;
{
    if(aComboBox == self.MaskComboBox)
        return m_MaskHistory->size();
    if(aComboBox == self.TextComboBox)
        return m_TextHistory->size();
    return 0;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index;
{
    if(aComboBox == self.MaskComboBox)
        return [NSString stringWithUTF8StdString:m_MaskHistory->at(index)];
    if(aComboBox == self.TextComboBox)
        return [NSString stringWithUTF8StdString:m_TextHistory->at(index)];
    return 0;
}

- (IBAction)OnClose:(id)sender
{
    if( NSEvent *ev = NSApp.currentEvent )
        if( ev.type == NSKeyDown && m_FileSearch->IsRunning() ) {
            // Close was triggered by Esc hotkey. just stop current search and don't close the dialog
            m_FileSearch->Stop();
            return;
        }
 
    m_FileSearch->Stop();
    m_FileSearch->Wait();
    m_OnPanelize = nullptr;
    [self endSheet:NSModalResponseOK];
}

- (void)onSearchFinished
{
    dispatch_assert_background_queue();
    m_StatGroup.Wait();
    m_StatQueue.Wait();

    [self UpdateByTimer:m_BatchDrainTimer];
    m_BatchQueue.Wait();
    m_StatQueue.Wait();
    
    dispatch_to_main_queue([=]{
        [m_BatchDrainTimer invalidate];
        m_BatchDrainTimer = nil;
        self.searchingNow = false;
  
        [m_LookingInPathUpdateTimer invalidate];
        m_LookingInPathUpdateTimer = nil;
        self.LookingIn.stringValue = @"";
        
        if( m_FoundItems.count > 0 ) {
            [self.window makeFirstResponder:self.TableView];
            [self.TableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:false];
        }
        
        [self setupReturnKey];
    });
}

- (int) searchOptionsFromUI
{
    int search_options = 0;
    if( self.SearchInSubDirsButton.intValue )
        search_options |= SearchForFiles::Options::GoIntoSubDirs;
    switch( self.searchForPopup.selectedTag ) {
        case 1:     search_options |= SearchForFiles::Options::SearchForFiles;  break;
        case 2:     search_options |= SearchForFiles::Options::SearchForDirs;   break;
        default:    search_options |= SearchForFiles::Options::SearchForDirs |
                                      SearchForFiles::Options::SearchForFiles;
    }
    if( self.SearchInArchivesButton.intValue )
        search_options |= SearchForFiles::Options::LookInArchives;
    return search_options;
}

- (SearchForFiles::FilterSize) searchFilterSizeFromUI
{
    uint64_t value = self.SizeTextFieldValue.integerValue;
    switch( self.SizeMetricPopUp.selectedTag ) {
        case 1: value *= 1024; break;
        case 2: value *= 1024*1024; break;
        case 3: value *= 1024*1024*1024; break;
        default: break;
    }
    SearchForFiles::FilterSize filter_size;
    if(self.SizeRelationPopUp.selectedTag == 0) // "≥"
        filter_size.min = value;
    else if(self.SizeRelationPopUp.selectedTag == 2) // "≤"
        filter_size.max = value;
    else if(self.SizeRelationPopUp.selectedTag == 1) // "="
        filter_size.min = filter_size.max = value;
    return filter_size;
}

- (IBAction)OnSearch:(id)sender
{
    if( m_FileSearch->IsRunning() ) {
        m_FileSearch->Stop();
        return;
    }

    NSRange range_all = NSMakeRange(0, [self.ArrayController.arrangedObjects count]);
    [self.ArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range_all]];
    
    m_FileSearch->ClearFilters();

    const auto mask = self.MaskComboBoxValue;
    if(mask != nil &&
       [mask isEqualToString:@""] == false &&
       [mask isEqualToString:@"*"] == false) {
        SearchForFiles::FilterName filter_name;
        filter_name.mask = mask.UTF8String;
        m_FileSearch->SetFilterName(filter_name);
        m_MaskHistory->insert_unique( mask.UTF8String );
    }
    else
        m_MaskHistory->insert_unique("*");
    
    const auto text_query = self.TextComboBoxValue;
    if( text_query.length ) {
        SearchForFiles::FilterContent filter_content;
        filter_content.text = text_query.UTF8String;
        filter_content.encoding = (int)self.EncodingsPopUp.selectedTag;
        filter_content.case_sensitive = self.CaseSensitiveButton.intValue;
        filter_content.whole_phrase = self.WholePhraseButton.intValue;
        m_FileSearch->SetFilterContent(filter_content);
    }
    m_TextHistory->insert_unique( text_query ? text_query.UTF8String : "" );
    
    m_FileSearch->SetFilterSize( self.searchFilterSizeFromUI );
    
    auto found_callback = [=](const char *_filename,
                              const char *_in_path,
                              VFSHost& _in_host,
                              CFRange _cont_pos){
        FindFilesSheetControllerFoundItem it;
        it.host = _in_host.SharedPtr();
        it.filename = _filename;
        it.dir_path = ensure_no_tr_slash(_in_path);
        it.full_filename = ensure_tr_slash(_in_path) + it.filename;
        it.content_pos = _cont_pos;
        it.rel_path = to_relative_path(it.host,
                                       ensure_tr_slash(_in_path),
                                       string(m_Host->JunctionPath()) + m_Path);
        
        
        // TODO: need some decent cancelling mechanics here
        auto stat_block = [=, it=move(it)]()mutable{
            // doing stat()'ing item in async background thread
            it.host->Stat(it.full_filename.c_str(), it.st, 0, 0);
            
            FindFilesSheetFoundItem *item = [[FindFilesSheetFoundItem alloc] initWithFoundItem:move(it)];
            m_BatchQueue.Run([self, item]{
                // dumping result entry into batch array in BatchQueue
                [m_FoundItemsBatch addObject:item];
            });
        };
        
        if( _in_host.IsNativeFS() )
            m_StatGroup.Run( move(stat_block) );
        else
            m_StatQueue.Run( move(stat_block) );
        
        if(m_FoundItems.count + m_FoundItemsBatch.count >= g_MaximumSearchResults)
            m_FileSearch->Stop(); // gorshochek, ne vari!!!
    };
    auto finish_callback = [=]{
        [self onSearchFinished];
    };
    auto lookin_in_callback = [=](const char *_path, VFSHost& _in_host) {
        auto verbose_path = _in_host.MakePathVerbose(_path);
        LOCK_GUARD(m_LookingInPathGuard)
            m_LookingInPath = move(verbose_path);
    };
    auto spawn_archive_callback = [=](const char*_for_path, VFSHost& _in_host)->VFSHostPtr {
        return [self spawnArchiveFromPath:_for_path inVFS:_in_host.SharedPtr()];
    };
    const bool started = m_FileSearch->Go(m_Path,
                                          m_Host,
                                          self.searchOptionsFromUI,
                                          move(found_callback),
                                          move(finish_callback),
                                          move(lookin_in_callback),
                                          move(spawn_archive_callback)
                                          );
    self.searchingNow = started;
    if(started) {
        self.didAnySearchStarted = true;
        m_UIChanged = false;
        m_BatchDrainTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 // 0.5 sec update
                                                             target:self
                                                           selector:@selector(UpdateByTimer:)
                                                           userInfo:nil
                                                            repeats:YES];
        [m_BatchDrainTimer setDefaultTolerance];

        m_LookingInPathUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 // 0.1 sec update
                                                             target:self
                                                           selector:@selector(updateLookingInByTimer:)
                                                           userInfo:nil
                                                            repeats:YES];
        [m_LookingInPathUpdateTimer setDefaultTolerance];
    }
}

- (VFSHostPtr)spawnArchiveFromPath:(const char*)_path inVFS:(const VFSHostPtr&)_host
{
    if( !ActivationManager::Instance().HasArchivesBrowsing() )
        return nullptr;
    
    char extension[MAXPATHLEN];
    if( !GetExtensionFromPath(_path, extension) )
        return nullptr;
    
    if( !nc::panel::IsExtensionInArchivesWhitelist(extension) )
        return nullptr;
    
    auto host = VFSArchiveProxy::OpenFileAsArchive(_path,
                                                   _host,
                                                   nullptr,
                                                   [&]{ return m_FileSearch->IsStopped(); } );
    if( host )
        if( self.vfsInstanceManager )
            self.vfsInstanceManager->TameVFS(host);
    
    return host;
}

- (void)updateLookingInByTimer:(NSTimer*)theTimer
{
    NSString *new_title;
    LOCK_GUARD(m_LookingInPathGuard)
        new_title = [NSString stringWithUTF8StdString:m_LookingInPath];
    self.LookingIn.stringValue = new_title;
}

- (void) UpdateByTimer:(NSTimer*)theTimer
{
    m_BatchQueue.Run([=]{
        if( m_FoundItemsBatch.count == 0 )
            return; // nothing to add
        
        NSArray *temp = m_FoundItemsBatch;
        m_FoundItemsBatch = [[NSMutableArray alloc] initWithCapacity:4096];
        
        dispatch_to_main_queue([=]{
            NSMutableArray *new_objects = [m_FoundItems mutableCopy];
            [new_objects addObjectsFromArray:temp];
            self.FoundItems = new_objects;
        });
    });
}

- (FindFilesSheetControllerFoundItem*) selectedItem
{
    if(m_DoubleClickedItem == nil)
        return nullptr;
    return m_DoubleClickedItem.data;
}

- (IBAction)doubleClick:(id)table
{
    NSInteger row = [self.TableView clickedRow];
    if(row < 0 || row >= self.TableView.numberOfRows)
        return;
    FindFilesSheetFoundItem *item = [self.ArrayController.arrangedObjects objectAtIndex:row];
    m_DoubleClickedItem = item;
    [self OnClose:self];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    NSInteger row = [self.TableView selectedRow];
    if(row >= 0)
        self.focusedItem = (FindFilesSheetFoundItem *)[self.ArrayController.arrangedObjects objectAtIndex:row];
    else
        self.focusedItem = nil;
}

- (IBAction)OnGoToFile:(id)sender
{
    if( self.focusedItem ) {
        m_DoubleClickedItem = self.focusedItem;
        [self OnClose:self];
    }
}

- (bool)Predicate_OnFileInternalBigViewCommand
{
    return self.ViewButton.enabled;
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender
{
    [self OnFileView:sender];
}

- (IBAction)OnFileView:(id)sender
{
    dispatch_assert_main_queue();
    NSInteger row = self.TableView.selectedRow;
    FindFilesSheetFoundItem *item = [self.ArrayController.arrangedObjects objectAtIndex:row];
    FindFilesSheetControllerFoundItem *data = item.data;
    
    string p = data->full_filename;
    VFSHostPtr vfs = data->host;
    CFRange cont = data->content_pos;
    NSString *search_req = self.TextComboBox.stringValue;
    
    if( GlobalConfig().GetBool(g_ConfigModalInternalViewer) ) { // as a sheet
        BigFileViewSheet *sheet = [[BigFileViewSheet alloc] initWithFilepath:p at:vfs];
        dispatch_to_background([=]{
            const auto success = [sheet open];
            dispatch_to_main_queue([=]{
                // make sure that 'sheet' will be destroyed in main queue
                if( success ) {
                    [sheet beginSheetForWindow:self.window];
                    if(cont.location >= 0)
                        [sheet markInitialSelection:cont searchTerm:search_req.UTF8String];
                }
            });
        });
    }
    else { // as a window
        if( InternalViewerWindowController *window = [NCAppDelegate.me findInternalViewerWindowForPath:p onVFS:vfs]  ) {
            // already has this one
            [window showWindow:self];
            
            if(cont.location >= 0)
                [window markInitialSelection:cont searchTerm:search_req.UTF8String];
        }
        else {
            // need to create a new one
            window = [[InternalViewerWindowController alloc] initWithFilepath:p at:vfs];
            dispatch_to_background([=]{
                if( [window performBackgrounOpening] ) {
                    dispatch_to_main_queue([=]{
                        [window showAsFloatingWindow];
                        if(cont.location >= 0)
                            [window markInitialSelection:cont searchTerm:search_req.UTF8String];
                    });
                }
            });
        }
    }
}

// Workaround about combox' menu forcing Search by selecting item from list with Return key
- (void)comboBoxWillPopUp:(NSNotification *)notification
{
    [self clearReturnKey];
}

- (void)comboBoxWillDismiss:(NSNotification *)notification
{
    dispatch_to_main_queue_after(10ms, [=]{
        [self setupReturnKey];
    });
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    [self onSearchSettingsUIChanged:obj.object];
}

- (IBAction)onSearchSettingsUIChanged:(id)sender
{
    m_UIChanged = true;
    [self setupReturnKey];
}

- (IBAction)OnPanelize:(id)sender
{
    if( m_OnPanelize ) {
        vector<VFSPath> results;
        for( FindFilesSheetFoundItem *item in self.ArrayController.arrangedObjects ) {
            auto d = item.data;
            results.emplace_back( d->host, d->full_filename );
        }

        if( !results.empty() )
            m_OnPanelize( results );
    }
    
    [self OnClose:self];
}

- (void) setupReturnKey
{
    dispatch_assert_main_queue();
    
    [self clearReturnKey];
    
    if( m_FoundItems.count > 0 && !m_UIChanged ) {
        self.GoToButton.keyEquivalent = @"\r";
    }
    else {
        // either never searched or didn't find anything
        self.SearchButton.keyEquivalent = @"\r";
    }
}

- (void) clearReturnKey
{
    dispatch_assert_main_queue();
    self.SearchButton.keyEquivalent = @"";
    self.GoToButton.keyEquivalent = @"";
}

- (BOOL)tableView:(NSTableView *)tableView
shouldTypeSelectForEvent:(NSEvent *)event
withCurrentSearchString:(NSString *)searchString
{
    if( event.charactersIgnoringModifiers.length == 1 &&
        [event.charactersIgnoringModifiers characterAtIndex:0] == 0x20 ) {
        // treat Spacebar as View button
        dispatch_to_main_queue([=]{
            [self OnFileView:self];
        });
        return false;
    }
    return true;
}

@end
