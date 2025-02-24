// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FindFilesSheetController.h"
#include <Base/DispatchGroup.h>
#include <Base/dispatch_cpp.h>
#include <Config/RapidJSON.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Core/VFSInstanceManager.h>
#include <NimbleCommander/Core/VFSInstancePromise.h>
#include <NimbleCommander/States/FilePanels/PanelAux.h>
#include <Panel/FindFilesData.h>
#include <Utility/ByteCountFormatter.h>
#include <Utility/Encodings.h>
#include <Utility/NSTimer+Tolerance.h>
#include <Utility/ObjCpp.h>
#include <Utility/PathManip.h>
#include <Utility/SheetWithHotkeys.h>
#include <Utility/StringExtras.h>
#include <VFS/SearchForFiles.h>
#include <algorithm>
#include <fmt/format.h>
#include <iostream>

static const auto g_StateMaskHistory = "filePanel.findFilesSheet.maskHistory";
static const auto g_StateTextHistory = "filePanel.findFilesSheet.textHistory";
static const int g_MaximumSearchResults = 262144;

static constexpr size_t g_MaximumMaskHistoryElements = 16;

using namespace nc::panel;
using nc::vfs::SearchForFiles;

static std::string ensure_tr_slash(std::string _str)
{
    if( _str.empty() || _str.back() != '/' )
        _str += '/';
    return _str;
}

static std::string ensure_no_tr_slash(std::string _str)
{
    if( _str.empty() || _str == "/" )
        return _str;

    if( _str.back() == '/' )
        _str.pop_back();

    return _str;
}

static std::string to_relative_path(const VFSHostPtr &_in_host, std::string _path, const std::string &_base_path)
{
    VFSHostPtr a = _in_host;
    while( a ) {
        _path.insert(0, a->JunctionPath());
        a = a->Parent();
    }

    if( _base_path.length() > 1 && _path.starts_with(_base_path) )
        _path.replace(0, _base_path.length(), "./");
    return _path;
}

class FindFilesSheetComboHistory : public std::vector<std::string>
{
public:
    FindFilesSheetComboHistory(int _max, const char *_config_path) : m_Max(_max), m_Path(_config_path)
    {
        auto arr = StateConfig().Get(m_Path);
        if( arr.GetType() == rapidjson::kArrayType )
            for( auto i = arr.Begin(), e = arr.End(); i != e; ++i )
                if( i->GetType() == rapidjson::kStringType )
                    emplace_back(i->GetString());
    }

    ~FindFilesSheetComboHistory()
    {
        nc::config::Value arr(rapidjson::kArrayType);
        for( auto &s : *this )
            arr.PushBack(nc::config::Value(s.c_str(), nc::config::g_CrtAllocator), nc::config::g_CrtAllocator);
        StateConfig().Set(m_Path, arr);
    }

    void insert_unique(const std::string &_value)
    {
        std::erase_if(*this, [&](auto &_s) { return _s == _value; });
        insert(begin(), _value);
        while( size() > static_cast<size_t>(m_Max) )
            pop_back();
    }

private:
    const int m_Max;
    const char *m_Path;
};

@interface FindFilesSheetFoundItem : NSObject
@property(nonatomic, readonly) const FindFilesSheetControllerFoundItem &data;
@property(nonatomic, readonly) NSString *location;
@property(nonatomic, readonly) NSString *filename;
@property(nonatomic, readonly) uint64_t size;
@property(nonatomic, readonly) uint64_t mdate;
@end

@implementation FindFilesSheetFoundItem {
    FindFilesSheetControllerFoundItem m_Data;
    NSString *m_Location;
    NSString *m_Filename;
}

@synthesize location = m_Location;
@synthesize filename = m_Filename;

- (id)initWithFoundItem:(FindFilesSheetControllerFoundItem &&)_item
{
    self = [super init];
    if( self ) {
        m_Data = std::move(_item);
        m_Location = [NSString stringWithUTF8StdString:m_Data.rel_path];
        m_Filename = [NSString stringWithUTF8StdString:m_Data.filename];
    }
    return self;
}

- (uint64_t)size
{
    return m_Data.st.mode_bits.dir ? std::numeric_limits<uint64_t>::max() : m_Data.st.size;
}

- (uint64_t)mdate
{
    return m_Data.st.mtime.tv_sec;
}

- (const FindFilesSheetControllerFoundItem &)data
{
    return m_Data;
}

@end

@interface FindFilesSheetSizeToStringTransformer : NSValueTransformer
@end
@implementation FindFilesSheetSizeToStringTransformer
+ (Class)transformedValueClass
{
    return NSString.class;
}
- (id)transformedValue:(id)_value
{
    if( _value == nil )
        return nil;

    const uint64_t val = [_value unsignedLongLongValue];
    if( val == std::numeric_limits<uint64_t>::max() ) {
        return NSLocalizedString(@"__MODERNPRESENTATION_FOLDER_WORD",
                                 "Folders dummy string when size is not available, for English is 'Folder'");
    }
    else {
        const auto &bf = ByteCountFormatter::Instance();
        return bf.ToNSString(val, ByteCountFormatter::Fixed6);
    }
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
    static std::once_flag once;
    std::call_once(once, [] {
        formatter = [NSDateFormatter new];
        formatter.locale = NSLocale.currentLocale;
        formatter.dateStyle = NSDateFormatterShortStyle;
    });

    if( value == nil )
        return nil;
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:static_cast<double>([value unsignedLongLongValue])];
    return [formatter stringFromDate:date];
}
@end

@interface FindFilesSheetController ()

@property(nonatomic) bool didAnySearchStarted;
@property(nonatomic) bool searchingNow;

@property(nonatomic) IBOutlet NSButton *CloseButton;
@property(nonatomic) IBOutlet NSButton *SearchButton;
@property(nonatomic) IBOutlet NSButton *GoToButton;
@property(nonatomic) IBOutlet NSButton *ViewButton;
@property(nonatomic) IBOutlet NSButton *PanelButton;
@property(nonatomic) IBOutlet NSSearchField *maskSearchField;
@property(nonatomic) IBOutlet NSSearchField *textSearchField;
@property(nonatomic) IBOutlet NSTextField *LookingIn;
@property(nonatomic) IBOutlet NSTableView *TableView;
@property(nonatomic) IBOutlet NSArrayController *ArrayController;
@property(nonatomic) IBOutlet NSPopUpButton *SizeRelationPopUp;
@property(nonatomic) IBOutlet NSTextField *SizeTextField;
@property(nonatomic) NSString *SizeTextFieldValue;
@property(nonatomic) IBOutlet NSPopUpButton *SizeMetricPopUp;
@property(nonatomic) IBOutlet NSButton *SearchInSubDirsButton;
@property(nonatomic) IBOutlet NSButton *SearchInArchivesButton;
@property(nonatomic) IBOutlet NSPopUpButton *searchForPopup;
@property(nonatomic) NSMutableArray *FoundItems;
@property(nonatomic) FindFilesSheetFoundItem *focusedItem; // may be nullptr
@property(nonatomic) bool focusedItemIsReg;
@property(nonatomic) bool filenameMaskIsOk;

@end

@implementation FindFilesSheetController {
    std::shared_ptr<VFSHost> m_Host;
    std::string m_Path;
    std::unique_ptr<SearchForFiles> m_FileSearch;
    NSDateFormatter *m_DateFormatter;

    bool m_UIChanged;
    NSMutableArray *m_FoundItems; // is controlled by ArrayController

    bool m_RegexSearch;
    bool m_CaseSensitiveTextSearch;
    bool m_WholePhraseTextSearch;
    bool m_NotContainingTextSearch;
    nc::utility::Encoding m_TextSearchEncoding;

    std::vector<nc::panel::FindFilesMask> m_MaskHistory;
    std::unique_ptr<FindFilesSheetComboHistory> m_TextHistory;

    NSMutableArray *m_FoundItemsBatch;
    NSTimer *m_BatchDrainTimer;
    nc::base::SerialQueue m_BatchQueue;
    nc::base::DispatchGroup m_StatGroup; // for native VFS
    nc::base::SerialQueue m_StatQueue;   // for custom VFS

    std::string m_LookingInPath;
    std::mutex m_LookingInPathGuard;
    NSTimer *m_LookingInPathUpdateTimer;

    FindFilesSheetFoundItem *m_DoubleClickedItem;
    std::function<void(const std::vector<nc::vfs::VFSPath> &_filepaths)> m_OnPanelize;
    std::function<void(const nc::panel::FindFilesSheetViewRequest &)> m_OnView;
}

@synthesize FoundItems = m_FoundItems;
@synthesize host = m_Host;
@synthesize path = m_Path;
@synthesize onPanelize = m_OnPanelize;
@synthesize onView = m_OnView;
@synthesize vfsInstanceManager;
@synthesize didAnySearchStarted;
@synthesize searchingNow;
@synthesize CloseButton;
@synthesize SearchButton;
@synthesize GoToButton;
@synthesize ViewButton;
@synthesize PanelButton;
@synthesize maskSearchField;
@synthesize textSearchField;
@synthesize LookingIn;
@synthesize TableView;
@synthesize ArrayController;
@synthesize SizeRelationPopUp;
@synthesize SizeTextField;
@synthesize SizeTextFieldValue;
@synthesize SizeMetricPopUp;
@synthesize SearchInSubDirsButton;
@synthesize SearchInArchivesButton;
@synthesize searchForPopup;
@synthesize focusedItem;
@synthesize focusedItemIsReg;
@synthesize filenameMaskIsOk;

- (instancetype)init
{
    self = [super init];
    if( self ) {
        m_FileSearch = std::make_unique<SearchForFiles>();
        m_FoundItems = [[NSMutableArray alloc] initWithCapacity:4096];
        m_FoundItemsBatch = [[NSMutableArray alloc] initWithCapacity:4096];
        m_RegexSearch = false;
        m_CaseSensitiveTextSearch = false;
        m_WholePhraseTextSearch = false;
        m_NotContainingTextSearch = false;
        m_TextSearchEncoding = nc::utility::Encoding::ENCODING_UTF8;
        m_MaskHistory = nc::panel::LoadFindFilesMasks(StateConfig(), g_StateMaskHistory);
        m_TextHistory = std::make_unique<FindFilesSheetComboHistory>(16, g_StateTextHistory);
        m_UIChanged = true;
        self.focusedItem = nil;
        self.focusedItemIsReg = false;
        self.didAnySearchStarted = false;
        self.searchingNow = false;
        self.filenameMaskIsOk = true;
    }
    return self;
}

- (void)dealloc
{
    nc::panel::StoreFindFilesMasks(StateConfig(), g_StateMaskHistory, m_MaskHistory);
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    self.TableView.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    [self.TableView sizeToFit];

    self.ArrayController.sortDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"location" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"filename" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"size" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"mdate" ascending:YES]
    ];

    [self updateMasksMenu];
    [self updateMaskSearchFieldPrompt];
    nc::objc_cast<NSSearchFieldCell>(self.maskSearchField.cell).cancelButtonCell = nil;
    self.maskSearchField.stringValue = @"*";

    [self updateTextMenu];
    nc::objc_cast<NSSearchFieldCell>(self.textSearchField.cell).cancelButtonCell = nil;

    // wire up the hotkeys
    NCSheetWithHotkeys *sheet = static_cast<NCSheetWithHotkeys *>(self.window);
    sheet.onCtrlT = [sheet makeFocusHotkey:self.textSearchField];
    sheet.onCtrlM = [sheet makeFocusHotkey:self.maskSearchField];
    sheet.onCtrlS = [sheet makeFocusHotkey:self.SizeTextField];
    sheet.onCtrlI = [sheet makeFocusHotkey:self.TableView];
    sheet.onCtrlP = [sheet makeClickHotkey:self.PanelButton];
    sheet.onCtrlG = [sheet makeClickHotkey:self.GoToButton];
    sheet.onCtrlV = [sheet makeClickHotkey:self.ViewButton];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    try {
        if( item.action == @selector(OnFileInternalBigViewCommand:) )
            return [self Predicate_OnFileInternalBigViewCommand];
    } catch( const std::exception &e ) {
        std::cout << "Exception caught: " << e.what() << '\n';
    } catch( ... ) {
        std::cout << "Caught an unhandled exception!" << '\n';
    }
    return true;
}

- (IBAction)OnClose:(id) [[maybe_unused]] _sender
{
    if( NSEvent *ev = NSApp.currentEvent )
        if( ev.type == NSEventTypeKeyDown && m_FileSearch->IsRunning() ) {
            // Close was triggered by Esc hotkey. just stop current search and don't close the
            // dialog
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

    dispatch_to_main_queue([=] {
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

- (int)searchOptionsFromUI
{
    int search_options = 0;
    if( self.SearchInSubDirsButton.intValue )
        search_options |= SearchForFiles::Options::GoIntoSubDirs;
    switch( self.searchForPopup.selectedTag ) {
        case 1:
            search_options |= SearchForFiles::Options::SearchForFiles;
            break;
        case 2:
            search_options |= SearchForFiles::Options::SearchForDirs;
            break;
        default:
            search_options |= SearchForFiles::Options::SearchForDirs | SearchForFiles::Options::SearchForFiles;
    }
    if( self.SearchInArchivesButton.intValue )
        search_options |= SearchForFiles::Options::LookInArchives;
    return search_options;
}

- (SearchForFiles::FilterSize)searchFilterSizeFromUI
{
    uint64_t value = self.SizeTextFieldValue.integerValue;
    switch( self.SizeMetricPopUp.selectedTag ) {
        case 1:
            value *= 1024ULL;
            break;
        case 2:
            value *= 1024ULL * 1024ULL;
            break;
        case 3:
            value *= 1024ULL * 1024ULL * 1024ULL;
            break;
        default:
            break;
    }
    SearchForFiles::FilterSize filter_size;
    if( self.SizeRelationPopUp.selectedTag == 0 ) // "≥"
        filter_size.min = value;
    else if( self.SizeRelationPopUp.selectedTag == 2 ) // "≤"
        filter_size.max = value;
    else if( self.SizeRelationPopUp.selectedTag == 1 ) // "="
        filter_size.min = filter_size.max = value;
    return filter_size;
}

- (IBAction)OnSearch:(id) [[maybe_unused]] _sender
{
    using nc::utility::FileMask;
    if( m_FileSearch->IsRunning() ) {
        m_FileSearch->Stop();
        return;
    }

    NSRange range_all = NSMakeRange(0, [self.ArrayController.arrangedObjects count]);
    [self.ArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range_all]];

    // by default - clear any all filter
    m_FileSearch->ClearFilters();

    // set the filename filter if any is specified
    const auto filename_mask = [self filenameEffectiveMask];
    const auto filename_mask_type = [self filenameMaskType];
    if( !filename_mask.empty() ) {
        m_FileSearch->SetFilterName(FileMask{filename_mask, filename_mask_type});

        // memorize the query
        FindFilesMask history_entry;
        history_entry.string = filename_mask;
        history_entry.type = m_RegexSearch ? nc::panel::FindFilesMask::RegEx : nc::panel::FindFilesMask::Classic;
        [self insertFindFilesMaskIntoHistory:history_entry];
    }

    const auto text_query = self.textSearchField.stringValue ? self.textSearchField.stringValue : @"";
    if( text_query.length ) {
        SearchForFiles::FilterContent filter_content;
        filter_content.text = text_query.fileSystemRepresentationSafe;
        filter_content.encoding = m_TextSearchEncoding;
        filter_content.case_sensitive = m_CaseSensitiveTextSearch;
        filter_content.whole_phrase = m_WholePhraseTextSearch;
        filter_content.not_containing = m_NotContainingTextSearch;
        m_FileSearch->SetFilterContent(filter_content);

        // memorize the query
        m_TextHistory->insert_unique(filter_content.text);
    }

    m_FileSearch->SetFilterSize(self.searchFilterSizeFromUI);

    auto found_callback = [=](const char *_filename, const char *_in_path, VFSHost &_in_host, CFRange _cont_pos) {
        FindFilesSheetControllerFoundItem it;
        it.host = _in_host.SharedPtr();
        it.filename = _filename;
        it.dir_path = ensure_no_tr_slash(_in_path);
        it.full_filename = ensure_tr_slash(_in_path) + it.filename;
        it.content_pos = _cont_pos;
        it.rel_path =
            to_relative_path(it.host, ensure_tr_slash(_in_path), fmt::format("{}{}", m_Host->JunctionPath(), m_Path));

        // TODO: need some decent cancelling mechanics here
        auto stat_block = [self, it = std::move(it)]() mutable {
            // doing stat()'ing item in async background thread
            it.st = it.host->Stat(it.full_filename, 0).value_or(VFSStat{}); // TODO: why is the status ignored?

            FindFilesSheetFoundItem *const item = [[FindFilesSheetFoundItem alloc] initWithFoundItem:std::move(it)];
            m_BatchQueue.Run([self, item] {
                // dumping result entry into batch array in BatchQueue
                [m_FoundItemsBatch addObject:item];
            });
        };

        if( _in_host.IsNativeFS() )
            m_StatGroup.Run(std::move(stat_block));
        else
            m_StatQueue.Run(std::move(stat_block));

        if( m_FoundItems.count + m_FoundItemsBatch.count >= g_MaximumSearchResults )
            m_FileSearch->Stop(); // gorshochek, ne vari!!!
    };
    auto finish_callback = [=] { [self onSearchFinished]; };
    auto lookin_in_callback = [=](const char *_path, VFSHost &_in_host) {
        auto verbose_path = _in_host.MakePathVerbose(_path);
        auto lock = std::lock_guard{m_LookingInPathGuard};
        m_LookingInPath = std::move(verbose_path);
    };
    auto spawn_archive_callback = [=](const char *_for_path, VFSHost &_in_host) -> VFSHostPtr {
        return [self spawnArchiveFromPath:_for_path inVFS:_in_host.SharedPtr()];
    };
    const bool started = m_FileSearch->Go(m_Path,
                                          m_Host,
                                          self.searchOptionsFromUI,
                                          std::move(found_callback),
                                          std::move(finish_callback),
                                          std::move(lookin_in_callback),
                                          std::move(spawn_archive_callback));
    self.searchingNow = started;
    if( started ) {
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

- (VFSHostPtr)spawnArchiveFromPath:(const char *)_path inVFS:(const VFSHostPtr &)_host
{
    const std::string_view extension = nc::utility::PathManip::Extension(_path);
    if( extension.empty() )
        return nullptr;

    if( !nc::panel::IsExtensionInArchivesWhitelist(extension) )
        return nullptr;

    auto host = VFSArchiveProxy::OpenFileAsArchive(_path, _host, nullptr, [&] { return m_FileSearch->IsStopped(); });
    if( host )
        if( self.vfsInstanceManager )
            self.vfsInstanceManager->TameVFS(host);

    return host;
}

- (void)updateLookingInByTimer:(NSTimer *) [[maybe_unused]] theTimer
{
    NSString *new_title;
    {
        auto lock = std::lock_guard{m_LookingInPathGuard};
        new_title = [NSString stringWithUTF8StdString:m_LookingInPath];
    }
    self.LookingIn.stringValue = new_title;
}

- (void)UpdateByTimer:(NSTimer *) [[maybe_unused]] theTimer
{
    m_BatchQueue.Run([=] {
        if( m_FoundItemsBatch.count == 0 )
            return; // nothing to add

        NSArray *const temp = m_FoundItemsBatch;
        m_FoundItemsBatch = [[NSMutableArray alloc] initWithCapacity:4096];

        dispatch_to_main_queue([=] {
            NSMutableArray *const new_objects = [m_FoundItems mutableCopy];
            [new_objects addObjectsFromArray:temp];
            self.FoundItems = new_objects;
        });
    });
}

- (const FindFilesSheetControllerFoundItem *)selectedItem
{
    if( m_DoubleClickedItem == nil )
        return nullptr;
    return &m_DoubleClickedItem.data;
}

- (IBAction)doubleClick:(id) [[maybe_unused]] table
{
    NSInteger row = [self.TableView clickedRow];
    if( row < 0 || row >= self.TableView.numberOfRows )
        return;
    FindFilesSheetFoundItem *item = [self.ArrayController.arrangedObjects objectAtIndex:row];
    m_DoubleClickedItem = item;
    [self OnClose:self];
}

- (void)tableViewSelectionDidChange:(NSNotification *) [[maybe_unused]] aNotification
{
    NSInteger row = [self.TableView selectedRow];
    if( row >= 0 ) {
        id selected_object = [self.ArrayController.arrangedObjects objectAtIndex:row];
        self.focusedItem = nc::objc_cast<FindFilesSheetFoundItem>(selected_object);
    }
    else {
        self.focusedItem = nil;
    }

    if( self.focusedItem ) {
        self.focusedItemIsReg = (self.focusedItem.data.st.mode & S_IFMT) == S_IFREG;
    }
    else {
        self.focusedItemIsReg = false;
    }
}

- (IBAction)OnGoToFile:(id) [[maybe_unused]] sender
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

- (IBAction)OnFileView:(id) [[maybe_unused]] sender
{
    dispatch_assert_main_queue();
    if( m_OnView == nullptr )
        return;

    const auto row_index = self.TableView.selectedRow;
    if( row_index < 0 )
        return;

    const auto found_item =
        nc::objc_cast<FindFilesSheetFoundItem>([self.ArrayController.arrangedObjects objectAtIndex:row_index]);

    const FindFilesSheetControllerFoundItem &data = found_item.data;

    auto request = FindFilesSheetViewRequest{};
    request.vfs = data.host;
    request.path = data.full_filename;
    request.sender = self;
    if( data.content_pos.location >= 0 ) {
        request.content_mark.emplace();
        request.content_mark->bytes_offset = data.content_pos.location;
        request.content_mark->bytes_length = data.content_pos.length;
        request.content_mark->search_term = self.textSearchField.stringValue.UTF8String;
    }
    m_OnView(request);
}

// Workaround about combox' menu forcing Search by selecting item from list with Return key
- (void)comboBoxWillPopUp:(NSNotification *) [[maybe_unused]] notification
{
    [self clearReturnKey];
}

- (void)comboBoxWillDismiss:(NSNotification *) [[maybe_unused]] notification
{
    using namespace std::literals;
    dispatch_to_main_queue_after(10ms, [=] { [self setupReturnKey]; });
}

- (void)controlTextDidChange:(NSNotification *)_notification
{
    if( nc::objc_cast<NSTextField>(_notification.object) == self.textSearchField ) {
        // For some reason when:
        // 1) the Enabled property of this text field is bound; AND
        // 2) the listener of this notification does not query the string value. THEN
        // => the value of `self.textSearchField.stringValue` is not updated upon a mouse click on the Search button
        // and later, once the text field is disabled, the field editor discards the input completely.
        // To work around this bug, let's query the value just for the sake of it.
        // This situation doesn't make much sense and a proper fix with a better understanding is required.
        // See the GitHub issue #482 for details.
        (void)self.textSearchField.stringValue;
    }

    [self onSearchSettingsUIChanged:_notification.object];
}

- (IBAction)onSearchSettingsUIChanged:(id) [[maybe_unused]] sender
{
    m_UIChanged = true;

    // validate the mask string
    const auto filename_mask = [self filenameEffectiveMask];
    const auto filename_mask_type = [self filenameMaskType];
    self.filenameMaskIsOk = nc::utility::FileMask::Validate(filename_mask, filename_mask_type);

    [self setupReturnKey];
}

- (nc::utility::FileMask::Type)filenameMaskType
{
    return m_RegexSearch ? nc::utility::FileMask::Type::RegEx : nc::utility::FileMask::Type::Mask;
}

- (std::string)filenameEffectiveMask
{
    //    const auto search_fied_value = self.maskSearchFieldValue;

    const auto search_fied_value = self.maskSearchField.stringValue;

    auto query = search_fied_value != nil ? std::string(search_fied_value.UTF8String) : std::string{};
    if( query.empty() )
        return {};
    if( m_RegexSearch ) {
        return query;
    }
    else {
        // expand simple requests, like "system", into "*system*"
        return nc::utility::FileMask::IsWildCard(query) ? query : nc::utility::FileMask::ToFilenameWildCard(query);
    }
}

- (IBAction)OnPanelize:(id) [[maybe_unused]] sender
{
    if( m_OnPanelize ) {
        std::vector<nc::vfs::VFSPath> results;
        for( FindFilesSheetFoundItem *item in self.ArrayController.arrangedObjects ) {
            auto &data = item.data;
            results.emplace_back(data.host, data.full_filename);
        }

        if( !results.empty() )
            m_OnPanelize(results);
    }

    [self OnClose:self];
}

- (void)setupReturnKey
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

- (void)clearReturnKey
{
    dispatch_assert_main_queue();
    self.SearchButton.keyEquivalent = @"";
    self.GoToButton.keyEquivalent = @"";
}

- (BOOL)tableView:(NSTableView *) [[maybe_unused]] tableView
    shouldTypeSelectForEvent:(NSEvent *)event
     withCurrentSearchString:(NSString *) [[maybe_unused]] searchString
{
    if( event.charactersIgnoringModifiers.length == 1 &&
        [event.charactersIgnoringModifiers characterAtIndex:0] == 0x20 ) {
        // treat Spacebar as View button
        dispatch_to_main_queue([=] { [self OnFileView:self]; });
        return false;
    }
    return true;
}

- (void)updateMasksMenu
{
    self.maskSearchField.searchMenuTemplate = [self buildMasksMenu];
}

- (void)updateTextMenu
{
    self.textSearchField.searchMenuTemplate = [self buildTextMenu];
}

- (NSMenu *)buildMasksMenu
{
    const auto menu = [[NSMenu alloc] initWithTitle:@""];

    [menu addItemWithTitle:NSLocalizedString(@"Options", "") action:nil keyEquivalent:@""];

    const auto regex = [menu addItemWithTitle:NSLocalizedString(@"Regular Expression", "")
                                       action:@selector(onMaskMenuRegExOptionClicked:)
                                keyEquivalent:@""];
    regex.state = m_RegexSearch ? NSControlStateValueOn : NSControlStateValueOff;
    regex.indentationLevel = 1;

    if( !m_MaskHistory.empty() ) {
        [menu addItem:NSMenuItem.separatorItem];
        [menu addItemWithTitle:NSLocalizedString(@"Recent Searches", "") action:nil keyEquivalent:@""];
        long query_index = 0;
        for( const auto &query : m_MaskHistory ) {
            NSString *title = @"";
            if( query.type == FindFilesMask::Classic ) {
                title = [NSString
                    stringWithFormat:NSLocalizedString(@"Mask \u201c%@\u201d", "Find file masks history - plain mask"),
                                     [NSString stringWithUTF8StdString:query.string]];
            }
            else if( query.type == FindFilesMask::RegEx ) {
                title = [NSString
                    stringWithFormat:NSLocalizedString(@"RegEx \u201c%@\u201d", "Find file masks history - regex"),
                                     [NSString stringWithUTF8StdString:query.string]];
            }
            auto item = [menu addItemWithTitle:title
                                        action:@selector(onMaskMenuHistoryEntryClicked:)
                                 keyEquivalent:@""];
            item.indentationLevel = 1;
            item.tag = query_index;
            ++query_index;
        }
        [menu addItem:NSMenuItem.separatorItem];
        [menu addItemWithTitle:NSLocalizedString(@"Clear Recents", "")
                        action:@selector(onMaskMenuClearRecentsClicked:)
                 keyEquivalent:@""];
    }

    return menu;
}

- (NSMenu *)buildTextMenu
{
    const auto menu = [[NSMenu alloc] initWithTitle:@""];

    [menu addItemWithTitle:NSLocalizedString(@"Options", "") action:nil keyEquivalent:@""];

    const auto case_sensitive = [menu addItemWithTitle:NSLocalizedString(@"Case Sensitive", "")
                                                action:@selector(onTextMenuCaseSensitiveClicked:)
                                         keyEquivalent:@""];
    case_sensitive.state = m_CaseSensitiveTextSearch ? NSControlStateValueOn : NSControlStateValueOff;
    case_sensitive.indentationLevel = 1;

    const auto whole_phrase = [menu addItemWithTitle:NSLocalizedString(@"Whole Phrase", "")
                                              action:@selector(onTextMenuWholePhraseClicked:)
                                       keyEquivalent:@""];
    whole_phrase.state = m_WholePhraseTextSearch ? NSControlStateValueOn : NSControlStateValueOff;
    whole_phrase.indentationLevel = 1;

    const auto not_containing = [menu addItemWithTitle:NSLocalizedString(@"Not Containing", "")
                                                action:@selector(onTextMenuNotContainingClicked:)
                                         keyEquivalent:@""];
    not_containing.state = m_NotContainingTextSearch ? NSControlStateValueOn : NSControlStateValueOff;
    not_containing.indentationLevel = 1;

    const auto encoding_menu = [[NSMenu alloc] initWithTitle:@""];
    for( const auto &i : nc::utility::LiteralEncodingsList() ) {
        auto item = [encoding_menu addItemWithTitle:(__bridge NSString *)i.second
                                             action:@selector(onTextMenuEncodingClicked:)
                                      keyEquivalent:@""];
        item.tag = std::to_underlying(i.first);
        if( i.first == m_TextSearchEncoding )
            item.state = NSControlStateValueOn;
    }
    const auto encoding_menu_item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Encoding", "")
                                                               action:nil
                                                        keyEquivalent:@""];
    encoding_menu_item.submenu = encoding_menu;
    encoding_menu_item.indentationLevel = 1;
    [menu addItem:encoding_menu_item];

    if( !m_TextHistory->empty() ) {
        [menu addItem:NSMenuItem.separatorItem];
        [menu addItemWithTitle:NSLocalizedString(@"Recent Searches", "") action:nil keyEquivalent:@""];
        long text_index = 0;
        for( const auto &text : *m_TextHistory ) {
            auto item = [menu addItemWithTitle:[NSString stringWithUTF8StdString:text]
                                        action:@selector(onTextMenuHistoryEntryClicked:)
                                 keyEquivalent:@""];
            item.indentationLevel = 1;
            item.tag = text_index;
            ++text_index;
        }
        [menu addItem:NSMenuItem.separatorItem];
        [menu addItemWithTitle:NSLocalizedString(@"Clear Recents", "")
                        action:@selector(onTextMenuClearRecentsClicked:)
                 keyEquivalent:@""];
    }
    return menu;
}

- (void)onTextMenuEncodingClicked:(id)_sender
{
    if( auto item = nc::objc_cast<NSMenuItem>(_sender) ) {
        m_TextSearchEncoding = static_cast<nc::utility::Encoding>(item.tag);
        [self updateTextMenu];
        [self onSearchSettingsUIChanged:_sender];
    }
}

- (void)onTextMenuHistoryEntryClicked:(id) [[maybe_unused]] _sender
{
    const auto item = nc::objc_cast<NSMenuItem>(_sender);
    if( !item )
        return;
    const auto tag = item.tag;
    if( tag < 0 || static_cast<size_t>(tag) >= m_TextHistory->size() )
        return;
    const auto history_entry = m_TextHistory->at(tag);
    [self.textSearchField setStringValue:[NSString stringWithUTF8StdString:history_entry]];
    [self onSearchSettingsUIChanged:_sender];
}

- (void)onTextMenuClearRecentsClicked:(id) [[maybe_unused]] _sender
{
    m_TextHistory->clear();
    [self updateTextMenu];
}

- (void)onTextMenuCaseSensitiveClicked:(id)_sender
{
    m_CaseSensitiveTextSearch = !m_CaseSensitiveTextSearch;
    [self updateTextMenu];
    [self onSearchSettingsUIChanged:_sender];
}

- (void)onTextMenuWholePhraseClicked:(id) [[maybe_unused]] _sender
{
    m_WholePhraseTextSearch = !m_WholePhraseTextSearch;
    [self updateTextMenu];
    [self onSearchSettingsUIChanged:_sender];
}

- (void)onTextMenuNotContainingClicked:(id) [[maybe_unused]] _sender
{
    m_NotContainingTextSearch = !m_NotContainingTextSearch;
    [self updateTextMenu];
    [self onSearchSettingsUIChanged:_sender];
}

- (void)onMaskMenuHistoryEntryClicked:(id)_sender
{
    const auto item = nc::objc_cast<NSMenuItem>(_sender);
    if( !item )
        return;
    const auto tag = item.tag;
    if( tag < 0 || static_cast<size_t>(tag) >= m_MaskHistory.size() )
        return;
    const auto history_entry = m_MaskHistory[tag];
    m_RegexSearch = history_entry.type == nc::panel::FindFilesMask::RegEx;
    [self.maskSearchField setStringValue:[NSString stringWithUTF8StdString:history_entry.string]];

    [self updateMasksMenu];
    [self onSearchSettingsUIChanged:_sender];
}

- (void)onMaskMenuRegExOptionClicked:(id)_sender
{
    m_RegexSearch = !m_RegexSearch;
    [self updateMasksMenu];
    [self updateMaskSearchFieldPrompt];
    [self onSearchSettingsUIChanged:_sender];
}

- (void)updateMaskSearchFieldPrompt
{
    NSString *tt = @"";
    NSString *ps = @"";
    if( m_RegexSearch ) {
        tt = NSLocalizedString(@"Specify a regular expression to match filenames with. (^M)",
                               "Tooltip for a regex filename match");
        ps = NSLocalizedString(@"Regular expression", "Placeholder prompt for a regex");
    }
    else {
        tt = NSLocalizedString(@"Use \"*\" for multiple-character wildcard, \"?\" for single-character wildcard and "
                               @"\",\" to specify more than one mask. (^M)",
                               "Tooltip for mask filename match");
        ps = NSLocalizedString(@"Mask: *, or *.t?t, or *.txt,*.jpg", "Placeholder prompt for a filemask");
    }
    self.maskSearchField.toolTip = tt;
    self.maskSearchField.placeholderString = ps;
}

- (void)onMaskMenuClearRecentsClicked:(id) [[maybe_unused]] sender
{
    m_MaskHistory.clear();
    [self updateMasksMenu];
}

- (void)insertFindFilesMaskIntoHistory:(const FindFilesMask &)_mask
{
    // update the search history - remove the entry if it was already there
    if( auto it = std::ranges::find(m_MaskHistory, _mask); it != m_MaskHistory.end() )
        m_MaskHistory.erase(it);

    // ... and place it to the front
    m_MaskHistory.insert(m_MaskHistory.begin(), _mask);

    // cap the history size if it grew too long
    if( m_MaskHistory.size() > g_MaximumMaskHistoryElements )
        m_MaskHistory.resize(g_MaximumMaskHistoryElements);

    // re-rebuild the pop-up menu template
    [self updateMasksMenu];
}

- (BOOL)control:(NSControl *)_control textView:(NSTextView *) [[maybe_unused]] _text_view doCommandBySelector:(SEL)_sel
{
    const auto menu_offset = 6.;
    if( _control == self.maskSearchField && _sel == @selector(moveDown:) ) {
        // show the mask field's combo box when the Down key is pressed
        const auto menu = self.maskSearchField.searchMenuTemplate;
        const auto bounds = self.maskSearchField.bounds;
        [menu popUpMenuPositioningItem:nil
                            atLocation:NSMakePoint(NSMinX(bounds), NSMaxY(bounds) + menu_offset)
                                inView:self.maskSearchField];
        return true;
    }
    if( _control == self.textSearchField && _sel == @selector(moveDown:) ) {
        // show the test field's combo box when the Down key is pressed
        const auto menu = self.textSearchField.searchMenuTemplate;
        const auto bounds = self.textSearchField.bounds;
        [menu popUpMenuPositioningItem:nil
                            atLocation:NSMakePoint(NSMinX(bounds), NSMaxY(bounds) + menu_offset)
                                inView:self.textSearchField];
        return true;
    }
    if( _sel == @selector(cancelOperation:) &&
        (_control == self.maskSearchField || _control == self.textSearchField) ) {
        // Don't allow the search field to swallow the Esc button, instead route it to the Close button
        [self OnClose:self];
        return true;
    }
    return false;
}

@end
