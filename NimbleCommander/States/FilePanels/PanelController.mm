#include "PanelController.h"
#include <Habanero/algo.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/NSMenu+Hierarchical.h>
#include <NimbleCommander/Operations/Copy/FileCopyOperation.h>
#include "../MainWindowController.h"
#include "Views/QuickPreview.h"
#include "MainWindowFilePanelState.h"
#include "PanelAux.h"
#include "SharingService.h"
#include "Views/BriefSystemOverview.h"
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Core/SandboxManager.h>
#include <Utility/ExtensionLowercaseComparison.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include "PanelDataPersistency.h"
#include <NimbleCommander/GeneralUI/AskForPasswordWindowController.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "PanelViewLayoutSupport.h"
#include "Helpers/Pasteboard.h"
#include "PanelDataItemVolatileData.h"
#include "PanelDataOptionsPersistence.h"
#include <Habanero/CommonPaths.h>
#include <VFS/Native.h>
#include "PanelHistory.h"
#include <Habanero/SerialQueue.h>
#include "PanelData.h"
#include "PanelView.h"
#include "PanelDataExternalEntryKey.h"
#include "PanelDataPersistency.h"
#include <NimbleCommander/Core/VFSInstanceManager.h>
#include "PanelController+Menu.h"
#include "NCPanelContextMenu.h"
#include "Actions/OpenFile.h"

using namespace ::nc::panel;

static const auto g_ConfigShowDotDotEntry                       = "filePanel.general.showDotDotEntry";
static const auto g_ConfigIgnoreDirectoriesOnMaskSelection      = "filePanel.general.ignoreDirectoriesOnSelectionWithMask";
static const auto g_ConfigShowLocalizedFilenames                = "filePanel.general.showLocalizedFilenames";
static const auto g_ConfigRouteKeyboardInputIntoTerminal        = "filePanel.general.routeKeyboardInputIntoTerminal";
static const auto g_ConfigQuickSearchWhereToFind                = "filePanel.quickSearch.whereToFind";
static const auto g_ConfigQuickSearchSoftFiltering              = "filePanel.quickSearch.softFiltering";
static const auto g_ConfigQuickSearchTypingView                 = "filePanel.quickSearch.typingView";
static const auto g_ConfigQuickSearchKeyOption                  = "filePanel.quickSearch.keyOption";

static const auto g_RestorationDataKey = "data";
static const auto g_RestorationSortingKey = "sorting";
static const auto g_RestorationLayoutKey = "layout";

struct PanelQuickSearchMode
{
    enum KeyModif { // persistancy-bound values, don't change it
        WithAlt         = 0,
        WithCtrlAlt     = 1,
        WithShiftAlt    = 2,
        WithoutModif    = 3,
        Disabled        = 4
    };
    
    static KeyModif KeyModifFromInt(int _k)
    {
        if(_k >= 0 && _k <= Disabled)
            return (KeyModif)_k;
        return WithAlt;
    }
};

namespace nc::panel {

ActivityTicket::ActivityTicket():
    panel(nil),
    ticket(0)
{
}

ActivityTicket::ActivityTicket(PanelController *_panel, uint64_t _ticket):
    panel(_panel),
    ticket(_ticket)
{
}

ActivityTicket::ActivityTicket( ActivityTicket&& _rhs):
    panel(_rhs.panel),
    ticket(_rhs.ticket)
{
    _rhs.panel = nil;
    _rhs.ticket = 0;
}

ActivityTicket::~ActivityTicket()
{
    Reset();
}

void ActivityTicket::operator=(ActivityTicket&&_rhs)
{
    Reset();
    panel = _rhs.panel;
    ticket = _rhs.ticket;
    _rhs.panel = nil;
    _rhs.ticket = 0;
}

void ActivityTicket::Reset()
{
    if( ticket )
        if( PanelController *pc = panel )
            [pc finishExtActivityWithTicket:ticket];
    panel = nil;
    ticket = 0;
}


class GenericCursorPersistance
{
public:
    GenericCursorPersistance(PanelView* _view, const data::Model &_data);
    void Restore() const;
    
private:
    PanelView                  *m_View;
    const data::Model          &m_Data;
    string                      m_OldCursorName;
    data::ExternalEntryKey      m_OldEntrySortKeys;
};
    
GenericCursorPersistance::GenericCursorPersistance(PanelView* _view, const data::Model &_data):
    m_View(_view),
    m_Data(_data)
{
    auto cur_pos = _view.curpos;
    if(cur_pos >= 0 && m_View.item ) {
        m_OldCursorName = m_View.item.Name();
        m_OldEntrySortKeys = _data.EntrySortKeysAtSortPosition(cur_pos);
    }
}

void GenericCursorPersistance::Restore() const
{
    int newcursorrawpos = m_Data.RawIndexForName(m_OldCursorName.c_str());
    if( newcursorrawpos >= 0 ) {
        int newcursorsortpos = m_Data.SortedIndexForRawIndex(newcursorrawpos);
        if(newcursorsortpos >= 0)
            m_View.curpos = newcursorsortpos;
        else
            m_View.curpos = m_Data.SortedDirectoryEntries().empty() ? -1 : 0;
    }
    else {
        int lower_bound = m_Data.SortLowerBoundForEntrySortKeys(m_OldEntrySortKeys);
        if( lower_bound >= 0) {
            m_View.curpos = lower_bound;
        }
        else {
            m_View.curpos = m_Data.SortedDirectoryEntries().empty() ? -1 : int(m_Data.SortedDirectoryEntries().size()) - 1;
        }
    }
}

}

static bool IsItemInArchivesWhitelist( const VFSListingItem &_item ) noexcept
{
    if( _item.IsDir() )
        return false;

    if( !_item.HasExtension() )
        return false;
    
    return IsExtensionInArchivesWhitelist(_item.Extension());
}

static void ShowExceptionAlert( const string &_message = "" )
{
    if( dispatch_is_main_queue() ) {
        auto alert = [[Alert alloc] init];
        alert.messageText = @"Unexpected exception was caught:";
        alert.informativeText = !_message.empty() ?
            [NSString stringWithUTF8StdString:_message] :
            @"Unknown exception";
        [alert runModal];
    }
    else {
        dispatch_to_main_queue([_message]{
            ShowExceptionAlert(_message);
        });
    }
}


#define MAKE_AUTO_UPDATING_BOOL_CONFIG_VALUE( _name, _path )\
static bool _name()\
{\
    static const auto fetch = []{\
        return GlobalConfig().GetBool((_path));\
    };\
    static bool value = []{\
        static auto ticket = GlobalConfig().Observe((_path), []{\
            value = fetch();\
        });\
        return fetch();\
    }();\
    return value;\
}

MAKE_AUTO_UPDATING_BOOL_CONFIG_VALUE(ConfigShowDotDotEntry, g_ConfigShowDotDotEntry);
MAKE_AUTO_UPDATING_BOOL_CONFIG_VALUE(ConfigShowLocalizedFilenames, g_ConfigShowLocalizedFilenames);

static void HeatUpConfigValues()
{
    ConfigShowDotDotEntry();
    ConfigShowLocalizedFilenames();
}

@implementation PanelController
{
    // Main controller's possessions
    data::Model                  m_Data;   // owns
    PanelView                   *m_View;  // create and owns
    
    // VFS changes observation
    VFSHostDirObservationTicket  m_UpdatesObservationTicket;
    
    // VFS listing fetch flags
    int                         m_VFSFetchingFlags;
    
    // Quick searching section
    bool                                m_QuickSearchIsSoftFiltering;
    bool                                m_QuickSearchTypingView;
    PanelQuickSearchMode::KeyModif      m_QuickSearchMode;
    data::TextualFilter::Where          m_QuickSearchWhere;
    nanoseconds                         m_QuickSearchLastType;
    unsigned                            m_QuickSearchOffset;
    
    // background operations' queues
    SerialQueue m_DirectorySizeCountingQ;
    SerialQueue m_DirectoryLoadingQ;
    SerialQueue m_DirectoryReLoadingQ;
    
    // navigation support
    History m_History;
    
    // spinning indicator support
    bool                m_IsAnythingWorksInBackground;
    
    // Tickets to show some external activities on this panel
    uint64_t            m_NextActivityTicket;
    vector<uint64_t>    m_ActivitiesTickets;
    spinlock            m_ActivitiesTicketsLock;
    
    // QuickLook support
    __weak QuickLookView *m_QuickLook;
    
    // BriefSystemOverview support
    __weak BriefSystemOverview* m_BriefSystemOverview;
    
    // delayed entry selection support
    struct
    {
        /**
         * Requested item name to select. Empty filename means that request is invalid.
         */
        string      filename;
        
        /**
         * Time after which request is meaningless and should be removed
         */
        nanoseconds    request_end;

        /**
         * Called when changed a cursor position
         */
        function<void()> done;
    } m_DelayedSelection;
    
    __weak MainWindowFilePanelState* m_FilePanelState;
    
    vector<GenericConfig::ObservationTicket> m_ConfigObservers;

    int                                 m_ViewLayoutIndex;
    shared_ptr<const PanelViewLayout>   m_AssignedViewLayout;
    PanelViewLayoutsStorage::ObservationTicket m_LayoutsObservation;
}

@synthesize view = m_View;
@synthesize data = m_Data;
@synthesize history = m_History;
@synthesize layoutIndex = m_ViewLayoutIndex;
@synthesize vfsFetchingFlags = m_VFSFetchingFlags;

- (id) init
{
    static once_flag once;
    call_once(once, HeatUpConfigValues);

    self = [super init];
    if(self) {
        m_QuickSearchLastType = 0ns;
        m_QuickSearchOffset = 0;
        m_VFSFetchingFlags = 0;
        m_NextActivityTicket = 1;
        m_IsAnythingWorksInBackground = false;
        m_ViewLayoutIndex = AppDelegate.me.panelLayouts.DefaultLayoutIndex();
        m_AssignedViewLayout = AppDelegate.me.panelLayouts.DefaultLayout();
        
        __weak PanelController* weakself = self;
        auto on_change = [=]{
            dispatch_to_main_queue([=]{
                [(PanelController*)weakself updateSpinningIndicator];
            });
        };
        m_DirectorySizeCountingQ.SetOnChange(on_change);
        m_DirectoryReLoadingQ.SetOnChange(on_change);
        m_DirectoryLoadingQ.SetOnChange(on_change);
        
        static const auto pv_rect = NSMakeRect(0, 0, 100, 100);
        m_View = [[PanelView alloc] initWithFrame:pv_rect layout:*m_AssignedViewLayout];
        m_View.delegate = self;
        m_View.data = &m_Data;
        
        // wire up config changing notifications
        auto add_co = [&](const char *_path, SEL _sel) { m_ConfigObservers.
            emplace_back( GlobalConfig().Observe(_path, objc_callback(self, _sel)) );
        };
        add_co(g_ConfigShowDotDotEntry,         @selector(configVFSFetchFlagsChanged) );
        add_co(g_ConfigShowLocalizedFilenames,  @selector(configVFSFetchFlagsChanged) );
        add_co(g_ConfigQuickSearchWhereToFind,  @selector(configQuickSearchSettingsChanged) );
        add_co(g_ConfigQuickSearchSoftFiltering,@selector(configQuickSearchSettingsChanged) );
        add_co(g_ConfigQuickSearchTypingView,   @selector(configQuickSearchSettingsChanged) );
        add_co(g_ConfigQuickSearchKeyOption,    @selector(configQuickSearchSettingsChanged) );
        
        m_LayoutsObservation = AppDelegate.me.panelLayouts.
            ObserveChanges( objc_callback(self, @selector(panelLayoutsChanged)) );
        
        // loading config via simulating it's change
        [self configVFSFetchFlagsChanged];
        [self configQuickSearchSettingsChanged];
    }

    return self;
}

- (void) dealloc
{
    // we need to manually set data to nullptr, since PanelView can be destroyed a bit later due to other strong pointers.
    // in that case view will contain a dangling pointer, which can lead to crash.
    m_View.data = nullptr;
}

- (void)configVFSFetchFlagsChanged
{
    if( ConfigShowDotDotEntry() == false )
        m_VFSFetchingFlags |= VFSFlags::F_NoDotDot;
    else
        m_VFSFetchingFlags &= ~VFSFlags::F_NoDotDot;
    
    if( ConfigShowLocalizedFilenames() == true )
        m_VFSFetchingFlags |= VFSFlags::F_LoadDisplayNames;
    else
        m_VFSFetchingFlags &= ~VFSFlags::F_LoadDisplayNames;
    
    [self refreshPanel];
}

- (void)configQuickSearchSettingsChanged
{
    m_QuickSearchWhere = data::TextualFilter::WhereFromInt( GlobalConfig().GetInt(g_ConfigQuickSearchWhereToFind) );
    m_QuickSearchIsSoftFiltering = GlobalConfig().GetBool( g_ConfigQuickSearchSoftFiltering );
    m_QuickSearchTypingView = GlobalConfig().GetBool( g_ConfigQuickSearchTypingView );
    m_QuickSearchMode = PanelQuickSearchMode::KeyModifFromInt( GlobalConfig().GetInt(g_ConfigQuickSearchKeyOption) );
    [self QuickSearchClearFiltering];
}

- (void) setState:(MainWindowFilePanelState *)state
{
    m_FilePanelState = state;
}

- (MainWindowFilePanelState*)state
{
    return m_FilePanelState;
}

- (NSWindow*) window
{
    return self.state.window;
}

- (MainWindowController *)mainWindowController
{
    return (MainWindowController*)self.window.delegate;
}

- (bool) isUniform
{
    return m_Data.Listing().IsUniform();
}

- (bool) receivesUpdateNotifications
{
    return (bool)m_UpdatesObservationTicket;
}

- (bool) ignoreDirectoriesOnSelectionByMask
{
    return GlobalConfig().GetBool(g_ConfigIgnoreDirectoriesOnMaskSelection);
}

- (void) copyOptionsFromController:(PanelController*)_pc
{
    if( !_pc )
        return;
    
    data::OptionsImporter{m_Data}.Import( data::OptionsExporter{_pc.data}.Export() );
    [self.view dataUpdated];
    [self.view dataSortingHasChanged];
    self.layoutIndex = _pc.layoutIndex;
}

- (bool) isActive
{
    return m_View.active;
}

- (void) changeSortingModeTo:(data::SortMode)_mode
{
    if( _mode != m_Data.SortMode() ) {
        GenericCursorPersistance pers(m_View, m_Data);
        
        m_Data.SetSortMode(_mode);
        
        pers.Restore();
        
        [m_View dataSortingHasChanged];
        [m_View dataUpdated];
        [self markRestorableStateAsInvalid];
    }
}

- (void) changeHardFilteringTo:(data::HardFilter)_filter
{
    if( _filter != m_Data.HardFiltering() ) {
        GenericCursorPersistance pers(m_View, m_Data);
        
        m_Data.SetHardFiltering(_filter);
        
        pers.Restore();
        [m_View dataUpdated];
        [self markRestorableStateAsInvalid];
    }
}

- (bool) HandleGoToUpperDirectory
{
    if( self.isUniform  ) {
        path cur = path(m_Data.DirectoryPathWithTrailingSlash());
        if( cur.empty() )
            return false;
        if( cur == "/" ) {
            if( self.vfs->Parent() != nullptr ) {
                path junct = self.vfs->JunctionPath();
                assert(!junct.empty());
                string dir = junct.parent_path().native();
                string sel_fn = junct.filename().native();
                
                if(self.vfs->Parent()->IsNativeFS() && ![self ensureCanGoToNativeFolderSync:dir])
                    return true; // silently reap this command, since user refuses to grant an access
                return [self GoToDir:dir vfs:self.vfs->Parent() select_entry:sel_fn loadPreviousState:true async:true] == 0;
            }
        }
        else {
            string dir = cur.parent_path().remove_filename().native();
            string sel_fn = cur.parent_path().filename().native();
            
            if( self.vfs->IsNativeFS() && ![self ensureCanGoToNativeFolderSync:dir] )
                return true; // silently reap this command, since user refuses to grant an access
            return [self GoToDir:dir vfs:self.vfs select_entry:sel_fn loadPreviousState:true async:true] == 0;
        }
    }
    else
        [self OnGoBack:self];
    return false;
}

- (bool) handleGoIntoDirOrArchiveSync:(bool)_whitelist_archive_only
{
    const auto entry = m_View.item;
    if( !entry )
        return false;
    
    // Handle directories.
    if(entry.IsDir()) {
        if(entry.IsDotDot())
            return [self HandleGoToUpperDirectory];
        
        if(entry.Host()->IsNativeFS() && ![self ensureCanGoToNativeFolderSync:entry.Path()])
            return true; // silently reap this command, since user refuses to grant an access
        
        return [self GoToDir:entry.Path() vfs:entry.Host() select_entry:"" async:true] == 0;
    }
    // archive stuff here
    // will actually go async for archives
    else if( ActivationManager::Instance().HasArchivesBrowsing() ) {
        if( !_whitelist_archive_only || IsItemInArchivesWhitelist(entry) ) {
            m_DirectoryLoadingQ.Run([=]{
                // background
                auto pwd_ask = [=]{ string p; return RunAskForPasswordModalWindow(entry.Filename(), p) ? p : ""; };
                
                auto arhost = VFSArchiveProxy::OpenFileAsArchive(entry.Path(),
                                                                 entry.Host(),
                                                                 pwd_ask,
                                                                 [=]{ return m_DirectoryLoadingQ.IsStopped(); }
                                                                 );
                
                if( arhost )
                    dispatch_to_main_queue([=]{
                        [self GoToDir:"/" vfs:arhost select_entry:"" async:true];
                    });
            });
            return true;
        }
    }
    
    return false;
}

- (void) handleGoIntoDirOrOpenInSystemSync
{
    if( self.state && [self.state handleReturnKeyWithOverlappedTerminal] )
        return;
    
    if([self handleGoIntoDirOrArchiveSync:true])
        return;
    
    auto entry = m_View.item;
    if( !entry )
        return;
    
    // need more sophisticated executable handling here
    if( ActivationManager::Instance().HasTerminal() &&
        !entry.IsDotDot() &&
        entry.Host()->IsNativeFS() &&
        IsEligbleToTryToExecuteInConsole(entry) ) {
        [self.state requestTerminalExecution:entry.Name() at:entry.Directory()];
        return;
    }
    
    // If previous code didn't handle current item,
    // open item with the default associated application.
    actions::OpenFileWithDefaultHandler{}.Perform(self, self);
}

- (void) ReLoadRefreshedListing:(const VFSListingPtr &)_ptr
{
    assert(dispatch_is_main_queue());
    
    GenericCursorPersistance pers(m_View, m_Data);
    
    m_Data.ReLoad(_ptr);
    [m_View dataUpdated];
    
    if(![self CheckAgainstRequestedSelection])
        pers.Restore();
    
    [self OnCursorChanged];
    [self QuickSearchUpdate];
    [m_View setNeedsDisplay];
}

- (void) refreshPanelDiscardingCaches:(bool)_force
{
    if(m_View == nil)
        return; // guard agains calls from init process
    if( m_Data.Listing().shared_from_this() == VFSListing::EmptyListing() )
        return; // guard agains calls from init process
    
    if( !m_DirectoryLoadingQ.Empty() )
        return; //reducing overhead

    // later: maybe check PanelType somehow
    
    if( self.isUniform ) {
        const auto fetch_flags = m_VFSFetchingFlags | (_force ? VFSFlags::F_ForceRefresh : 0);
        const auto dirpath = m_Data.DirectoryPathWithTrailingSlash();
        const auto vfs = self.vfs;
        
        m_DirectoryReLoadingQ.Run([=]{
            VFSListingPtr listing;
            int ret = vfs->FetchDirectoryListing(dirpath.c_str(),
                                                 listing,
                                                 fetch_flags,
                                                 [&]{ return m_DirectoryReLoadingQ.IsStopped(); }
                                                 );
            if(ret >= 0)
                dispatch_to_main_queue( [=]{
                    [self ReLoadRefreshedListing:listing];
                });
            else
                dispatch_to_main_queue( [=]{
                    [self RecoverFromInvalidDirectory];
                });
        });
    }
    else {
        m_DirectoryReLoadingQ.Run([=]{
            auto listing = VFSListing::ProduceUpdatedTemporaryPanelListing(
                m_Data.Listing(),
                [&]{ return m_DirectoryReLoadingQ.IsStopped(); }
                );
            if( listing )
                dispatch_to_main_queue( [=]{
                    [self ReLoadRefreshedListing:listing];
                });
        });
    }
}

- (void) refreshPanel
{
   [self refreshPanelDiscardingCaches:false];
}

- (void) forceRefreshPanel
{
    [self refreshPanelDiscardingCaches:true];
}

static bool RouteKeyboardInputIntoTerminal()
{
    static bool route = GlobalConfig().GetBool( g_ConfigRouteKeyboardInputIntoTerminal );
    static auto observe_ticket = GlobalConfig().Observe(g_ConfigRouteKeyboardInputIntoTerminal, []{
        route = GlobalConfig().GetBool( g_ConfigRouteKeyboardInputIntoTerminal );
    });
    return route;
}

- (bool) PanelViewProcessKeyDown:(PanelView*)_view event:(NSEvent *)event
{
    [self ClearSelectionRequest]; // on any key press we clear entry selection request if any
 
    const bool route_to_overlapped_terminal = RouteKeyboardInputIntoTerminal();
    const bool terminal_can_eat = route_to_overlapped_terminal &&
                                  [self.state overlappedTerminalWillEatKeyDown:event];
    
    NSString*  const character   = event.charactersIgnoringModifiers;
    if ( character.length > 0 ) {
        NSUInteger const modif       = event.modifierFlags;
        unichar const unicode        = [character characterAtIndex:0];
        unsigned short const keycode = event.keyCode;
        
//        if(keycode == 3 ) { // 'F' button
//            if( (modif&NSDeviceIndependentModifierFlagsMask) == (NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) {
//                
//                static const auto account = "mike.kazakov@gmail.com";
//                static const auto g_Token = "4LRIcv92dSgAAAAAAAAMENZLSUeRl53EU1iwuuw4FecM1Y27FEjEXch4HDd3oK3N";
////                static const auto g_Token = "-chTBf0f5HAAAAAAAAAACybjBH4SYO9sh3HrD_TtKyUusrLu0yWYustS3CdlqYkN";
//                shared_ptr<VFSHost> host = make_shared<VFSNetDropboxHost>(account, g_Token);
//                
//                [self GoToDir:"/"
//                          vfs:host
//                 select_entry:""
//                        async:true];
//                
//                
//                return true;
//            }
//        }
        
        if( unicode == NSTabCharacter ) { // Tab button
            [self.state changeFocusedSide];
            return true;
        }
        if( keycode == 53 ) { // Esc button
            [self CancelBackgroundOperations];
            [self.state CloseOverlay:self];
            m_BriefSystemOverview = nil;
            m_QuickLook = nil;
            [self QuickSearchClearFiltering];
            return true;
        }
        
        // handle some actions manually, to prevent annoying by menu highlighting by hotkey
        static ActionsShortcutsManager::ShortCut hk_file_open, hk_file_open_native, hk_go_root, hk_go_home, hk_preview, hk_go_into, kh_go_outside;
        static ActionsShortcutsManager::ShortCutsUpdater hotkeys_updater({&hk_file_open, &hk_file_open_native, &hk_go_root, &hk_go_home, &hk_preview, &hk_go_into, &kh_go_outside}, {"menu.file.open", "menu.file.open_native", "panel.go_root", "panel.go_home", "panel.show_preview", "panel.go_into_folder", "panel.go_into_enclosing_folder"});

        if( !terminal_can_eat ) {
            if( hk_preview.IsKeyDown(unicode, keycode, modif) ) {
                [self OnFileViewCommand:self];
                return true;
            }
            if( hk_go_home.IsKeyDown(unicode, keycode, modif) ) {
                static auto tag = ActionsShortcutsManager::Instance().TagFromAction("menu.go.home");
                [[NSApp menu] performActionForItemWithTagHierarchical:tag];
                return true;
            }
            if( hk_go_root.IsKeyDown(unicode, keycode, modif) ) {
                static auto tag = ActionsShortcutsManager::Instance().TagFromAction("menu.go.root");
                [[NSApp menu] performActionForItemWithTagHierarchical:tag];
                return true;
            }
            if( hk_go_into.IsKeyDown(unicode, keycode, modif) ) {
                static auto tag = ActionsShortcutsManager::Instance().TagFromAction("menu.go.into_folder");
                [[NSApp menu] performActionForItemWithTagHierarchical:tag];
                return true;
            }
            if( kh_go_outside.IsKeyDown(unicode, keycode, modif) ) {
                static auto tag = ActionsShortcutsManager::Instance().TagFromAction("menu.go.enclosing_folder");
                [[NSApp menu] performActionForItemWithTagHierarchical:tag];
                return true;
            }
            if( hk_file_open.IsKeyDown(unicode, keycode, modif) ) {
                // we keep it here to avoid blinking on menu item
                [self handleGoIntoDirOrOpenInSystemSync];
                return true;
            }
            if( hk_file_open_native.IsKeyDown(unicode, keycode, modif) ) {
                // we keep it here to avoid blinking on menu item
                actions::OpenFileWithDefaultHandler{}.Perform(self, self);
                return true;
            }
        }
        
        // try to process this keypress with QuickSearch
        if( [self QuickSearchProcessKeyDown:event] )
            return true;
        
        if(keycode == 51 && // backspace
           (modif & (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) == 0 &&
           !terminal_can_eat
           ) { // treat not-processed by QuickSearch backspace as a GoToUpperLevel command
            return [self HandleGoToUpperDirectory];
        }
        
        if( terminal_can_eat && [self.state feedOverlappedTerminalWithKeyDown:event] )
            return true;
    }
    
    return false;
}

- (void) calculateSizesOfItems:(const vector<VFSListingItem>&) _items
{
    if( _items.empty() )
        return;
    m_DirectorySizeCountingQ.Run([=]{
        for(auto &i:_items) {
            if( !i.IsDir() )
                continue;
            if( m_DirectorySizeCountingQ.IsStopped() )
                return;
            
            auto result = i.Host()->CalculateDirectorySize(
                !i.IsDotDot() ? i.Path().c_str() : i.Directory().c_str(),
                [=]{ return m_DirectorySizeCountingQ.IsStopped(); }
                );
            if( result >= 0 )
                dispatch_to_main_queue([=]{
                    GenericCursorPersistance pers(m_View, m_Data);
                    // may cause re-sorting if current sorting is by size
                    if( m_Data.SetCalculatedSizeForDirectory(i.Name(), i.Directory().c_str(), result) ) {
                        [m_View dataUpdated];
                        [m_View volatileDataChanged];
                        pers.Restore();
                    }
                });
        }
    });
}

- (void) CancelBackgroundOperations
{
    m_DirectorySizeCountingQ.Stop();
    m_DirectoryLoadingQ.Stop();
    m_DirectoryReLoadingQ.Stop();
}

- (void) updateSpinningIndicator
{
    dispatch_assert_main_queue();
    
    size_t ext_activities_no = call_locked(m_ActivitiesTicketsLock,
                                           [&]{ return m_ActivitiesTickets.size(); });
    bool is_anything_working = !m_DirectorySizeCountingQ.Empty() ||
                               !m_DirectoryLoadingQ.Empty() ||
                               !m_DirectoryReLoadingQ.Empty() ||
                                ext_activities_no > 0;
    
    if( is_anything_working == m_IsAnythingWorksInBackground )
        return; // nothing to update;
        
    if( is_anything_working ) {
        // there should be 100ms of workload before the user gets the spinning indicator
        dispatch_to_main_queue_after(100ms, [=]{
                            // need to check if task was already done
                           if( m_IsAnythingWorksInBackground )
                               [m_View.busyIndicator startAnimation:nil];
                       });
    }
    else
        [m_View.busyIndicator stopAnimation:nil];
    
    m_IsAnythingWorksInBackground = is_anything_working;
}

- (void) selectEntriesWithFilenames:(const vector<string>&)_filenames
{
    for( auto &i: _filenames )
        m_Data.CustomFlagsSelectSorted( m_Data.SortedIndexForName(i.c_str()), true );
    [m_View volatileDataChanged];
}

- (void) setEntriesSelection:(const vector<bool>&)_selection
{
    if( m_Data.CustomFlagsSelectSorted(_selection) )
        [m_View volatileDataChanged];
}

- (void) OnPathChanged
{
    // update directory changes notification ticket
    __weak PanelController *weakself = self;
    m_UpdatesObservationTicket.reset();    
    if( self.isUniform )
        m_UpdatesObservationTicket = self.vfs->DirChangeObserve(self.currentDirectoryPath.c_str(), [=]{
            dispatch_to_main_queue([=]{
                [(PanelController *)weakself refreshPanel];
            });
        });
    
    [self ClearSelectionRequest];
    [self QuickSearchClearFiltering];
    [self.state PanelPathChanged:self];
    [self OnCursorChanged];
    [self UpdateBriefSystemOverview];

    if( self.isUniform )
        m_History.Put( self.vfs, self.currentDirectoryPath );
    
    [self markRestorableStateAsInvalid];
}

- (void) markRestorableStateAsInvalid
{
    if( auto wc = objc_cast<MainWindowController>(self.state.window.delegate) )
        [wc invalidateRestorableState];
}

- (void) OnCursorChanged
{
    // update QuickLook if any
    if( auto i = self.view.item )
        [(QuickLookView *)m_QuickLook PreviewItem:i.Path() vfs:i.Host()];
}

- (void) UpdateBriefSystemOverview
{
    if( auto bso = (BriefSystemOverview *)m_BriefSystemOverview ) {
        if( auto i = self.view.item )
            [bso UpdateVFSTarget:i.Directory() host:i.Host()];
        else if( self.isUniform )
            [bso UpdateVFSTarget:self.currentDirectoryPath host:self.vfs];
    }
}

- (void) PanelViewCursorChanged:(PanelView*)_view
{
    [self OnCursorChanged];
}

- (NSMenu*) panelView:(PanelView*)_view requestsContextMenuForItemNo:(int)_sort_pos
{
    dispatch_assert_main_queue();
    
    const auto clicked_item = m_Data.EntryAtSortPosition(_sort_pos);
    if( !clicked_item || clicked_item.IsDotDot() )
        return nil;
    
    const auto clicked_item_vd = m_Data.VolatileDataAtSortPosition(_sort_pos);
    
    vector<VFSListingItem> vfs_items;
    if( clicked_item_vd.is_selected() == false)
        vfs_items.emplace_back(clicked_item); // only clicked item
    else
        vfs_items = m_Data.SelectedEntries(); // all selected items
    
    for( auto &i: vfs_items )
        m_Data.VolatileDataAtRawPosition(i.Index()).toggle_highlight(true);
    [_view volatileDataChanged];
    
    const auto menu = [[NCPanelContextMenu alloc] initWithItems:move(vfs_items)
                                                        ofPanel:self];
    return menu;
}

- (void) contextMenuDidClose:(NSMenu*)_menu
{
    m_Data.CustomFlagsClearHighlights();
    [m_View volatileDataChanged];
}

- (void) PanelViewDoubleClick:(PanelView*)_view atElement:(int)_sort_pos
{
    [self handleGoIntoDirOrOpenInSystemSync];
}

- (void) PanelViewRenamingFieldEditorFinished:(PanelView*)_view text:(NSString*)_filename
{
    if(_filename == nil ||
       _filename.length == 0 ||
       _filename.fileSystemRepresentation == nullptr ||
       [_filename isEqualToString:@"."] ||
       [_filename isEqualToString:@".."] ||
       !m_View.item ||
       m_View.item.IsDotDot() ||
       !m_View.item.Host()->IsWritable() ||
       [_filename isEqualToString:m_View.item.NSName()])
        return;
    
    string target_fn = _filename.fileSystemRepresentationSafe;
    auto item = m_View.item;
    
 
    // checking for invalid symbols
    if( !item.Host()->ValidateFilename(target_fn.c_str()) ) {
        Alert *a = [[Alert alloc] init];
        a.messageText = [NSString stringWithFormat:NSLocalizedString(@"The name “%@” can’t be used.", "Message text when user is entering an invalid filename"),
                         _filename.length <= 256 ? _filename : [[_filename substringToIndex:256] stringByAppendingString:@"..."]
                         ];
        a.informativeText = NSLocalizedString(@"Try using a name with fewer characters or without punctuation marks.", "Informative text when user is entering an invalid filename");
        a.alertStyle = NSCriticalAlertStyle;
        [a runModal];
        return;
    }
    
    FileCopyOperation *op = [FileCopyOperation singleItemRenameOperation:item newName:target_fn];

    if( self.isUniform ) {
        string curr_path = self.currentDirectoryPath;
        auto curr_vfs = self.vfs;
        [op AddOnFinishHandler:^{
            if(self.currentDirectoryPath == curr_path && self.vfs == curr_vfs)
                dispatch_to_main_queue( [=]{
                    DelayedSelection req;
                    req.filename = target_fn;
                    [self ScheduleDelayedSelectionChangeFor:req];
                    [self refreshPanel];
                } );
        }];
    }
    
    [self.state AddOperation:op];
}

- (void) panelViewDidBecomeFirstResponder
{
    [self.state activePanelChangedTo:self];
//    [self ModifierFlagsChanged:[NSEvent modifierFlags]];
}

+ (bool) ensureCanGoToNativeFolderSync:(const string&)_path
{
    return SandboxManager::EnsurePathAccess(_path);
}

- (bool)ensureCanGoToNativeFolderSync:(const string&)_path
{
    return [PanelController ensureCanGoToNativeFolderSync:_path];
}

- (optional<rapidjson::StandaloneValue>) encodeRestorableState
{
    rapidjson::StandaloneValue json(rapidjson::kObjectType);
    
    if( auto v = PanelDataPersisency::EncodeVFSPath(m_Data.Listing()) )
        json.AddMember(rapidjson::StandaloneValue(g_RestorationDataKey, rapidjson::g_CrtAllocator),
                       move(*v),
                       rapidjson::g_CrtAllocator );
    else
        return nullopt;
  
    json.AddMember(rapidjson::StandaloneValue(g_RestorationSortingKey, rapidjson::g_CrtAllocator),
                   data::OptionsExporter{m_Data}.Export(), rapidjson::g_CrtAllocator );
    json.AddMember(rapidjson::StandaloneValue(g_RestorationLayoutKey, rapidjson::g_CrtAllocator),
                   rapidjson::StandaloneValue(m_ViewLayoutIndex), rapidjson::g_CrtAllocator );
    
    return move(json);
}

- (bool) loadRestorableState:(const rapidjson::StandaloneValue&)_state
{
    assert(dispatch_is_main_queue());
    if( _state.IsObject() ) {
        if( _state.HasMember(g_RestorationSortingKey) ) {
            GenericCursorPersistance pers(m_View, m_Data);
            data::OptionsImporter{m_Data}.Import( _state[g_RestorationSortingKey] );
            [m_View dataUpdated];
            [m_View dataSortingHasChanged];
            pers.Restore();
        }
        
        if( _state.HasMember(g_RestorationLayoutKey) )
            if( _state[g_RestorationLayoutKey].IsNumber() )
                self.layoutIndex = _state[g_RestorationLayoutKey].GetInt();
        
        if( _state.HasMember(g_RestorationDataKey) ) {
            auto data = make_shared<rapidjson::StandaloneValue>();
            data->CopyFrom(_state[g_RestorationDataKey], rapidjson::g_CrtAllocator);
            m_DirectoryLoadingQ.Run([=]{
                VFSHostPtr host;
                if( PanelDataPersisency::CreateVFSFromState(*data, host) == VFSError::Ok ) {
                    string path = PanelDataPersisency::GetPathFromState(*data);
                    dispatch_to_main_queue([=]{
                        auto context = make_shared<DirectoryChangeRequest>();
                        context->VFS = host;
                        context->PerformAsynchronous = true;
                        context->RequestedDirectory = path;
                        [self GoToDirWithContext:context];
                    });
                }
            });
        }
        return true;
    }
    return false;
}

- (id)validRequestorForSendType:(NSString *)sendType
                     returnType:(NSString *)returnType
{
    if(([sendType isEqualToString:NSFilenamesPboardType] ||
        [sendType isEqualToString:(__bridge NSString *)kUTTypeFileURL]))
        return self;
    
    return [super validRequestorForSendType:sendType returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
    if( [types containsObject:(__bridge NSString *)kUTTypeFileURL] )
        return PasteboardSupport::WriteURLSPBoard(self.selectedEntriesOrFocusedEntry,
                                                         pboard);
    if( [types containsObject:NSFilenamesPboardType] )
        return PasteboardSupport::WriteFilesnamesPBoard(self.selectedEntriesOrFocusedEntry,
                                                               pboard);
    return false;
}

- (ActivityTicket) registerExtActivity
{
    auto ticket = call_locked(m_ActivitiesTicketsLock, [&]{
        m_ActivitiesTickets.emplace_back( m_NextActivityTicket );
        return ActivityTicket(self, m_NextActivityTicket++);
    });
    dispatch_to_main_queue([=]{
        [self updateSpinningIndicator];
    });
    return ticket;
}

- (void) finishExtActivityWithTicket:(uint64_t)_ticket
{
    LOCK_GUARD(m_ActivitiesTicketsLock) {
        auto i = find(begin(m_ActivitiesTickets), end(m_ActivitiesTickets), _ticket);
        if( i == end(m_ActivitiesTickets) )
            return;
        m_ActivitiesTickets.erase(i);
    }
    dispatch_to_main_queue([=]{
        [self updateSpinningIndicator];
    });
}

- (void) setLayoutIndex:(int)layoutIndex
{
    if( m_ViewLayoutIndex != layoutIndex ) {
        if( auto l = AppDelegate.me.panelLayouts.GetLayout(layoutIndex) )
            if( !l->is_disabled() ) {
                m_ViewLayoutIndex = layoutIndex;
                m_AssignedViewLayout = l;
                [m_View setPresentationLayout:*l];
                [self markRestorableStateAsInvalid];                
            }
    }
}

- (void) panelLayoutsChanged
{
    if( auto l = AppDelegate.me.panelLayouts.GetLayout(m_ViewLayoutIndex) ) {
        if( m_AssignedViewLayout && *m_AssignedViewLayout == *l )
            return;
        
        if( !l->is_disabled() ) {
            m_AssignedViewLayout = l;
            [m_View setPresentationLayout:*l];
        }
        else {
            m_AssignedViewLayout = AppDelegate.me.panelLayouts.LastResortLayout();
            [m_View setPresentationLayout:*m_AssignedViewLayout];
        }
    }
}

- (void) panelViewDidChangePresentationLayout
{
    PanelViewLayout layout;
    layout.name = m_AssignedViewLayout->name;
    layout.layout = [m_View presentationLayout];

    if( layout != *m_AssignedViewLayout )
        AppDelegate.me.panelLayouts.ReplaceLayout( move(layout), m_ViewLayoutIndex );
}

- (void) commitCancelableLoadingTask:(function<void(const function<bool()> &_is_cancelled)>) _task
{
    auto sq = &m_DirectoryLoadingQ;
    m_DirectoryLoadingQ.Run([=]{
        _task( [sq]{ return sq->IsStopped(); } );
    });
}

- (NetworkConnectionsManager&)networkConnectionsManager
{
    return AppDelegate.me.networkConnectionsManager;
}

- (void) GoToVFSPromise:(const VFSInstanceManager::Promise&)_promise onPath:(const string&)_directory
{
//    m_DirectoryLoadingQ->Run([=](const SerialQueue &_q){
    m_DirectoryLoadingQ.Run([=](){
        VFSHostPtr host;
        try {
            host = VFSInstanceManager::Instance().RetrieveVFS(_promise,
                                                              [&]{ return m_DirectoryLoadingQ.IsStopped(); }
                                                              );
        } catch (VFSErrorException &e) {
            return; // TODO: something
        }
        
        // TODO: need an ability to show errors at least
        dispatch_to_main_queue([=]{
            [self GoToDir:_directory
                      vfs:host
             select_entry:""
        loadPreviousState:true
                    async:true];
        });
    });
}

- (void) goToPersistentLocation:(const PersistentLocation &)_location
{
    m_DirectoryLoadingQ.Run([=]{
        VFSHostPtr host;
        if( PanelDataPersisency::CreateVFSFromLocation(_location, host) == VFSError::Ok ) {
            string path = _location.path;
            dispatch_to_main_queue([=]{
                auto context = make_shared<DirectoryChangeRequest>();
                context->VFS = host;
                context->PerformAsynchronous = true;
                context->RequestedDirectory = path;
                [self GoToDirWithContext:context];
            });
        }
    });
}

- (int) GoToDir:(const string&)_dir
            vfs:(VFSHostPtr)_vfs
   select_entry:(const string&)_filename
          async:(bool)_asynchronous
{
    return [self GoToDir:_dir
                     vfs:_vfs
            select_entry:_filename
       loadPreviousState:false
                   async:_asynchronous];
}

- (int) GoToDir:(const string&)_dir
            vfs:(VFSHostPtr)_vfs
   select_entry:(const string&)_filename
loadPreviousState:(bool)_load_state
          async:(bool)_asynchronous
{
    auto c = make_shared<DirectoryChangeRequest>();
    c->RequestedDirectory = _dir;
    c->VFS = _vfs;
    c->RequestFocusedEntry = _filename;
    c->LoadPreviousViewState = _load_state;
    c->PerformAsynchronous = _asynchronous;
    
    return [self GoToDirWithContext:c];
}

- (int) GoToDirWithContext:(shared_ptr<DirectoryChangeRequest>)_context
{
    auto &c = _context;
    if(c->RequestedDirectory.empty() ||
       c->RequestedDirectory.front() != '/' ||
       !c->VFS)
        return VFSError::InvalidCall;
    
    if(c->PerformAsynchronous == false) {
        assert(dispatch_is_main_queue());
        m_DirectoryLoadingQ.Stop();
        m_DirectoryLoadingQ.Wait();
    }
    else {
        if(!m_DirectoryLoadingQ.Empty())
            return 0;
    }
    
    auto workblock = [=]() {
        try {
            shared_ptr<VFSListing> listing;
            c->LoadingResultCode = c->VFS->FetchDirectoryListing(
                c->RequestedDirectory.c_str(),
                listing,
                m_VFSFetchingFlags,
                [&] { return m_DirectoryLoadingQ.IsStopped(); });
            if( c->LoadingResultCallback )
                c->LoadingResultCallback( c->LoadingResultCode );
            
            if( c->LoadingResultCode < 0 )
                return;
            // TODO: need an ability to show errors at least
            
            [self CancelBackgroundOperations]; // clean running operations if any
            dispatch_or_run_in_main_queue([=]{
                [m_View SavePathState];
                m_Data.Load(listing, data::Model::PanelType::Directory);
                [m_View dataUpdated];
                [m_View panelChangedWithFocusedFilename:c->RequestFocusedEntry
                                      loadPreviousState:c->LoadPreviousViewState];
                [self OnPathChanged];
            });
        }
        catch(exception &e) {
            ShowExceptionAlert(e.what());
        }
        catch(...){
            ShowExceptionAlert();
        }
    };
    
    if( c->PerformAsynchronous == false ) {
        workblock();
        return c->LoadingResultCode;
    }
    else {
        m_DirectoryLoadingQ.Run(workblock);
        return 0;
    }
}

- (void) loadNonUniformListing:(const shared_ptr<VFSListing>&)_listing
{
    [self CancelBackgroundOperations]; // clean running operations if any
    dispatch_or_run_in_main_queue([=]{
        [m_View SavePathState];
        m_Data.Load(_listing, data::Model::PanelType::Temporary);
        [m_View dataUpdated];
        [m_View panelChangedWithFocusedFilename:"" loadPreviousState:false];
        [self OnPathChanged];
    });
}

- (void) RecoverFromInvalidDirectory
{
    path initial_path = self.currentDirectoryPath;
    auto initial_vfs = self.vfs;
//    m_DirectoryLoadingQ->Run([=](const SerialQueue &_que) {
    m_DirectoryLoadingQ.Run([=]{
        // 1st - try to locate a valid dir in current host
        path path = initial_path;
        auto vfs = initial_vfs;
        
        while(true)
        {
            if(vfs->IterateDirectoryListing(path.c_str(), [](const VFSDirEnt &_dirent) {
                    return false;
                }) >= 0) {
                dispatch_to_main_queue([=]{
                    [self GoToDir:path.native()
                              vfs:vfs
                     select_entry:""
                            async:true];
                });
                break;
            }
            
            if(path == "/")
                break;
            
            if(path.filename() == ".") path.remove_filename();
            path = path.parent_path();
        }
        
        // we can't work on this vfs. currently for simplicity - just go home
        dispatch_to_main_queue([=]{
            [self GoToDir:CommonPaths::Home()
                      vfs:VFSNativeHost::SharedHost()
             select_entry:""
                    async:true];
        });
    });
}

- (void) ScheduleDelayedSelectionChangeFor:(DelayedSelection)request;
{
    assert(dispatch_is_main_queue()); // to preserve against fancy threading stuff
    // we assume that _item_name will not contain any forward slashes
    
    if(request.filename.empty())
        return;
    
    m_DelayedSelection.request_end = machtime() + request.timeout;
    m_DelayedSelection.filename = request.filename;
    m_DelayedSelection.done = request.done;
    
    if(request.check_now)
        [self CheckAgainstRequestedSelection];
}

- (bool) CheckAgainstRequestedSelection
{
    assert(dispatch_is_main_queue()); // to preserve against fancy threading stuff
    if(m_DelayedSelection.filename.empty())
        return false;
    
    if(machtime() > m_DelayedSelection.request_end) {
        m_DelayedSelection.filename.clear();
        m_DelayedSelection.done = nullptr;
        return false;
    }
    
    // now try to find it
    int entryindex = m_Data.RawIndexForName(m_DelayedSelection.filename.c_str());
    if( entryindex >= 0 )
    {
        // we found this entry. regardless of appearance of this entry in current directory presentation
        // there's no reason to search for it again
        auto done = m_DelayedSelection.done;
        m_DelayedSelection.done = nullptr;
        
        int sortpos = m_Data.SortedIndexForRawIndex(entryindex);
        if( sortpos >= 0 )
        {
            m_View.curpos = sortpos;
            if(!self.isActive)
                [(MainWindowFilePanelState*)self.state ActivatePanelByController:self];
            if(done)
                done();
            return true;
        }
    }
    return false;
}

- (void) ClearSelectionRequest
{
    m_DelayedSelection.filename.clear();
    m_DelayedSelection.done = nullptr;
}

- (IBAction)OnBriefSystemOverviewCommand:(id)sender
{
    if( m_BriefSystemOverview ) {
        [self.state CloseOverlay:self];
        m_BriefSystemOverview = nil;
        return;
    }
    
    m_BriefSystemOverview = [self.state RequestBriefSystemOverview:self];
    if( m_BriefSystemOverview )
        [self UpdateBriefSystemOverview];
}

- (IBAction)OnFileViewCommand:(id)sender
{
    // Close quick preview, if it is open.
    if( m_QuickLook ) {
        [self.state CloseOverlay:self];
        m_QuickLook = nil;
        return;
    }
    
    m_QuickLook = [self.state RequestQuickLookView:self];
    if( m_QuickLook )
        [self OnCursorChanged];
}

static const nanoseconds g_FastSeachDelayTresh = 4s;

static bool IsQuickSearchModifier(NSUInteger _modif, PanelQuickSearchMode::KeyModif _mode)
{
    // exclude CapsLock from our decision process
    _modif &= ~NSAlphaShiftKeyMask;
    
    switch (_mode) {
        case PanelQuickSearchMode::WithAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == NSAlternateKeyMask ||
            (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSShiftKeyMask);
        case PanelQuickSearchMode::WithCtrlAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSControlKeyMask) ||
            (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSControlKeyMask|NSShiftKeyMask);
        case PanelQuickSearchMode::WithShiftAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSShiftKeyMask);
        case PanelQuickSearchMode::WithoutModif:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == 0 ||
            (_modif&NSDeviceIndependentModifierFlagsMask) == NSShiftKeyMask ;
        default:
            break;
    }
    return false;
}

static bool IsQuickSearchModifierForArrows(NSUInteger _modif, PanelQuickSearchMode::KeyModif _mode)
{
    // exclude CapsLock from our decision process
    _modif &= ~NSAlphaShiftKeyMask;
    
    // arrow keydowns have NSNumericPadKeyMask and NSFunctionKeyMask flag raised
    if((_modif & NSNumericPadKeyMask) == 0) return false;
    if((_modif & NSFunctionKeyMask) == 0) return false;
    _modif &= ~NSNumericPadKeyMask;
    _modif &= ~NSFunctionKeyMask;
    
    switch (_mode) {
        case PanelQuickSearchMode::WithAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == NSAlternateKeyMask ||
            (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSShiftKeyMask);
        case PanelQuickSearchMode::WithCtrlAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSControlKeyMask) ||
            (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSControlKeyMask|NSShiftKeyMask);
        case PanelQuickSearchMode::WithShiftAlt:
            return (_modif&NSDeviceIndependentModifierFlagsMask) == (NSAlternateKeyMask|NSShiftKeyMask);
        default:
            break;
    }
    return false;
}

static bool IsQuickSearchStringCharacter(NSString *_s)
{
    static NSCharacterSet *chars;
    static once_flag once;
    call_once(once, []{
        NSMutableCharacterSet *un = [NSMutableCharacterSet new];
        [un formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
        [un removeCharactersInString:@"/"]; // such character simply can't appear in filename under unix
        chars = un;
    });
    
    if(_s.length == 0)
        return false;
    
    unichar u = [_s characterAtIndex:0]; // consider uing UTF-32 here
    return [chars characterIsMember:u];
}

static inline bool IsBackspace(NSString *_s)
{
    return _s.length == 1 && [_s characterAtIndex:0] == 0x7F;
}

static inline bool IsSpace(NSString *_s)
{
    return _s.length == 1 && [_s characterAtIndex:0] == 0x20;
}

static NSString *RemoveLastCharacterWithNormalization(NSString *_s)
{
    // remove last symbol. since strings are decomposed (as for file system interaction),
    // it should be composed first and decomposed back after altering
    assert(_s != nil);
    assert(_s.length > 0);
    NSString *s = _s.precomposedStringWithCanonicalMapping;
    s = [s substringToIndex:s.length-1];
    return s.decomposedStringWithCanonicalMapping;
}

static NSString *ModifyStringByKeyDownString(NSString *_str, NSString *_key)
{
    if( !_key )
        return _str;
    
    if( !IsBackspace(_key) )
        _str = _str ? [_str stringByAppendingString:_key] : _key;
    else
        _str = _str.length > 0 ? RemoveLastCharacterWithNormalization(_str) : nil;
    
    return _str;
}

- (void) QuickSearchClearFiltering
{
    if(m_View == nil)
        return;
    
    GenericCursorPersistance pers(m_View, m_Data);
    
    bool any_changed = m_Data.ClearTextFiltering();
    
    [m_View setQuickSearchPrompt:nil withMatchesCount:0];
    
    if( any_changed ) {
        [m_View dataUpdated];
        pers.Restore();
    }
}

- (bool)HandleQuickSearchSoft: (NSString*) _key
{
    nanoseconds currenttime = machtime();

    // update soft filtering
    NSString *text = m_Data.SoftFiltering().text;
    if( m_QuickSearchLastType + g_FastSeachDelayTresh < currenttime )
        text = nil;
    
    text = ModifyStringByKeyDownString(text, _key);
    if( !text  )
        return false;
    
    if( text.length == 0 ) {
        [self QuickSearchClearFiltering];
        return true;
    }
    
    [self SetQuickSearchSoft:text];

    return true;
}

- (void)SetQuickSearchSoft:(NSString*) _text
{
    if( !_text )
        return;
    
    nanoseconds currenttime = machtime();
    
    // update soft filtering
    auto filtering = m_Data.SoftFiltering();
    if( m_QuickSearchLastType + g_FastSeachDelayTresh < currenttime )
        m_QuickSearchOffset = 0;
    
    filtering.text = _text;
    filtering.type = m_QuickSearchWhere;
    filtering.ignore_dot_dot = false;
    filtering.hightlight_results = m_QuickSearchTypingView;
    m_Data.SetSoftFiltering(filtering);
    
    m_QuickSearchLastType = currenttime;
    
    if( !m_Data.EntriesBySoftFiltering().empty() ) {
        if(m_QuickSearchOffset >= m_Data.EntriesBySoftFiltering().size())
            m_QuickSearchOffset = (unsigned)m_Data.EntriesBySoftFiltering().size() - 1;
        m_View.curpos = m_Data.EntriesBySoftFiltering()[m_QuickSearchOffset];
    }
    
    if( m_QuickSearchTypingView ) {
        int total = (int)m_Data.EntriesBySoftFiltering().size();
        [m_View setQuickSearchPrompt:m_Data.SoftFiltering().text withMatchesCount:total];
        //        m_View.quickSearchPrompt = PromptForMatchesAndString(total, m_Data.SoftFiltering().text);
        
        // automatically remove prompt after g_FastSeachDelayTresh
        __weak PanelController *wself = self;
        dispatch_to_main_queue_after(g_FastSeachDelayTresh + 1000ns, [=]{
            if(PanelController *sself = wself)
                if( sself->m_QuickSearchLastType + g_FastSeachDelayTresh <= machtime() )
                    [sself QuickSearchClearFiltering];
        });
        
        [m_View volatileDataChanged];
    }
}

- (void)QuickSearchHardUpdateTypingUI
{
    if(!m_QuickSearchTypingView)
        return;
    
    auto filtering = m_Data.HardFiltering();
    if(!filtering.text.text) {
        [m_View setQuickSearchPrompt:nil withMatchesCount:0];
//        m_View.quickSearchPrompt = nil;
    }
    else {
        int total = (int)m_Data.SortedDirectoryEntries().size();
        if(total > 0 && m_Data.Listing().IsDotDot(0))
            total--;
//        m_View.quickSearchPrompt = PromptForMatchesAndString(total, filtering.text.text);
        [m_View setQuickSearchPrompt:filtering.text.text withMatchesCount:total];
    }
}

- (bool)HandleQuickSearchHard:(NSString*) _key
{
    NSString *text = m_Data.HardFiltering().text.text;
    
    text = ModifyStringByKeyDownString(text, _key);
    if( text == nil )
        return false;

    if( text.length == 0 ) {
        [self QuickSearchClearFiltering];
        return true;
    }

    [self SetQuickSearchHard:text];
    
    return true;
}

- (void)SetQuickSearchHard:(NSString*)_text
{
    auto filtering = m_Data.HardFiltering();
    filtering.text.text = _text;
    if( filtering.text.text == nil )
        return;
    
    GenericCursorPersistance pers(m_View, m_Data);
    
    filtering.text.type = m_QuickSearchWhere;
    filtering.text.clear_on_new_listing = true;
    filtering.text.hightlight_results = m_QuickSearchTypingView;
    m_Data.SetHardFiltering(filtering);
    
    pers.Restore();
    
    [m_View dataUpdated];
    [self QuickSearchHardUpdateTypingUI];
    
    // for convinience - if we have ".." and cursor is on it - move it to first element (if any)
    if((m_VFSFetchingFlags & VFSFlags::F_NoDotDot) == 0 &&
       m_View.curpos == 0 &&
       m_Data.SortedDirectoryEntries().size() >= 2 &&
       m_Data.EntryAtRawPosition(m_Data.SortedDirectoryEntries()[0]).IsDotDot() )
        m_View.curpos = 1;
    
}

- (void) QuickSearchSetCriteria:(NSString *)_text
{
    if( m_QuickSearchIsSoftFiltering )
        [self SetQuickSearchSoft:_text];
    else
        [self SetQuickSearchHard:_text];
}

- (void)QuickSearchPrevious
{
    if(m_QuickSearchOffset > 0)
        m_QuickSearchOffset--;
    [self HandleQuickSearchSoft:nil];
}

- (void)QuickSearchNext
{
    m_QuickSearchOffset++;
    [self HandleQuickSearchSoft:nil];
}

- (bool) QuickSearchProcessKeyDown:(NSEvent *)event
{
    NSString*  const character   = [event charactersIgnoringModifiers];
    NSUInteger const modif       = [event modifierFlags];
    
    bool empty_text = m_QuickSearchIsSoftFiltering ?
        m_Data.SoftFiltering().text.length == 0 :
        m_Data.HardFiltering().text.text.length == 0;
    
    if( IsQuickSearchModifier(modif, m_QuickSearchMode) &&
        ( IsQuickSearchStringCharacter(character) ||
            ( !empty_text && IsSpace(character) ) ||
            IsBackspace(character)
         )
       ) {
        if(m_QuickSearchIsSoftFiltering)
            return [self HandleQuickSearchSoft:character.decomposedStringWithCanonicalMapping];
        else
            return [self HandleQuickSearchHard:character.decomposedStringWithCanonicalMapping];
    }
    else if( character.length == 1 )
        switch([character characterAtIndex:0]) {
            case NSUpArrowFunctionKey:
                if( IsQuickSearchModifierForArrows(modif, m_QuickSearchMode) ) {
                    [self QuickSearchPrevious];
                    return true;
                }
            case NSDownArrowFunctionKey:
                if( IsQuickSearchModifierForArrows(modif, m_QuickSearchMode) ) {
                    [self QuickSearchNext];
                    return true;
                }
        }
    
    return false;
}

- (void) QuickSearchUpdate
{
    if(!m_QuickSearchIsSoftFiltering)
        [self QuickSearchHardUpdateTypingUI];
}


@end
