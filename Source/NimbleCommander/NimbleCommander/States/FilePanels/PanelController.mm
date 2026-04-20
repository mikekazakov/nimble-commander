// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelController.h"
#include <Base/algo.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/NSMenu+Hierarchical.h>
#include "../MainWindowController.h"
#include "PanelPreview.h"
#include "MainWindowFilePanelState.h"
#include "Views/BriefSystemOverview.h"
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include "PanelViewLayoutSupport.h"
#include <Panel/PanelDataItemVolatileData.h>
#include "PanelDataOptionsPersistence.h"
#include <Base/CommonPaths.h>
#include <VFS/Native.h>
#include "PanelHistory.h"
#include <Base/SerialQueue.h>
#include <Panel/PanelData.h>
#include "PanelView.h"
#include "DragReceiver.h"
#include "ContextMenu.h"
#include <Panel/PanelDataExternalEntryKey.h>
#include "PanelDataPersistency.h"
#include <NimbleCommander/Core/VFSInstanceManager.h>
#include "Actions/OpenFile.h"
#include "Actions/GoToFolder.h"
#include "Actions/Enter.h"
#include <Operations/Copying.h>
#include <Panel/CursorBackup.h>
#include <Panel/QuickSearch.h>
#include <Panel/Log.h>
#include "PanelViewHeader.h"
#include <Config/RapidJSON.h>
#include <Utility/ObjCpp.h>
#include <Utility/StringExtras.h>
#include <Utility/PathManip.h>
#include <Base/mach_time.h>

#include <algorithm>

using namespace nc;
using namespace nc::core;
using namespace nc::panel;
using namespace std::literals;

static constexpr size_t g_MaxSizeCalculationCommitBatches = 40;
static constexpr std::chrono::nanoseconds g_FilesystemHintTriggerDelay = std::chrono::milliseconds{500}; // 0.5s

static const auto g_ConfigShowDotDotEntry = "filePanel.general.showDotDotEntry";
static const auto g_ConfigIgnoreDirectoriesOnMaskSelection = "filePanel.general.ignoreDirectoriesOnSelectionWithMask";
static const auto g_ConfigShowLocalizedFilenames = "filePanel.general.showLocalizedFilenames";
static const auto g_ConfigEnableFinderTags = "filePanel.FinderTags.enable";

namespace nc::panel {

ActivityTicket::ActivityTicket() : ticket(0), panel(nil)
{
}

ActivityTicket::ActivityTicket(PanelController *_panel, uint64_t _ticket) : ticket(_ticket), panel(_panel)
{
}

ActivityTicket::ActivityTicket(ActivityTicket &&_rhs) noexcept : ticket(_rhs.ticket), panel(_rhs.panel)
{
    _rhs.panel = nil;
    _rhs.ticket = 0;
}

ActivityTicket::~ActivityTicket()
{
    Reset();
}

ActivityTicket &ActivityTicket::operator=(ActivityTicket &&_rhs) noexcept
{
    Reset();
    panel = _rhs.panel;
    ticket = _rhs.ticket;
    _rhs.panel = nil;
    _rhs.ticket = 0;
    return *this;
}

void ActivityTicket::Reset()
{
    if( ticket )
        if( PanelController *const pc = panel )
            [pc finishExtActivityWithTicket:ticket];
    panel = nil;
    ticket = 0;
}

struct CalculatedSizesBatch {
    std::vector<VFSListingItem> items;
    std::vector<uint64_t> sizes;
};

} // namespace nc::panel

#define MAKE_AUTO_UPDATING_BOOL_CONFIG_VALUE(_name, _path)                                                             \
    static bool _name()                                                                                                \
    {                                                                                                                  \
        static const auto fetch = [] { return GlobalConfig().GetBool((_path)); };                                      \
        static bool value = [] {                                                                                       \
            GlobalConfig().ObserveForever((_path), [] { value = fetch(); });                                           \
            return fetch();                                                                                            \
        }();                                                                                                           \
        return value;                                                                                                  \
    }

MAKE_AUTO_UPDATING_BOOL_CONFIG_VALUE(ConfigShowDotDotEntry, g_ConfigShowDotDotEntry);
MAKE_AUTO_UPDATING_BOOL_CONFIG_VALUE(ConfigShowLocalizedFilenames, g_ConfigShowLocalizedFilenames);
MAKE_AUTO_UPDATING_BOOL_CONFIG_VALUE(ConfigEnableFinderTags, g_ConfigEnableFinderTags);

static void HeatUpConfigValues()
{
    ConfigShowDotDotEntry();
    ConfigShowLocalizedFilenames();
    ConfigEnableFinderTags();
}

@interface PanelController ()

@property(nonatomic, readonly)
    bool receivesUpdateNotifications; // returns true if underlying vfs will notify controller that content has changed
@end

@implementation PanelController {
    // Main controller's possessions
    data::Model m_Data; // owns
    PanelView *m_View;  // create and owns

    // VFS changes observation
    vfs::HostDirObservationTicket m_UpdatesObservationTicket;

    // VFS listing fetch flags
    unsigned long m_VFSFetchingFlags;

    // background operations' queues
    nc::base::SerialQueue m_DirectorySizeCountingQ;
    nc::base::SerialQueue m_DirectoryLoadingQ;
    nc::base::SerialQueue m_DirectoryReLoadingQ;

    NCPanelQuickSearch *m_QuickSearch;

    // navigation support
    History m_History;

    // spinning indicator support
    bool m_IsAnythingWorksInBackground;

    // Tickets to show some external activities on this panel
    uint64_t m_NextActivityTicket;
    std::vector<uint64_t> m_ActivitiesTickets;
    spinlock m_ActivitiesTicketsLock;

    // delayed entry selection support
    struct {
        /**
         * Requested item name to select. Empty filename means that request is invalid.
         */
        std::string filename;

        /**
         * Time after which request is meaningless and should be removed
         */
        std::chrono::nanoseconds request_end;

        /**
         * Called when changed a cursor position
         */
        std::function<void()> done;
    } m_DelayedSelection;

    __weak MainWindowFilePanelState *m_FilePanelState;

    boost::container::static_vector<nc::config::Token, 3> m_ConfigObservers;
    nc::core::VFSInstanceManager *m_VFSInstanceManager;
    nc::panel::DirectoryAccessProvider *m_DirectoryAccessProvider;
    std::shared_ptr<PanelViewLayoutsStorage> m_Layouts;
    int m_ViewLayoutIndex;
    std::shared_ptr<const PanelViewLayout> m_AssignedViewLayout;
    PanelViewLayoutsStorage::ObservationTicket m_LayoutsObservation;
    ContextMenuProvider m_ContextMenuProvider;
    nc::utility::NativeFSManager *m_NativeFSManager;
    nc::vfs::NativeHost *m_NativeHost;

    unsigned long m_DataGeneration;
}

@synthesize view = m_View;
@synthesize data = m_Data;
@synthesize history = m_History;
@synthesize layoutIndex = m_ViewLayoutIndex;
@synthesize vfsFetchingFlags = m_VFSFetchingFlags;
@synthesize dataGeneration = m_DataGeneration;

- (instancetype)initWithView:(PanelView *)_panel_view
                     layouts:(std::shared_ptr<nc::panel::PanelViewLayoutsStorage>)_layouts
          vfsInstanceManager:(nc::core::VFSInstanceManager &)_vfs_mgr
     directoryAccessProvider:(nc::panel::DirectoryAccessProvider &)_directory_access_provider
         contextMenuProvider:(nc::panel::ContextMenuProvider)_context_menu_provider
             nativeFSManager:(nc::utility::NativeFSManager &)_native_fs_mgr
                  nativeHost:(nc::vfs::NativeHost &)_native_host
{
    assert(_layouts);
    assert(_context_menu_provider);

    static std::once_flag once;
    std::call_once(once, HeatUpConfigValues);

    self = [super init];
    if( self ) {
        m_Layouts = std::move(_layouts);
        m_VFSInstanceManager = &_vfs_mgr;
        m_NativeFSManager = &_native_fs_mgr;
        m_NativeHost = &_native_host;
        m_DirectoryAccessProvider = &_directory_access_provider;
        m_ContextMenuProvider = std::move(_context_menu_provider);
        m_History.SetVFSInstanceManager(_vfs_mgr);
        m_VFSFetchingFlags = 0;
        m_NextActivityTicket = 1;
        m_DataGeneration = 0;
        m_IsAnythingWorksInBackground = false;
        m_ViewLayoutIndex = m_Layouts->DefaultLayoutIndex();
        m_AssignedViewLayout = m_Layouts->DefaultLayout();

        __weak PanelController *weakself = self;
        auto on_change = [=] {
            dispatch_to_main_queue([=] { [static_cast<PanelController *>(weakself) updateSpinningIndicator]; });
        };
        m_DirectorySizeCountingQ.SetOnChange(on_change);
        m_DirectoryReLoadingQ.SetOnChange(on_change);
        m_DirectoryLoadingQ.SetOnChange(on_change);

        m_View = _panel_view;
        m_View.delegate = self;
        m_View.data = &m_Data;
        [m_View setPresentationLayout:*m_AssignedViewLayout];

        // wire up config changing notifications
        auto add_co = [&](const char *_path, SEL _sel) {
            m_ConfigObservers.emplace_back(GlobalConfig().Observe(_path, objc_callback(self, _sel)));
        };
        add_co(g_ConfigShowDotDotEntry, @selector(configVFSFetchFlagsChanged));
        add_co(g_ConfigShowLocalizedFilenames, @selector(configVFSFetchFlagsChanged));
        add_co(g_ConfigEnableFinderTags, @selector(configVFSFetchFlagsChanged));

        m_LayoutsObservation = m_Layouts->ObserveChanges(objc_callback(self, @selector(panelLayoutsChanged)));

        // loading config via simulating it's change
        [self configVFSFetchFlagsChanged];

        m_QuickSearch = [[NCPanelQuickSearch alloc] initWithData:m_Data delegate:self config:GlobalConfig()];
        __weak NCPanelQuickSearch *weak_qs = m_QuickSearch;
        auto callback = [weak_qs](NSString *_request) {
            if( NCPanelQuickSearch *const strong_qs = weak_qs )
                strong_qs.searchCriteria = _request;
        };
        m_View.headerView.searchRequestChangeCallback = std::move(callback);

        [m_View addKeystrokeSink:self];
        [m_View addKeystrokeSink:m_QuickSearch];
    }

    return self;
}

- (void)dealloc
{
    // we need to manually set data to nullptr, since PanelView can be destroyed a bit later due
    // to other strong pointers. in that case view will contain a dangling pointer, which can lead
    // to a crash.
    m_View.data = nullptr;
}

- (void)configVFSFetchFlagsChanged
{
    if( !ConfigShowDotDotEntry() )
        m_VFSFetchingFlags |= VFSFlags::F_NoDotDot;
    else
        m_VFSFetchingFlags &= ~VFSFlags::F_NoDotDot;

    if( ConfigShowLocalizedFilenames() )
        m_VFSFetchingFlags |= VFSFlags::F_LoadDisplayNames;
    else
        m_VFSFetchingFlags &= ~VFSFlags::F_LoadDisplayNames;

    if( ConfigEnableFinderTags() )
        m_VFSFetchingFlags |= VFSFlags::F_LoadTags;
    else
        m_VFSFetchingFlags &= ~VFSFlags::F_LoadTags;

    [self refreshPanel];
}

- (void)setState:(MainWindowFilePanelState *)state
{
    m_FilePanelState = state;
}

- (MainWindowFilePanelState *)state
{
    return m_FilePanelState;
}

- (NSWindow *)window
{
    return self.state.window;
}

- (NCMainWindowController *)mainWindowController
{
    return static_cast<NCMainWindowController *>(self.window.delegate);
}

- (bool)isUniform
{
    return m_Data.Listing().IsUniform();
}

- (bool)receivesUpdateNotifications
{
    return static_cast<bool>(m_UpdatesObservationTicket);
}

- (bool)ignoreDirectoriesOnSelectionByMask
{
    return GlobalConfig().GetBool(g_ConfigIgnoreDirectoriesOnMaskSelection);
}

- (void)copyOptionsFromController:(PanelController *)_pc
{
    if( !_pc )
        return;

    data::OptionsImporter{m_Data}.Import(data::OptionsExporter{_pc.data}.Export());
    [self.view dataUpdated];
    [self.view dataSortingHasChanged];
    self.layoutIndex = _pc.layoutIndex;
}

- (bool)isActive
{
    return m_View.active;
}

- (void)changeSortingModeTo:(data::SortMode)_mode
{
    if( _mode != m_Data.SortMode() ) {
        const auto pers = CursorBackup{m_View.curpos, m_Data};

        m_Data.SetSortMode(_mode);

        m_View.curpos = pers.RestoredCursorPosition();

        [m_View dataSortingHasChanged];
        [m_View dataUpdated];
        [self markRestorableStateAsInvalid];
    }
}

- (void)changeHardFilteringTo:(data::HardFilter)_filter
{
    if( _filter != m_Data.HardFiltering() ) {
        const auto pers = CursorBackup{m_View.curpos, m_Data};

        m_Data.SetHardFiltering(_filter);

        m_View.curpos = pers.RestoredCursorPosition();
        [m_View dataUpdated];
        [self markRestorableStateAsInvalid];
    }
}

- (void)reloadRefreshedListing:(const VFSListingPtr &)_ptr
{
    assert(dispatch_is_main_queue());
    Log::Info("Reloading refreshed listing, {}", _ptr->IsUniform() ? _ptr->Directory().c_str() : "uniform");

    const auto pers = CursorBackup{m_View.curpos, m_Data};

    m_Data.ReLoad(_ptr);
    [m_View dataUpdated];
    [m_QuickSearch dataUpdated];

    if( [self checkAgainstRequestedFocusing] ) {
        Log::Trace("Cursor position was changed by requested focusing, skipping RestoredCursorPosition()");
    }
    else {
        m_View.curpos = pers.RestoredCursorPosition();
    }

    [self onCursorChanged];
    [m_View setNeedsDisplay];
}

- (void)refreshPanelDiscardingCaches:(bool)_force
{
    Log::Debug("refreshPanelDiscardingCaches:{} was called", _force);

    if( m_View == nil )
        return; // guard agains calls from init process
    if( &m_Data.Listing() == VFSListing::EmptyListing().get() )
        return; // guard agains calls from init process

    if( !m_DirectoryLoadingQ.Empty() ) {
        Log::Debug("Discarding the refresh request as there is a load request in place");
        return; // reducing overhead
    }

    if( m_DirectoryReLoadingQ.Length() >= 2 ) {
        Log::Debug("Discarding the refresh request as the current length of reload queue is {}",
                   m_DirectoryReLoadingQ.Length());
        return; // reducing overhead
    }

    // later: maybe check PanelType somehow

    if( self.isUniform ) {
        const auto fetch_flags = m_VFSFetchingFlags | (_force ? VFSFlags::F_ForceRefresh : 0);
        const auto dirpath = m_Data.DirectoryPathWithTrailingSlash();
        const auto vfs = self.vfs;

        m_DirectoryReLoadingQ.Run([=] {
            if( m_DirectoryReLoadingQ.IsStopped() ) {
                Log::Trace("[PanelController refreshPanelDiscardingCaches] cancelled the refresh");
                return;
            }
            const std::expected<VFSListingPtr, Error> listing =
                vfs->FetchDirectoryListing(dirpath, fetch_flags, [&] { return m_DirectoryReLoadingQ.IsStopped(); });
            if( m_DirectoryReLoadingQ.IsStopped() ) {
                Log::Trace("[PanelController refreshPanelDiscardingCaches] cancelled the refresh");
                return;
            }
            dispatch_to_main_queue([=] {
                if( self.currentDirectoryPath != dirpath ) {
                    Log::Debug(
                        "[PanelController refreshPanelDiscardingCaches]: discarding a stale request to refresh '{}'",
                        dirpath);
                    return;
                }

                if( listing )
                    [self reloadRefreshedListing:*listing];
                else
                    [self recoverFromInvalidDirectory];
            });
        });
    }
    else {
        m_DirectoryReLoadingQ.Run([=] {
            if( m_DirectoryReLoadingQ.IsStopped() )
                return;
            auto listing = VFSListing::ProduceUpdatedTemporaryPanelListing(
                m_Data.Listing(), [&] { return m_DirectoryReLoadingQ.IsStopped(); });
            if( listing )
                dispatch_to_main_queue([=] { [self reloadRefreshedListing:listing]; });
        });
    }
}

- (void)refreshPanel
{
    Log::Trace("[Panel refreshPanel] was called");
    [self refreshPanelDiscardingCaches:false];
}

- (void)forceRefreshPanel
{
    Log::Trace("[Panel forceRefreshPanel] was called");
    [self refreshPanelDiscardingCaches:true];
}

- (int)bidForHandlingKeyDown:(NSEvent *)_event forPanelView:(PanelView *) [[maybe_unused]] _panel_view
{
    // this is doubtful, actually. need to figure out something clearer:
    [self clearFocusingRequest]; // on any key press we clear entry selection request, if any

    const auto keycode = _event.keyCode;
    if( keycode == 53 ) { // Esc button
        if( m_IsAnythingWorksInBackground )
            return panel::view::BiddingPriority::Default;
        if( self.quickLook || self.briefSystemOverview )
            return panel::view::BiddingPriority::Default;
        ;
    }

    return panel::view::BiddingPriority::Skip;
}

- (void)handleKeyDown:(NSEvent *)_event forPanelView:(PanelView *) [[maybe_unused]] _panel_view
{
    const auto keycode = _event.keyCode;
    if( keycode == 53 ) { // Esc button
        if( m_IsAnythingWorksInBackground ) {
            [self CancelBackgroundOperations];
            return;
        }
        if( self.quickLook || self.briefSystemOverview ) {
            [self.state closeAttachedUI:self];
            return;
        }
    }
}

- (void)calculateSizesOfItems:(const std::vector<VFSListingItem> &)_items
{
    if( !_items.empty() ) {
        m_DirectorySizeCountingQ.Run([=] { [self doCalculateSizesOfItems:_items]; });
    }
}

- (void)doCalculateSizesOfItems:(const std::vector<VFSListingItem> &)_items
{
    dispatch_assert_background_queue();
    assert(!_items.empty());

    // divide all items into maximum of g_MaxSizeCalculationCommitBatches batches as equally as
    // possible
    const size_t items_count = _items.size();
    const size_t batches = std::min(g_MaxSizeCalculationCommitBatches, items_count);
    const size_t items_per_batch = items_count / batches;
    const size_t items_leftover = items_count - (items_per_batch * batches);

    for( size_t batch = 0, items_first = 0, items_last = 0; batch != batches; ++batch ) {
        items_first = items_last;
        items_last += items_per_batch + (batch < items_leftover ? 1 : 0);

        panel::CalculatedSizesBatch calculated;
        calculated.items.reserve(items_last - items_first);
        calculated.sizes.reserve(items_last - items_first);

        for( size_t item_index = items_first; item_index != items_last; ++item_index ) {
            if( m_DirectorySizeCountingQ.IsStopped() )
                return;

            auto &i = _items[item_index];
            if( !i.IsDir() )
                continue;

            const std::expected<uint64_t, Error> result = i.Host()->CalculateDirectorySize(
                !i.IsDotDot() ? i.Path() : i.Directory(), [=] { return m_DirectorySizeCountingQ.IsStopped(); });

            if( !result )
                continue; // silently skip items that caused erros while calculating size

            calculated.items.emplace_back(i);
            calculated.sizes.emplace_back(*result);
        }

        if( calculated.items.empty() )
            continue;

        auto commit_batch = [=, calculated = std::move(calculated)] {
            assert(!calculated.items.empty());

            // may cause re-sorting if current sorting is by size so save the cursor
            const auto pers = CursorBackup{m_View.curpos, m_Data};

            size_t num_set = 0;
            if( &m_Data.Listing() == calculated.items.front().Listing().get() ) {
                // the listing is the same, can use indices directly
                std::vector<unsigned> raw_indices(calculated.items.size());
                std::ranges::transform(calculated.items, raw_indices.begin(), [](auto &i) { return i.Index(); });
                num_set = m_Data.SetCalculatedSizesForDirectories(raw_indices, calculated.sizes);
            }
            else {
                // the listing has changed, need to use indirects: filename and directory
                std::vector<std::string_view> filenames(calculated.items.size());
                std::vector<std::string_view> directories(calculated.items.size());
                std::ranges::transform(
                    calculated.items, filenames.begin(), [](auto &i) { return std::string_view{i.Filename()}; });
                std::ranges::transform(
                    calculated.items, directories.begin(), [](auto &i) { return std::string_view{i.Directory()}; });
                num_set = m_Data.SetCalculatedSizesForDirectories(filenames, directories, calculated.sizes);
            }
            if( num_set != 0 ) {
                [m_View dataUpdated];
                [m_View volatileDataChanged];
                m_View.curpos = pers.RestoredCursorPosition();
            }
        };
        dispatch_to_main_queue(std::move(commit_batch));
    }
}

- (void)CancelBackgroundOperations
{
    m_DirectorySizeCountingQ.Stop();
    m_DirectoryLoadingQ.Stop();
    m_DirectoryReLoadingQ.Stop();
}

- (void)updateSpinningIndicator
{
    dispatch_assert_main_queue();

    size_t ext_activities_no = call_locked(m_ActivitiesTicketsLock, [&] { return m_ActivitiesTickets.size(); });
    bool is_anything_working = !m_DirectorySizeCountingQ.Empty() || !m_DirectoryLoadingQ.Empty() ||
                               !m_DirectoryReLoadingQ.Empty() || ext_activities_no > 0;

    if( is_anything_working == m_IsAnythingWorksInBackground )
        return; // nothing to update;

    if( is_anything_working ) {
        // there should be 100ms of workload before the user gets the spinning indicator
        dispatch_to_main_queue_after(100ms, [=] {
            // need to check if task was already done
            if( m_IsAnythingWorksInBackground )
                [m_View.busyIndicator startAnimation:nil];
        });
    }
    else
        [m_View.busyIndicator stopAnimation:nil];

    m_IsAnythingWorksInBackground = is_anything_working;
}

- (void)selectEntriesWithFilenames:(const std::vector<std::string> &)_filenames
{
    for( auto &i : _filenames )
        m_Data.CustomFlagsSelectSorted(m_Data.SortedIndexForName(i), true);
    [m_View volatileDataChanged];
}

- (void)setEntriesSelection:(const std::vector<bool> &)_selection
{
    if( m_Data.CustomFlagsSelectSorted(_selection) )
        [m_View volatileDataChanged];
}

- (void)setSelectionForItemAtIndex:(int)_index selected:(bool)_selected
{
    if( m_Data.VolatileDataAtSortPosition(_index).is_selected() == _selected )
        return;
    m_Data.CustomFlagsSelectSorted(_index, _selected);
    [m_View volatileDataChanged];
}

- (void)onPathChanged
{
    Log::Trace("[PanelController onPathChanged] was called");
    // update directory changes notification ticket
    __weak PanelController *weakself = self;
    m_UpdatesObservationTicket.reset();
    if( self.isUniform ) {
        const std::string current_directory_path = self.currentDirectoryPath;
        auto dir_change_callback = [=] {
            dispatch_to_main_queue([=] {
                Log::Debug("Got a notification about a directory change: '{}'", current_directory_path);
                if( PanelController *const pc = weakself ) {
                    if( pc.currentDirectoryPath == current_directory_path ) {
                        [pc refreshPanel];
                    }
                    else {
                        Log::Debug("Discarded a stale directory change notification");
                    }
                }
            });
        };
        m_UpdatesObservationTicket =
            self.vfs->ObserveDirectoryChanges(current_directory_path, std::move(dir_change_callback));
    }

    [self clearFocusingRequest];
    [m_QuickSearch setSearchCriteria:nil];

    [self.state PanelPathChanged:self];
    [self onCursorChanged];
    [self updateAttachedBriefSystemOverview];
    m_History.Put(m_Data.Listing());

    [self markRestorableStateAsInvalid];
}

- (void)markRestorableStateAsInvalid
{
    if( auto wc = objc_cast<NCMainWindowController>(self.state.window.delegate) )
        [wc invalidateRestorableState];
}

- (void)onCursorChanged
{
    [self updateAttachedQuickLook];
}

- (void)updateAttachedQuickLook
{
    if( auto ql = self.quickLook )
        if( auto i = self.view.item )
            [ql previewVFSItem:vfs::VFSPath{i.Host(), i.Path()} forPanel:self];
}

- (void)updateAttachedBriefSystemOverview
{
    if( const auto bso = self.briefSystemOverview ) {
        if( auto i = self.view.item )
            [bso UpdateVFSTarget:i.Directory() host:i.Host()];
        else if( self.isUniform )
            [bso UpdateVFSTarget:self.currentDirectoryPath host:self.vfs];
    }
}

- (void)panelViewCursorChanged:(PanelView *) [[maybe_unused]] _view
{
    [self onCursorChanged];
}

- (NCPanelContextMenu *)panelView:(PanelView *)_view requestsContextMenuForItemNo:(int)_sort_pos
{
    dispatch_assert_main_queue();

    const auto clicked_item = m_Data.EntryAtSortPosition(_sort_pos);
    if( !clicked_item || clicked_item.IsDotDot() )
        return nil;

    const auto clicked_item_vd = m_Data.VolatileDataAtSortPosition(_sort_pos);

    std::vector<VFSListingItem> vfs_items;
    if( !clicked_item_vd.is_selected() )
        vfs_items.emplace_back(clicked_item); // only clicked item
    else
        vfs_items = m_Data.SelectedEntriesSorted(); // all selected items

    for( auto &i : vfs_items )
        m_Data.VolatileDataAtRawPosition(i.Index()).toggle_highlight(true);
    [_view volatileDataChanged];

    NCPanelContextMenu *const menu = m_ContextMenuProvider(std::move(vfs_items), self);
    return menu;
}

- (void)contextMenuDidClose:(NSMenu *) [[maybe_unused]] _menu
{
    m_Data.CustomFlagsClearHighlights();
    [m_View volatileDataChanged];
}

static void ShowAlertAboutInvalidFilename(const std::string &_filename)
{
    Alert *const a = [[Alert alloc] init];
    auto fn = [NSString stringWithUTF8StdString:_filename];
    if( fn.length > 256 )
        fn = [[fn substringToIndex:256] stringByAppendingString:@"..."];

    const auto msg =
        NSLocalizedString(@"The name “%@” can’t be used.", "Message text when user is entering an invalid filename");
    a.messageText = [NSString stringWithFormat:msg, fn];
    const auto info = NSLocalizedString(@"Try using a name with fewer characters or without punctuation marks.",
                                        "Informative text when user is entering an invalid filename");
    a.informativeText = info;
    a.alertStyle = NSAlertStyleCritical;
    [a runModal];
}

- (void)requestQuickRenamingOfItem:(VFSListingItem)_item to:(const std::string &)_filename
{
    if( _filename == "." || _filename == ".." || !_item || _item.IsDotDot() || !_item.Host()->IsWritable() ||
        _filename == _item.Filename() )
        return;

    const auto &target_fn = _filename;

    // checking for invalid symbols
    if( !_item.Host()->ValidateFilename(target_fn) ) {
        ShowAlertAboutInvalidFilename(target_fn);
        return;
    }

    nc::ops::CopyingOptions opts;
    opts.docopy = false;

    const auto op = std::make_shared<nc::ops::Copying>(
        std::vector<VFSListingItem>{_item}, _item.Directory() + target_fn, _item.Host(), opts);

    if( self.isUniform && m_View.item && m_View.item.Filename() == _item.Filename() ) {
        std::string curr_path = self.currentDirectoryPath;
        auto curr_vfs = self.vfs;
        op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=] {
            if( self.currentDirectoryPath == curr_path && self.vfs == curr_vfs )
                dispatch_to_main_queue([=] {
                    DelayedFocusing req;
                    req.filename = target_fn;
                    [self scheduleDelayedFocusing:req];
                    [self refreshPanel];
                });
        });
    }

    [self.mainWindowController enqueueOperation:op];
}

- (void)panelViewDidBecomeFirstResponder
{
    [self.state activePanelChangedTo:self];
    [self updateAttachedQuickLook];
    [self updateAttachedBriefSystemOverview];
}

- (void)changeDataOptions:(const std::function<void(nc::panel::data::Model &_data)> &)_workload
{
    assert(dispatch_is_main_queue());
    assert(_workload);

    const auto pers = CursorBackup{m_View.curpos, m_Data};

    _workload(m_Data);

    [m_View dataUpdated];
    [m_View dataSortingHasChanged];
    m_View.curpos = pers.RestoredCursorPosition();
}

- (ActivityTicket)registerExtActivity
{
    auto ticket = call_locked(m_ActivitiesTicketsLock, [&] {
        m_ActivitiesTickets.emplace_back(m_NextActivityTicket);
        return ActivityTicket(self, m_NextActivityTicket++);
    });
    dispatch_to_main_queue([=] { [self updateSpinningIndicator]; });
    return ticket;
}

- (void)finishExtActivityWithTicket:(uint64_t)_ticket
{
    {
        auto lock = std::lock_guard{m_ActivitiesTicketsLock};
        auto i = std::ranges::find(m_ActivitiesTickets, _ticket);
        if( i == end(m_ActivitiesTickets) )
            return;
        m_ActivitiesTickets.erase(i);
    }
    dispatch_to_main_queue([=] { [self updateSpinningIndicator]; });
}

- (void)setLayoutIndex:(int)layoutIndex
{
    if( m_ViewLayoutIndex != layoutIndex ) {
        if( auto l = m_Layouts->GetLayout(layoutIndex) )
            if( !l->is_disabled() ) {
                m_ViewLayoutIndex = layoutIndex;
                m_AssignedViewLayout = l;
                [m_View setPresentationLayout:*l];
                [self markRestorableStateAsInvalid];
            }
    }
}

- (void)panelLayoutsChanged
{
    if( auto l = m_Layouts->GetLayout(m_ViewLayoutIndex) ) {
        if( m_AssignedViewLayout && *m_AssignedViewLayout == *l )
            return;

        if( !l->is_disabled() ) {
            m_AssignedViewLayout = l;
            [m_View setPresentationLayout:*l];
        }
        else {
            m_AssignedViewLayout = nc::panel::PanelViewLayoutsStorage::LastResortLayout();
            [m_View setPresentationLayout:*m_AssignedViewLayout];
        }
    }
}

- (void)panelViewDidChangePresentationLayout
{
    PanelViewLayout layout;
    layout.name = m_AssignedViewLayout->name;
    layout.layout = [m_View presentationLayout];

    if( layout != *m_AssignedViewLayout )
        m_Layouts->ReplaceLayout(std::move(layout), m_ViewLayoutIndex);
}

- (void)commitCancelableLoadingTask:(std::function<void(const std::function<bool()> &_is_cancelled)>)_task
{
    m_DirectoryLoadingQ.Run(
        [task = std::move(_task), sq = &m_DirectoryLoadingQ] { task([sq] { return sq->IsStopped(); }); });
}

- (bool)probeDirectoryAccessForRequest:(DirectoryChangeRequest &)_request
{
    const auto &directory = _request.RequestedDirectory;
    auto &vfs = *_request.VFS;
    auto &access_provider = *m_DirectoryAccessProvider;
    const auto has_access = access_provider.HasAccess(self, directory, vfs);
    if( has_access ) {
        return true;
    }
    else {
        if( _request.InitiatedByUser )
            return access_provider.RequestAccessSync(self, directory, vfs);
        else
            return false;
    }
}

- (std::expected<void, Error>)doGoToDirWithContext:(std::shared_ptr<DirectoryChangeRequest>)_request
{
    assert(_request != nullptr);
    assert(_request->VFS != nullptr);
    Log::Debug("[PanelController doGoToDirWithContext] was called with {}", *_request);

    try {
        if( ![self probeDirectoryAccessForRequest:*_request] ) {
            return std::unexpected(Error{Error::POSIX, EPERM});
        }

        auto directory = _request->RequestedDirectory;
        auto &vfs = *_request->VFS;
        const auto canceller = VFSCancelChecker([&] { return m_DirectoryLoadingQ.IsStopped(); });
        const std::expected<VFSListingPtr, Error> listing =
            vfs.FetchDirectoryListing(directory, m_VFSFetchingFlags, canceller);
        if( _request->LoadingResultCallback ) {
            _request->LoadingResultCallback(listing ? std::expected<void, Error>{}
                                                    : std::expected<void, Error>{std::unexpected(listing.error())});
        }

        if( !listing )
            return std::unexpected(listing.error());

        // TODO: need an ability to show errors at least

        [self CancelBackgroundOperations]; // clean running operations if any
        dispatch_or_run_in_main_queue([=] {
            [m_View savePathState];
            m_Data.Load(*listing, data::Model::PanelType::Directory);
            for( auto &i : _request->RequestSelectedEntries )
                m_Data.CustomFlagsSelectSorted(m_Data.SortedIndexForName(i), true);
            m_DataGeneration++;
            [m_View dataUpdated];
            [m_View panelChangedWithFocusedFilename:_request->RequestFocusedEntry
                                  loadPreviousState:_request->LoadPreviousViewState];
            [self onPathChanged];
        });
    } catch( std::exception &e ) {
        ShowExceptionAlert(e);
    } catch( ... ) {
        ShowExceptionAlert();
    }
    return {};
}

- (std::expected<void, Error>)GoToDirWithContext:(std::shared_ptr<DirectoryChangeRequest>)_request
{
    if( _request == nullptr )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    if( _request->RequestedDirectory.empty() || _request->RequestedDirectory.front() != '/' ||
        _request->VFS == nullptr )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    assert(_request != nullptr);
    assert(_request->VFS != nullptr);
    Log::Debug("[PanelController GoToDirWithContext] was called with {}", *_request);

    if( !_request->PerformAsynchronous ) {
        assert(dispatch_is_main_queue());
        m_DirectoryLoadingQ.Stop();
        m_DirectoryLoadingQ.Wait();

        const std::expected<void, Error> result = [self doGoToDirWithContext:_request];
        return result;
    }
    else {
        if( !m_DirectoryLoadingQ.Empty() )
            return {};

        m_DirectoryLoadingQ.Run([=] { [self doGoToDirWithContext:_request]; });
        return {};
    }
}

- (void)loadListing:(const VFSListingPtr &)_listing
{
    [self CancelBackgroundOperations]; // clean running operations if any
    dispatch_or_run_in_main_queue([=] {
        [m_View savePathState];
        if( _listing->IsUniform() )
            m_Data.Load(_listing, data::Model::PanelType::Directory);
        else
            m_Data.Load(_listing, data::Model::PanelType::Temporary);
        m_DataGeneration++;
        [m_View dataUpdated];
        [m_View panelChangedWithFocusedFilename:"" loadPreviousState:false];
        [self onPathChanged];
    });
}

- (void)recoverFromInvalidDirectory
{
    std::filesystem::path initial_path = EnsureNoTrailingSlash(self.currentDirectoryPath);
    auto initial_vfs = self.vfs;
    m_DirectoryLoadingQ.Run([=] {
        // 1st - try to locate a valid dir in current host
        std::filesystem::path path = initial_path;
        const auto &vfs = initial_vfs;

        while( true ) {
            if( vfs->IterateDirectoryListing(path.native(), [](const VFSDirEnt &) { return false; }) ) {
                dispatch_to_main_queue([=] {
                    auto request = std::make_shared<DirectoryChangeRequest>();
                    request->RequestedDirectory = path.native();
                    request->VFS = vfs;
                    request->PerformAsynchronous = true;
                    [self GoToDirWithContext:request];
                });
                break;
            }

            if( path == "/" )
                break;

            path = path.parent_path();
        }

        // we can't work on this vfs. currently for simplicity - just go home
        auto request = std::make_shared<DirectoryChangeRequest>();
        request->RequestedDirectory = nc::base::CommonPaths::Home();
        request->VFS = m_NativeHost->SharedPtr();
        request->PerformAsynchronous = true;
        [self GoToDirWithContext:request];
    });
}

- (void)scheduleDelayedFocusing:(const DelayedFocusing &)request
{
    assert(dispatch_is_main_queue()); // to preserve against fancy threading stuff
    // we assume that _item_name will not contain any forward slashes

    if( request.filename.empty() )
        return;

    nc::panel::Log::Trace("[PanelController scheduleDelayedFocusing] called for '{}'", request.filename);

    m_DelayedSelection.request_end = nc::base::machtime() + request.timeout;
    m_DelayedSelection.filename = request.filename;
    m_DelayedSelection.done = request.done;

    if( request.check_now )
        [self checkAgainstRequestedFocusing];
}

// This function checks if a requested focusing can be satisfied and if so - changes the cursor.
// The check is destructive/has side effects - it clears a focus request if either it was satisfied
// or if it became outdated.
// Returns true if the request was satisfied and the cursor position was changed.
- (bool)checkAgainstRequestedFocusing
{
    assert(dispatch_is_main_queue()); // to preserve against fancy threading stuff
    if( m_DelayedSelection.filename.empty() )
        return false;

    if( nc::base::machtime() > m_DelayedSelection.request_end ) {
        nc::panel::Log::Trace("[PanelController checkAgainstRequestedFocusing] removing a stale request for '{}'",
                              m_DelayedSelection.filename);
        [self clearFocusingRequest];
        return false;
    }

    // now try to find it
    int raw_index = m_Data.RawIndexForName(m_DelayedSelection.filename);
    if( raw_index < 0 )
        return false;
    nc::panel::Log::Trace("[PanelController checkAgainstRequestedFocusing] found an entry for '{}'",
                          m_DelayedSelection.filename);

    // we found this entry. regardless of appearance of this entry in current directory presentation
    // there's no reason to search for it again
    auto done = std::move(m_DelayedSelection.done);

    const int sort_index = m_Data.SortedIndexForRawIndex(raw_index);
    if( sort_index >= 0 ) {
        m_View.curpos = sort_index;
        if( !self.isActive )
            [self.state ActivatePanelByController:self];
        if( done )
            done();
    }

    // focus requests are one-shot
    [self clearFocusingRequest];

    // return 'true' only if the entry was actually focused, regardless if it is present in raw
    // listing.
    return sort_index >= 0;
}

- (void)clearFocusingRequest
{
    m_DelayedSelection.filename.clear();
    m_DelayedSelection.done = nullptr;
}

- (BriefSystemOverview *)briefSystemOverview
{
    return [self.state briefSystemOverviewForPanel:self make:false];
}

- (id<NCPanelPreview>)quickLook
{
    return [self.state quickLookForPanel:self make:false];
}

- (nc::panel::PanelViewLayoutsStorage &)layoutStorage
{
    return *m_Layouts;
}

- (nc::core::VFSInstanceManager &)vfsInstanceManager
{
    return *m_VFSInstanceManager;
}

- (int)quickSearchNeedsCursorPosition:(NCPanelQuickSearch *) [[maybe_unused]] _qs
{
    return m_View.curpos;
}

- (void)quickSearch:(NCPanelQuickSearch *) [[maybe_unused]] _qs wantsToSetCursorPosition:(int)_cursor_position
{
    m_View.curpos = _cursor_position;
}

- (void)quickSearchHasChangedVolatileData:(NCPanelQuickSearch *) [[maybe_unused]] _qs
{
    [m_View volatileDataChanged];
}

- (void)quickSearchHasUpdatedData:(NCPanelQuickSearch *) [[maybe_unused]] _qs
{
    [m_View dataUpdated];
}

- (void)quickSearch:(NCPanelQuickSearch *) [[maybe_unused]] _qs
    wantsToSetSearchPrompt:(NSString *)_prompt
          withMatchesCount:(int)_count
{
    m_View.headerView.searchPrompt = _prompt;
    m_View.headerView.searchMatches = _count;
}

- (bool)isDoingBackgroundLoading
{
    return !m_DirectoryLoadingQ.Empty();
}

- (std::unique_ptr<nc::panel::DragReceiver>)panelView:(PanelView *) [[maybe_unused]] _view
                      requestsDragReceiverForDragging:(id<NSDraggingInfo>)_dragging
                                               onItem:(int)_on_sorted_index
{
    return std::make_unique<nc::panel::DragReceiver>(
        self, _dragging, _on_sorted_index, *m_NativeFSManager, *m_NativeHost);
}

- (void)hintAboutFilesystemChange
{
    Log::Trace("[PanelController hintAboutFilesystemChange] was called");
    dispatch_assert_main_queue(); // to preserve against fancy threading stuff
    if( self.receivesUpdateNotifications ) {
        // check in some future that the notification actually came
        const auto timestamp = nc::base::machtime();
        __weak PanelController *weak_me = self;
        dispatch_to_main_queue_after(g_FilesystemHintTriggerDelay, [weak_me, timestamp] {
            if( PanelController *const me = weak_me ) {
                // now check if our listing was created after we were hinted
                if( me->m_Data.Listing().BuildTicksTimestamp() > timestamp )
                    return; // yep, fresh enough.

                // nope, stale -> refresh
                [me refreshPanel];
            }
        });
    }
    else {
        // immediately request a listing reload since a notification won't come anyway
        [self refreshPanel];
    }
}

@end
