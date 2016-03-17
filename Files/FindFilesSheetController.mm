//
//  FindFileSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 12.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/dispatch_cpp.h>
#include <Utility/NSTimer+Tolerance.h>
#include <Utility/SheetWithHotkeys.h>
#include "States/Viewer/BigFileViewSheet.h"
#include "Utility/Encodings.h"
#include "FindFilesSheetController.h"
#include "FileSearch.h"
#include "ByteCountFormatter.h"
#include "AppDelegate.h"
#include "Config.h"

static NSString *g_MaskHistoryKey = @"FilePanelsSearchMaskHistory";
static const auto g_StateMaskHistory = "filePanel.findFilesSheet.maskHistory";
static NSString *g_TextHistoryKey = @"FilePanelsSearchTextHistory";
static const auto g_StateTextHistory = "filePanel.findFilesSheet.textHistory";
static const int g_MaximumSearchResults = 262144;

class FindFilesSheetComboHistory : public vector<string>
{
public:
    FindFilesSheetComboHistory( int _max, const char *_config_path, NSString *_defaults_migration_path ):
        m_Path(_config_path),
        m_Max(_max)
    {

        if( auto history = [NSUserDefaults.standardUserDefaults arrayForKey:_defaults_migration_path] ) {
            // load history from previous defaults and remove that key
            for( NSObject *e in history )
                if( auto s = objc_cast<NSString>(e) )
                    emplace_back( s.UTF8String );
            [NSUserDefaults.standardUserDefaults removeObjectForKey:_defaults_migration_path];
        }
        else {
            auto arr = StateConfig().Get(m_Path);
            if( arr.GetType() == rapidjson::kArrayType )
                for( auto i = arr.Begin(), e = arr.End(); i != e; ++i )
                    if( i->GetType() == rapidjson::kStringType )
                        emplace_back( i->GetString() );
        }
    }
    
    ~FindFilesSheetComboHistory()
    {
        GenericConfig::ConfigValue arr(rapidjson::kArrayType);
        for( auto &s: *this )
            arr.PushBack( GenericConfig::ConfigValue(s.c_str(), GenericConfig::g_CrtAllocator), GenericConfig::g_CrtAllocator );
        StateConfig().Set(m_Path, arr);
    }
    
    void insert_unique( const string &_value )
    {
        erase( remove_if(begin(), end(), [&](auto &_s) { return _s == _value; }), end() );
        insert( begin(), _value );
        while( size() > m_Max ) pop_back();
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
+ (void) initialize
{
    [NSValueTransformer setValueTransformer:[[self alloc] init]
                                    forName:NSStringFromClass(self.class)];
}
+ (Class)transformedValueClass
{
	return [NSString class];
}
- (id)transformedValue:(id)value
{
    return (value == nil) ? nil : ByteCountFormatter::Instance().ToNSString([value unsignedLongLongValue], ByteCountFormatter::Fixed6);
}
@end

@interface FindFilesSheetTimeToStringTransformer : NSValueTransformer
@end
@implementation FindFilesSheetTimeToStringTransformer
+ (void) initialize
{
    [NSValueTransformer setValueTransformer:[[self alloc] init]
                                    forName:NSStringFromClass(self.class)];
}
+ (Class)transformedValueClass
{
	return [NSString class];
}
- (id)transformedValue:(id)value
{
    static NSDateFormatter *formatter;
    static once_flag once;
    call_once(once, []{
        formatter = [NSDateFormatter new];
        [formatter setLocale:[NSLocale currentLocale]];
        [formatter setDateStyle:NSDateFormatterShortStyle];	// short date
    });
    
    if(value == nil)
        return nil;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[value unsignedLongLongValue]];
    return [formatter stringFromDate:date];
}
@end


@implementation FindFilesSheetController
{
    shared_ptr<VFSHost>         m_Host;
    string                      m_Path;
    unique_ptr<FileSearch>      m_FileSearch;
    NSDateFormatter            *m_DateFormatter;
    
    NSMutableArray             *m_FoundItems; // is controlled by ArrayController
    atomic_bool                 m_ControllerIsAdding;
    unique_ptr<FindFilesSheetComboHistory>  m_MaskHistory;
    unique_ptr<FindFilesSheetComboHistory>  m_TextHistory;
    
    NSMutableArray             *m_FoundItemsBatch;
    NSTimer                    *m_BatchDrainTimer;
    SerialQueue                 m_BatchQueue;
    DispatchGroup               m_StatGroup;

    string                      m_LookingInPath;
    spinlock                    m_LookingInPathGuard;
    NSTimer                    *m_LookingInPathUpdateTimer;
    
    FindFilesSheetFoundItem    *m_DoubleClickedItem;
    void                        (^m_Handler)();
    function<void(const map<string, vector<string>>&_dir_to_filenames)> m_OnPanelize;
}

@synthesize FoundItems = m_FoundItems;
@synthesize host = m_Host;
@synthesize path = m_Path;
@synthesize OnPanelize = m_OnPanelize;

- (id) init
{
    self = [super init];
    if(self){
        m_FileSearch.reset(new FileSearch);
        m_FoundItems = [NSMutableArray new];
        m_FoundItemsBatch = [NSMutableArray new];

        m_MaskHistory = make_unique<FindFilesSheetComboHistory>(16, g_StateMaskHistory, g_MaskHistoryKey);
        m_TextHistory = make_unique<FindFilesSheetComboHistory>(16, g_StateTextHistory, g_TextHistoryKey);
        
        m_BatchQueue = SerialQueueT::Make();
        self.focusedItem = nil;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.TableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    [self.TableView sizeToFit];
    self.TableView.delegate = self;
    self.TableView.target = self;
    self.TableView.doubleAction = @selector(doubleClick:);
    
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
    
    self.MaskComboBox.usesDataSource = true;
    self.MaskComboBox.dataSource = self;
    self.MaskComboBox.stringValue = m_MaskHistory->empty() ? @"*" : [NSString stringWithUTF8StdString:m_MaskHistory->front()];
    self.TextComboBox.usesDataSource = true;
    self.TextComboBox.dataSource = self;
    self.TextComboBox.stringValue = @"";
  
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(comboBoxWillPopUp:)
                                               name:@"NSComboBoxWillPopUpNotification"
                                             object:self.MaskComboBox];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(comboBoxWillDismiss:)
                                               name:@"NSComboBoxWillDismissNotification"
                                             object:self.MaskComboBox];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(comboBoxWillPopUp:)
                                               name:@"NSComboBoxWillPopUpNotification"
                                             object:self.TextComboBox];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(comboBoxWillDismiss:)
                                               name:@"NSComboBoxWillDismissNotification"
                                             object:self.TextComboBox];
    
    // wire up hotkeys
    SheetWithHotkeys *sheet = (SheetWithHotkeys *)self.window;
    sheet.onCtrlT = [sheet makeFocusHotkey:self.TextComboBox];
    sheet.onCtrlM = [sheet makeFocusHotkey:self.MaskComboBox];
    sheet.onCtrlS = [sheet makeFocusHotkey:self.SizeTextField];
    sheet.onCtrlP = [sheet makeClickHotkey:self.PanelButton];
    if( configuration::version == configuration::Version::Lite ) {
        self.PanelButton.target = AppDelegate.me;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector"
        self.PanelButton.action = @selector(showFeatureNotSupportedWindow:);
#pragma clang diagnostic pop
    }
    sheet.onCtrlV = [sheet makeClickHotkey:self.ViewButton];
    if( configuration::version == configuration::Version::Lite ) {
        self.ViewButton.target = AppDelegate.me;
        self.ViewButton.action = @selector(showFeatureNotSupportedWindow:);
    }
}

- (void) dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
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

- (void) OnFinishedSearch
{
    m_StatGroup.Wait();

    [self UpdateByTimer:m_BatchDrainTimer];
    m_BatchQueue->Wait();
    
    dispatch_to_main_queue([=]{
        [m_BatchDrainTimer invalidate];
        m_BatchDrainTimer = nil;
        self.SearchButton.state = NSOffState;
  
        [m_LookingInPathUpdateTimer invalidate];
        m_LookingInPathUpdateTimer = nil;
        self.LookingIn.stringValue = @"";
        
        if( [self.ArrayController.arrangedObjects count] > 0 )
            [self.window makeFirstResponder:self.TableView];
    });
}

- (IBAction)OnSearch:(id)sender
{
    if(m_FileSearch->IsRunning()) {
        m_FileSearch->Stop();
        return;
    }

    NSRange range_all = NSMakeRange(0, [self.ArrayController.arrangedObjects count]);
    [self.ArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range_all]];
    m_ControllerIsAdding = false;
    
    m_FileSearch->ClearFilters();
    
    NSString *mask = self.MaskComboBox.stringValue;
    if(mask != nil &&
       [mask isEqualToString:@""] == false &&
       [mask isEqualToString:@"*"] == false) {
        FileSearch::FilterName filter_name;
        filter_name.mask = mask;
        m_FileSearch->SetFilterName(filter_name);
        m_MaskHistory->insert_unique( mask.UTF8String );
    }
    else
        m_MaskHistory->insert_unique("*");
    
    NSString *cont_text = self.TextComboBox.stringValue;
    if([cont_text isEqualToString:@""] == false) {
        FileSearch::FilterContent filter_content;
        filter_content.text = cont_text;
        filter_content.encoding = (int)self.EncodingsPopUp.selectedTag;
        filter_content.case_sensitive = self.CaseSensitiveButton.intValue;
        filter_content.whole_phrase = self.WholePhraseButton.intValue;
        m_FileSearch->SetFilterContent(filter_content);
    }
    m_TextHistory->insert_unique( cont_text ? cont_text.UTF8String : "" );
    
    if([self.SizeTextField.stringValue isEqualToString:@""] == false)
    {
        uint64_t value = self.SizeTextField.integerValue;
        switch (self.SizeMetricPopUp.selectedTag) {
            case 1: value *= 1024; break;
            case 2: value *= 1024*1024; break;
            case 3: value *= 1024*1024*1024; break;
            default: break;
        }
        FileSearch::FilterSize filter_size;
        if(self.SizeRelationPopUp.selectedTag == 0) // "≥"
            filter_size.min = value;
        else if(self.SizeRelationPopUp.selectedTag == 2) // "≤"
            filter_size.max = value;
        else if(self.SizeRelationPopUp.selectedTag == 1) // "="
            filter_size.min = filter_size.max = value;
        
        m_FileSearch->SetFilterSize(filter_size);
    }
        
    int search_options = 0;
    if(self.SearchInSubDirsButton.intValue)
        search_options |= FileSearch::Options::GoIntoSubDirs;
    if(self.SearchForDirsButton.intValue)
        search_options |= FileSearch::Options::SearchForDirs;
    
    bool r = m_FileSearch->Go(m_Path,
                              m_Host,
                              search_options,
                              [=](const char *_filename, const char *_in_path, CFRange _cont_pos){
                                  FindFilesSheetControllerFoundItem it;
                                  it.filename = _filename;
                                  it.dir_path = _in_path;
                                  
                                  it.full_filename = it.dir_path;
                                  if(it.full_filename.back() != '/') it.full_filename += '/';
                                  it.full_filename += it.filename;
                                  if(it.dir_path != "/" && it.dir_path.back() == '/') it.dir_path.pop_back();
                                  
                                  it.content_pos = _cont_pos;
                                  
                                  it.rel_path = it.dir_path;
                                  if(it.rel_path.back() != '/') it.rel_path.push_back('/');
                                  if(m_Path.length() > 1 && it.rel_path.find(m_Path) == 0)
                                      it.rel_path.replace(0, m_Path.length(), "./");
                                  
                                  m_StatGroup.Run([=, it=move(it)]()mutable{
                                      // doing stat()'ing item in async background thread
                                      m_Host->Stat(it.full_filename.c_str(), it.st, 0, 0);
                                      
                                      FindFilesSheetFoundItem *item = [[FindFilesSheetFoundItem alloc] initWithFoundItem:move(it)];
                                      m_BatchQueue->Run([self, item]{
                                          // dumping result entry into batch array in BatchQueue
                                          [m_FoundItemsBatch addObject:item];
                                      });
                                  });
                                  
                                  if(m_FoundItems.count + m_FoundItemsBatch.count >= g_MaximumSearchResults)
                                      m_FileSearch->Stop(); // gorshochek, ne vari!!!
                              },
                              [=]{
                                  [self OnFinishedSearch];
                              },
                              [=](const char *_path) {
                                  LOCK_GUARD(m_LookingInPathGuard)
                                    m_LookingInPath = _path;
                              }
                              );
    if(r) {
        self.SearchButton.state = NSOnState;
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
    else {
        self.SearchButton.state = NSOffState;
    }
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
    m_BatchQueue->Run([=]{
        if( m_FoundItemsBatch.count == 0 )
            return; // nothing to add
        if( m_ControllerIsAdding )
            return; // controller is already adding objects from a previous batch. skip this iteration to decrease main thread saturation
        
        NSArray *temp = m_FoundItemsBatch;
        m_FoundItemsBatch = [NSMutableArray new];
        
        dispatch_to_main_queue([=]{
            m_ControllerIsAdding = true;
            [self.ArrayController addObjects:temp];
            m_ControllerIsAdding = false;
        });
    });
}

- (FindFilesSheetControllerFoundItem*) SelectedItem
{
    if(m_DoubleClickedItem == nil)
        return nullptr;
    return m_DoubleClickedItem.data;
}

- (void)doubleClick:(id)table
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

- (IBAction)OnFileView:(id)sender
{
    NSInteger row = [self.TableView selectedRow];
    FindFilesSheetFoundItem *item = [self.ArrayController.arrangedObjects objectAtIndex:row];
    FindFilesSheetControllerFoundItem *data = item.data;
    
    string p = data->full_filename;
    VFSHostPtr vfs = self.host;
    CFRange cont = data->content_pos;
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        BigFileViewSheet *sheet = [[BigFileViewSheet alloc] initWithFilepath:p at:vfs];
        if([sheet open]) {
            if(cont.location >= 0)
                [sheet selectBlockAt:cont.location length:cont.length];
            [sheet beginSheetForWindow:self.window
                     completionHandler:^(NSModalResponse returnCode) {}];
        }
    });
}

// Workaround about combox' menu forcing Search by selecting item from list with Return key
- (void)comboBoxWillPopUp:(NSNotification *)notification
{
    self.SearchButton.keyEquivalent = @"";
}

- (void)comboBoxWillDismiss:(NSNotification *)notification
{
    dispatch_to_main_queue_after(10ms, [=]{
        self.SearchButton.keyEquivalent = @"\r";
    });
}

- (IBAction)OnPanelize:(id)sender
{
    map<string, vector<string>> results; // directory->filenames
    for( FindFilesSheetFoundItem *item in self.ArrayController.arrangedObjects ) {
        auto d = item.data;
        results[d->dir_path].emplace_back( d->filename );
    }

    if( results.empty() )
        return;
    
    if( m_OnPanelize )
        m_OnPanelize( results );
    
    [self OnClose:self];
}

@end
