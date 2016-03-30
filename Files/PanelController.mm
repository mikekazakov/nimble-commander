//
//  PanelController.m
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/algo.h>
#include <Utility/NSView+Sugar.h>
#include <Utility/NSMenu+Hierarchical.h>
#include "Operations/Copy/FileCopyOperation.h"
#include "PanelController.h"
#include "MainWindowController.h"
#include "QuickPreview.h"
#include "MainWindowFilePanelState.h"
#include "PanelAux.h"
#include "SharingService.h"
#include "BriefSystemOverview.h"
#include "ActionsShortcutsManager.h"
#include "SandboxManager.h"
#include "ExtensionLowercaseComparison.h"
#include "Config.h"
#include "PanelDataPersistency.h"
#include "AskForPasswordWindowController.h"
#include "ActivationManager.h"

static const auto g_ConfigArchivesExtensionsWhieList            = "filePanel.general.archivesExtensionsWhitelist";
static const auto g_ConfigShowDotDotEntry                       = "filePanel.general.showDotDotEntry";
static const auto g_ConfigIgnoreDirectoriesOnMaskSelection      = "filePanel.general.ignoreDirectoriesOnSelectionWithMask";
static const auto g_ConfigUseTildeAsHomeShortcut                = "filePanel.general.useTildeAsHomeShortcut";
static const auto g_ConfigShowLocalizedFilenames                = "filePanel.general.showLocalizedFilenames";
static const auto g_ConfigRouteKeyboardInputIntoTerminal        = "filePanel.general.routeKeyboardInputIntoTerminal";
static const auto g_ConfigQuickSearchWhereToFind                = "filePanel.quickSearch.whereToFind";
static const auto g_ConfigQuickSearchSoftFiltering              = "filePanel.quickSearch.softFiltering";
static const auto g_ConfigQuickSearchTypingView                 = "filePanel.quickSearch.typingView";
static const auto g_ConfigQuickSearchKeyOption                  = "filePanel.quickSearch.keyOption";

static const auto g_RestorationDataKey = "data";
static const auto g_RestorationSortingKey = "sorting";
static const auto g_RestorationViewKey = "view";

panel::GenericCursorPersistance::GenericCursorPersistance(PanelView* _view, const PanelData &_data):
    m_View(_view),
    m_Data(_data)
{
    auto cur_pos = _view.curpos;
    if(cur_pos >= 0 && m_View.item ) {
        m_OldCursorName = m_View.item.Name();
        m_OldEntrySortKeys = _data.EntrySortKeysAtSortPosition(cur_pos);
    }
}

void panel::GenericCursorPersistance::Restore() const
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
    [m_View setNeedsDisplay];
}

static bool IsItemInArchivesWhitelist( const VFSListingItem &_item ) noexcept
{
    static const vector<string> archive_extensions = []{
        vector<string> v;
        if( auto exts_string = GlobalConfig().GetString(g_ConfigArchivesExtensionsWhieList) ) {
            // load extensions list from defaults
            if( auto extensions_array = [[NSString stringWithUTF8StdString:*exts_string] componentsSeparatedByString:@","] )
                for( NSString *s: extensions_array )
                    if( s != nil && s.length > 0 )
                        if( auto trimmed = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] )
                            if( auto utf8 = trimmed.UTF8String)
                                v.emplace_back( ExtensionLowercaseComparison::Instance().ExtensionToLowercase(utf8) );
        }
        else // hardcoded fallback data
            v = { "zip", "tar", "pax", "cpio", "xar", "lha", "ar", "cab", "mtree", "iso", "bz2", "gz", "bzip2", "gzip", "7z", "rar" };
        return v;
    }();
    
    if( _item.IsDir() )
        return false;

    if( !_item.HasExtension() )
        return false;
    
    const auto extension = ExtensionLowercaseComparison::Instance().ExtensionToLowercase( _item.Extension() );
    return any_of(begin(archive_extensions), end(archive_extensions), [&](auto &_) { return extension == _; } );
}

@implementation PanelController
@synthesize view = m_View;
@synthesize data = m_Data;
@synthesize lastNativeDirectoryPath = m_LastNativeDirectory;
@synthesize history = m_History;

- (id) init
{
    self = [super init];
    if(self) {
        m_QuickSearchLastType = 0ns;
        m_QuickSearchOffset = 0;
        m_VFSFetchingFlags = 0;
        m_IsAnythingWorksInBackground = false;
        m_DirectorySizeCountingQ = SerialQueueT::Make(ActivationManager::BundleID() + ".paneldirsizecounting");
        m_DirectoryLoadingQ = SerialQueueT::Make(ActivationManager::BundleID() + ".paneldirloading");
        m_DirectoryReLoadingQ = SerialQueueT::Make(ActivationManager::BundleID() + ".paneldirreloading");
        m_DragDrop.last_valid_items = -1;
        
        __weak PanelController* weakself = self;
        auto on_change = ^{
            dispatch_to_main_queue([=]{
                [(PanelController*)weakself UpdateSpinningIndicator];
            });
        };
        m_DirectorySizeCountingQ->OnChange(on_change);
        m_DirectoryReLoadingQ->OnChange(on_change);
        m_DirectoryLoadingQ->OnChange(on_change);
        
        m_View = [[PanelView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        m_View.delegate = self;
        m_View.data = &m_Data;
        [self RegisterDragAndDropListeners];
        
        // wire up config changing notifications
        __weak PanelController *weak_self = self;
        auto add_observer = [&](const char *_path, function<void()> _cb) { m_ConfigObservers.emplace_back( GlobalConfig().Observe(_path, move(_cb)) ); };
        add_observer(g_ConfigShowDotDotEntry,           [=]{ [(PanelController *)weak_self configVFSFetchFlagsChanged]; });
        add_observer(g_ConfigShowLocalizedFilenames,    [=]{ [(PanelController *)weak_self configVFSFetchFlagsChanged]; });
        add_observer(g_ConfigQuickSearchWhereToFind,    [=]{ [(PanelController *)weak_self configQuickSearchSettingsChanged]; });
        add_observer(g_ConfigQuickSearchSoftFiltering,  [=]{ [(PanelController *)weak_self configQuickSearchSettingsChanged]; });
        add_observer(g_ConfigQuickSearchTypingView,     [=]{ [(PanelController *)weak_self configQuickSearchSettingsChanged]; });
        add_observer(g_ConfigQuickSearchKeyOption,      [=]{ [(PanelController *)weak_self configQuickSearchSettingsChanged]; });
        
        // loading config via simulating it's change
        [self configVFSFetchFlagsChanged];
        [self configQuickSearchSettingsChanged];
    }

    return self;
}

- (void)configVFSFetchFlagsChanged
{
    if( GlobalConfig().GetBool(g_ConfigShowDotDotEntry) == false )
        m_VFSFetchingFlags |= VFSFlags::F_NoDotDot;
    else
        m_VFSFetchingFlags &= ~VFSFlags::F_NoDotDot;
    
    if( GlobalConfig().GetBool(g_ConfigShowLocalizedFilenames) == true )
        m_VFSFetchingFlags |= VFSFlags::F_LoadDisplayNames;
    else
        m_VFSFetchingFlags &= ~VFSFlags::F_LoadDisplayNames;
    
    [self RefreshDirectory];
}

- (void)configQuickSearchSettingsChanged
{
    m_QuickSearchWhere = PanelDataTextFiltering::WhereFromInt( GlobalConfig().GetInt(g_ConfigQuickSearchWhereToFind) );
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
    
    [self.view loadRestorableState:_pc.view.encodeRestorableState];
    self.data.DecodeSortingOptions( _pc.data.EncodeSortingOptions() );
}

- (bool) isActive
{
    return m_View.active;
}

- (void) handleOpenInSystem
{
    // may go async here on non-native VFS
    // non-default behaviour here: "/Abra/.." will produce "/Abra/" insted of default-way "/"    
    if( auto item = m_View.item )
        PanelVFSFileWorkspaceOpener::Open(item.IsDotDot() ? item.Directory() : item.Path(),
                                          item.Host());
}

- (void) ChangeSortingModeTo:(PanelSortMode)_mode
{
    panel::GenericCursorPersistance pers(m_View, m_Data);
    
    m_Data.SetSortMode(_mode);

    pers.Restore();
}

- (void) ChangeHardFilteringTo:(PanelDataHardFiltering)_filter
{
    panel::GenericCursorPersistance pers(m_View, m_Data);
    
    m_Data.SetHardFiltering(_filter);
    
    pers.Restore();
}

- (void) MakeSortWith:(PanelSortMode::Mode)_direct Rev:(PanelSortMode::Mode)_rev
{
    PanelSortMode mode = m_Data.SortMode(); // we don't want to change anything in sort params except the mode itself
    mode.sort = mode.sort != _direct ? _direct : _rev;
    [self ChangeSortingModeTo:mode];
    [self markRestorableStateAsInvalid];
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
    else if( ActivationManager::Instance().HasArchivesBrowsing() ) {
        if( !_whitelist_archive_only || IsItemInArchivesWhitelist(entry) ) {
            auto pwd_ask = [=]{ string p; return RunAskForPasswordModalWindow(entry.Filename(), p) ? p : ""; };
            if( auto arhost = VFSArchiveProxy::OpenFileAsArchive(entry.Path(), entry.Host(), pwd_ask) )
                return [self GoToDir:"/" vfs:arhost select_entry:"" async:true] == 0;
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
        panel::IsEligbleToTryToExecuteInConsole(entry) ) {
        [self.state requestTerminalExecution:entry.Name() at:entry.Directory()];
        return;
    }
    
    // If previous code didn't handle current item,
    // open item with the default associated application.
    [self handleOpenInSystem];
}

- (void) ReLoadRefreshedListing:(const VFSListingPtr &)_ptr
{
    assert(dispatch_is_main_queue());
    
    panel::GenericCursorPersistance pers(m_View, m_Data);
    
    m_Data.ReLoad(_ptr);
    [m_View dataUpdated];
    
    if(![self CheckAgainstRequestedSelection])
        pers.Restore();
    
    [self OnCursorChanged];
    [self QuickSearchUpdate];
    [m_View setNeedsDisplay];
}

- (void) RefreshDirectory
{
    if(m_View == nil)
        return; // guard agains calls from init process
    if( m_Data.Listing().shared_from_this() == VFSListing::EmptyListing() )
        return; // guard agains calls from init process
    
    // going async here
    if(!m_DirectoryLoadingQ->Empty())
        return; //reducing overhead

    // later: maybe check PanelType somehow
    
    if( self.isUniform ) {
        string dirpath = m_Data.DirectoryPathWithTrailingSlash();
        auto vfs = self.vfs;
        m_DirectoryReLoadingQ->Run([=](const SerialQueue &_q){
            VFSListingPtr listing;
            int ret = vfs->FetchFlexibleListing(dirpath.c_str(), listing, m_VFSFetchingFlags, [&]{ return _q->IsStopped(); });
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
        m_DirectoryReLoadingQ->Run([=](const SerialQueue &_q){
            auto listing = VFSListing::ProduceUpdatedTemporaryPanelListing( m_Data.Listing(), [&]{ return _q->IsStopped(); } );
            if( listing )
                dispatch_to_main_queue( [=]{
                    [self ReLoadRefreshedListing:listing];
                });
        });
    }
}

- (bool) PanelViewProcessKeyDown:(PanelView*)_view event:(NSEvent *)event
{
    [self ClearSelectionRequest]; // on any key press we clear entry selection request if any
 
    const bool route_to_overlapped_terminal = GlobalConfig().GetBool( g_ConfigRouteKeyboardInputIntoTerminal );
    const bool terminal_can_eat = route_to_overlapped_terminal && [self.state overlappedTerminalWillEatKeyDown:event];
    
    NSString*  const character   = event.charactersIgnoringModifiers;
    if ( character.length > 0 ) {
        NSUInteger const modif       = event.modifierFlags;
        unichar const unicode        = [character characterAtIndex:0];
        unsigned short const keycode = event.keyCode;
        
//        if(keycode == 3 ) { // 'F' button
//            if( (modif&NSDeviceIndependentModifierFlagsMask) == (NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) {
////                [self testNonUniformListing];
//                
////                auto host = make_shared<VFSXAttrHost>( self.view.item.Path(), self.view.item.Host() );
////
////                auto context = make_shared<PanelControllerGoToDirContext>();
////                context->VFS = host;
////                context->RequestedDirectory = "/";
////                
////                [self GoToDirWithContext:context];
//                return true;
//            }
//        }
        
        if(unicode == NSTabCharacter) { // Tab button
            [self.state HandleTabButton];
            return true;
        }
        if(unicode == 0x20 &&
           !terminal_can_eat) { // Space button
            [self OnFileViewCommand:self];
            return true;
        }
        if(keycode == 53) { // Esc button
            [self CancelBackgroundOperations];
            [self.state CloseOverlay:self];
            m_BriefSystemOverview = nil;
            m_QuickLook = nil;
            [self QuickSearchClearFiltering];
            return true;
        }
        if( unicode == '~' &&
           (modif & (NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) == 0 &&
            GlobalConfig().GetBool(g_ConfigUseTildeAsHomeShortcut) &&
           !terminal_can_eat) { // Tilde to go Home
            static auto tag = ActionsShortcutsManager::Instance().TagFromAction("menu.go.home");
            [[NSApp menu] performActionForItemWithTagHierarchical:tag];
            return true;
        }
        if( unicode == '/' &&
           (modif & (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask)) == 0 &&
           !terminal_can_eat) {
            static auto tag = ActionsShortcutsManager::Instance().TagFromAction("menu.go.root");
            [[NSApp menu] performActionForItemWithTagHierarchical:tag];
            return true;
        }
        
        // handle some actions manually, to prevent annoying by menu highlighting by hotkey
        auto &shortcuts = ActionsShortcutsManager::Instance();
        if(shortcuts.ShortCutFromAction("menu.file.open")->IsKeyDown(unicode, keycode, modif)) {
            [self handleGoIntoDirOrOpenInSystemSync];
            return true;
        }
        if(shortcuts.ShortCutFromAction("menu.file.open_native")->IsKeyDown(unicode, keycode, modif)) {
            [self handleOpenInSystem];
            return true;
        }
        
        // try to process this keypress with QuickSearch
        if([self QuickSearchProcessKeyDown:event])
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

- (void) CalculateSizes:(const vector<VFSListingItem>&) _items
{
    m_DirectorySizeCountingQ->Run([=](const SerialQueue &_q){
        for(auto &i:_items) {
            if( _q->IsStopped() )
                return;
            auto result = i.Host()->CalculateDirectorySize(!i.IsDotDot() ? i.Path().c_str() : i.Directory().c_str(),
                                                           [=]{ return _q->IsStopped(); }
                                                           );
            if( result >= 0 )
                dispatch_to_main_queue([=]{
                    panel::GenericCursorPersistance pers(m_View, m_Data);
                    // may cause re-sorting if current sorting is by size
                    if( m_Data.SetCalculatedSizeForDirectory(i.Name(), i.Directory().c_str(), result) ) {
                        [m_View setNeedsDisplay];
                        pers.Restore();
                    }
                });
        }
    });
}

- (void) ModifierFlagsChanged:(unsigned long)_flags // to know if shift or something else is pressed
{
    [m_View modifierFlagsChanged:_flags];

    if(m_QuickSearchIsSoftFiltering)
        [self QuickSearchClearFiltering];
}

- (void) AttachToControls:(NSProgressIndicator*)_indicator share:(NSButton*)_share
{
    m_SpinningIndicator = _indicator;
    m_ShareButton = _share;
    
    m_IsAnythingWorksInBackground = false;
    [m_SpinningIndicator stopAnimation:nil];
    [self UpdateSpinningIndicator];
    
    m_ShareButton.target = self;
    m_ShareButton.action = @selector(OnShareButton:);
}

- (void) CancelBackgroundOperations
{
    m_DirectorySizeCountingQ->Stop();
    m_DirectoryLoadingQ->Stop();
    m_DirectoryReLoadingQ->Stop();    
}

- (void) UpdateSpinningIndicator
{
    bool is_anything_working = !m_DirectorySizeCountingQ->Empty() || !m_DirectoryLoadingQ->Empty() || !m_DirectoryReLoadingQ->Empty();
    
    if(is_anything_working == m_IsAnythingWorksInBackground)
        return; // nothing to update;
        
    if(is_anything_working)
    {
        dispatch_to_main_queue_after(100ms, [=]{ // in 100 ms of workload should be before user will get spinning indicator
                           if(m_IsAnythingWorksInBackground) // need to check if task was already done
                           {
                               [m_SpinningIndicator startAnimation:nil];
                               if(m_SpinningIndicator.isHidden)
                                   m_SpinningIndicator.hidden = false;
                           }
                       });
    }
    else
    {
        [m_SpinningIndicator stopAnimation:nil];
        if(!m_SpinningIndicator.isHidden)
            m_SpinningIndicator.hidden = true;
        
    }
    
    m_IsAnythingWorksInBackground = is_anything_working;
}

- (void) SelectAllEntries:(bool) _select
{
    m_Data.CustomFlagsSelectAllSorted(_select);
    [m_View setNeedsDisplay];
}

- (void) invertSelection
{
    m_Data.CustomFlagsSelectInvert();
    [m_View setNeedsDisplay];
}

- (void) OnPathChanged
{
    // update directory changes notification ticket
    __weak PanelController *weakself = self;
    m_UpdatesObservationTicket.reset();    
    if( self.isUniform )
        m_UpdatesObservationTicket = self.vfs->DirChangeObserve(self.currentDirectoryPath.c_str(), [=]{
            dispatch_to_main_queue([=]{
                [(PanelController *)weakself RefreshDirectory];
            });
        });
    
    [self ClearSelectionRequest];
    [self QuickSearchClearFiltering];
    [self.state PanelPathChanged:self];
    [self OnCursorChanged];
    [self UpdateBriefSystemOverview];

    if( self.isUniform  ) {
        m_History.Put( VFSPathStack(self.vfs, self.currentDirectoryPath) );
        if( self.vfs->IsNativeFS() )
            m_LastNativeDirectory = self.currentDirectoryPath;
    }
    
    [self markRestorableStateAsInvalid];
}

- (void) markRestorableStateAsInvalid
{
    if( auto wc = objc_cast<MainWindowController>(self.state.window.delegate) )
        [wc invalidateRestorableState];
}

- (void) OnCursorChanged
{
    // need to update some UI here  
    // update share button regaring current state
    m_ShareButton.enabled = m_Data.Stats().selected_entries_amount > 0 ||
                            [SharingService SharingEnabledForItem:m_View.item];
    
    // update QuickLook if any
    if( auto i = self.view.item )
        [(QuickLookView *)m_QuickLook PreviewItem:i.Path() vfs:i.Host()];
}

- (void)OnShareButton:(id)sender
{
    if(SharingService.IsCurrentlySharing)
        return;
    
    auto files = self.selectedEntriesOrFocusedEntryFilenames;
    if(files.empty())
        return;
    
    [[SharingService new] ShowItems:files
                              InDir:self.currentDirectoryPath
                              InVFS:self.vfs
                     RelativeToRect:[sender bounds]
                             OfView:sender
                      PreferredEdge:NSMinYEdge];
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

- (NSMenu*) PanelViewRequestsContextMenu:(PanelView*)_view
{
    return [self.state RequestContextMenuOn:self.selectedEntriesOrFocusedEntry caller:self];
}

- (void) PanelViewDoubleClick:(PanelView*)_view atElement:(int)_sort_pos
{
    [self handleGoIntoDirOrOpenInSystemSync];
}

- (bool) PanelViewWantsRenameFieldEditor:(PanelView*)_view
{
    if( !_view.item ||
       _view.item.IsDotDot() ||
       !_view.item.Host()->IsWriteable())
        return false;
    return true;
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
       !m_View.item.Host()->IsWriteable() ||
       [_filename isEqualToString:m_View.item.NSName()])
        return;
    
    string target_fn = _filename.fileSystemRepresentationSafe;
    auto item = m_View.item;
    
 
    // checking for invalid symbols
    if( !item.Host()->ValidateFilename(target_fn.c_str()) ) {
        NSAlert *a = [[NSAlert alloc] init];
        a.messageText = [NSString stringWithFormat:NSLocalizedString(@"The name “%@” can’t be used.", "Message text when user is entering an invalid filename"),
                         _filename.length <= 256 ? _filename : [[_filename substringToIndex:256] stringByAppendingString:@"..."]
                         ];
        a.informativeText = NSLocalizedString(@"Try using a name with fewer characters, or with no punctuation marks.", "Informative text when user is entering an invalid filename");
        a.alertStyle = NSCriticalAlertStyle;
        [a runModal];
        return;
    }
    
    FileCopyOperationOptions opts;
    opts.docopy = false;

    FileCopyOperation *op = [FileCopyOperation singleItemRenameOperation:item newName:target_fn];

    if( self.isUniform ) {
        string curr_path = self.currentDirectoryPath;
        auto curr_vfs = self.vfs;
        [op AddOnFinishHandler:^{
            if(self.currentDirectoryPath == curr_path && self.vfs == curr_vfs)
                dispatch_to_main_queue( [=]{
                    PanelControllerDelayedSelection req;
                    req.filename = target_fn;
                    [self ScheduleDelayedSelectionChangeFor:req];
                    [self RefreshDirectory];
                } );
        }];
    }
    
    [self.state AddOperation:op];
}

- (void) PanelViewDidBecomeFirstResponder:(PanelView*)_view
{
    [self.state activePanelChangedTo:self];
    [self ModifierFlagsChanged:[NSEvent modifierFlags]];
}

- (void) SelectEntriesByMask:(NSString*)_mask select:(bool)_select
{
    if( m_Data.CustomFlagsSelectAllSortedByMask(_mask, _select, self.ignoreDirectoriesOnSelectionByMask) )
        [m_View setNeedsDisplay:true];
}

+ (bool) ensureCanGoToNativeFolderSync:(const string&)_path
{
    if( ActivationManager::Instance().Sandboxed() &&
        !SandboxManager::Instance().CanAccessFolder(_path) &&
        !SandboxManager::Instance().AskAccessForPathSync(_path) )
        return false;
    return true;
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
  
    json.AddMember( rapidjson::StandaloneValue(g_RestorationSortingKey, rapidjson::g_CrtAllocator), m_Data.EncodeSortingOptions(), rapidjson::g_CrtAllocator );
    json.AddMember( rapidjson::StandaloneValue(g_RestorationViewKey, rapidjson::g_CrtAllocator), [m_View encodeRestorableState], rapidjson::g_CrtAllocator );
    
    return move(json);
}

- (bool) loadRestorableState:(const rapidjson::StandaloneValue&)_state
{
    assert(dispatch_is_main_queue());
    if( _state.IsObject() ) {
        if( _state.HasMember(g_RestorationSortingKey) ) {
            panel::GenericCursorPersistance pers(m_View, m_Data);
            m_Data.DecodeSortingOptions( _state[g_RestorationSortingKey] );
            pers.Restore();
        }
        
        if( _state.HasMember(g_RestorationViewKey) )
            [m_View loadRestorableState:_state[g_RestorationViewKey]];
        
        if( _state.HasMember(g_RestorationDataKey) ) {
            auto data = make_shared<rapidjson::StandaloneValue>();
            data->CopyFrom(_state[g_RestorationDataKey], rapidjson::g_CrtAllocator);
            m_DirectoryLoadingQ->Run([=]{
                VFSHostPtr host;
                if( PanelDataPersisency::CreateVFSFromState(*data, host) == VFSError::Ok ) {
                    string path = PanelDataPersisency::GetPathFromState(*data);
                    dispatch_to_main_queue([=]{
                        auto context = make_shared<PanelControllerGoToDirContext>();
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

@end
