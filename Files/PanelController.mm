//
//  PanelController.m
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#import "PanelController.h"
#import "Common.h"
#import "MainWindowController.h"
#import "QuickPreview.h"
#import "MainWindowFilePanelState.h"
#import "FileMask.h"
#import "PanelAux.h"
#import "SharingService.h"
#import "BriefSystemOverview.h"
#import "ActionsShortcutsManager.h"
#import "FTPConnectionSheetController.h"
#import "SelectionWithMaskSheetController.h"
#import "DetailedVolumeInformationSheetController.h"
#import "FileSysEntryAttrSheetController.h"
#import "FindFilesSheetController.h"
#import "FileSysAttrChangeOperation.h"

static NSString *g_DefaultsQuickSearchKeyModifier   = @"FilePanelsQuickSearchKeyModifier";
static NSString *g_DefaultsQuickSearchSoftFiltering = @"FilePanelsQuickSearchSoftFiltering";
static NSString *g_DefaultsQuickSearchWhereToFind   = @"FilePanelsQuickSearchWhereToFind";
static NSString *g_DefaultsQuickSearchTypingView    = @"FilePanelsQuickSearchTypingView";
static NSString *g_DefaultsGeneralShowDotDotEntry       = @"FilePanelsGeneralShowDotDotEntry";
static NSString *g_DefaultsGeneralIgnoreDirsOnMaskSel   = @"FilePanelsGeneralIgnoreDirectoriesOnSelectionWithMask";

static NSArray *MyDefaultsKeys()
{
    return [NSArray arrayWithObjects:g_DefaultsQuickSearchKeyModifier,
            g_DefaultsQuickSearchSoftFiltering, g_DefaultsQuickSearchWhereToFind,
            g_DefaultsQuickSearchTypingView, g_DefaultsGeneralShowDotDotEntry,
            g_DefaultsGeneralIgnoreDirsOnMaskSel, nil];
};

static bool IsEligbleToTryToExecuteInConsole(const VFSListingItem& _item)
{
    // TODO: need more sophisticated executable handling here
    // THIS IS WRONG!
    bool uexec = (_item.UnixMode() & S_IXUSR) ||
                 (_item.UnixMode() & S_IXGRP) ||
                 (_item.UnixMode() & S_IXOTH) ;
    
    if(!uexec) return false;
    
    if(!_item.HasExtension())
        return true; // if file has no extension and had execute rights - let's try it
    
    const char *ext = _item.Extension();

    return  strcmp(ext, "sh") == 0 ||
            strcmp(ext, "pl") == 0 ||
            strcmp(ext, "rb") == 0 ||
            false; // need MOAR HERE!
}


panel::GenericCursorPersistance::GenericCursorPersistance(PanelView* _view, const PanelData &_data):
    view(_view),
    data(_data),
    oldcursorpos(_view.curpos)
{
    if(oldcursorpos >= 0 && view.item != nullptr)
        oldcursorname = view.item->Name();
}
    
void panel::GenericCursorPersistance::Restore()
{
    int newcursorrawpos = data.RawIndexForName(oldcursorname.c_str());
    if( newcursorrawpos >= 0 )
    {
        int newcursorsortpos = data.SortedIndexForRawIndex(newcursorrawpos);
        if(newcursorsortpos >= 0)
            view.curpos = newcursorsortpos;
        else
            view.curpos = data.SortedDirectoryEntries().empty() ? -1 : 0;
    }
    else
    {
        if( oldcursorpos < data.SortedDirectoryEntries().size() )
            view.curpos = oldcursorpos;
        else
            view.curpos = int(data.SortedDirectoryEntries().size()) - 1;
    }
}

@implementation PanelController
@synthesize view = m_View;
@synthesize data = m_Data;

- (id) init
{
    self = [super init];
    if(self) {
        m_UpdatesObservationTicket = 0;
        m_QuickSearchLastType = 0;
        m_QuickSearchOffset = 0;
        m_VFSFetchingFlags = 0;
        m_IsAnythingWorksInBackground = false;
        m_DirectorySizeCountingQ = make_shared<SerialQueueT>("info.filespamanager.paneldirsizecounting");
        m_DirectoryLoadingQ = make_shared<SerialQueueT>("info.filespamanager.paneldirsizecounting");
        m_DirectoryReLoadingQ = make_shared<SerialQueueT>("info.filespamanager.paneldirreloading");
        m_DelayedSelection.isvalid = false;
        
        __weak PanelController* weakself = self;
        auto on_change = ^{
            dispatch_to_main_queue( ^{
                [(PanelController*)weakself UpdateSpinningIndicator];
            });
        };
        m_DirectorySizeCountingQ->OnChange(on_change);
        m_DirectoryReLoadingQ->OnChange(on_change);
        m_DirectoryLoadingQ->OnChange(on_change);
        
        // loading defaults via simulating it's change
        [self observeValueForKeyPath:g_DefaultsQuickSearchKeyModifier ofObject:NSUserDefaults.standardUserDefaults change:nil context:nullptr];
        [self observeValueForKeyPath:g_DefaultsQuickSearchWhereToFind ofObject:NSUserDefaults.standardUserDefaults change:nil context:nullptr];
        [self observeValueForKeyPath:g_DefaultsQuickSearchSoftFiltering ofObject:NSUserDefaults.standardUserDefaults change:nil context:nullptr];
        [self observeValueForKeyPath:g_DefaultsQuickSearchTypingView ofObject:NSUserDefaults.standardUserDefaults change:nil context:nullptr];
        [self observeValueForKeyPath:g_DefaultsGeneralShowDotDotEntry ofObject:NSUserDefaults.standardUserDefaults change:nil context:nullptr];
        [NSUserDefaults.standardUserDefaults addObserver:self forKeyPaths:MyDefaultsKeys()];
        
        m_View = [[PanelView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        m_View.delegate = self;
        [m_View SetPanelData:&m_Data];
        [self RegisterDragAndDropListeners];
    }

    return self;
}

- (void) dealloc
{
    if(m_UpdatesObservationHost)
        m_UpdatesObservationHost->StopDirChangeObserving(m_UpdatesObservationTicket);

    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPaths:MyDefaultsKeys()];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    
    if(object == defaults)
    {
        if(keyPath == g_DefaultsQuickSearchKeyModifier) {
            m_QuickSearchMode = PanelQuickSearchMode::KeyModifFromInt((int)[defaults integerForKey:g_DefaultsQuickSearchKeyModifier]);
            [self QuickSearchClearFiltering];
        }
        else if(keyPath == g_DefaultsQuickSearchWhereToFind) {
            m_QuickSearchWhere = PanelDataTextFiltering::WhereFromInt((int)[defaults integerForKey:g_DefaultsQuickSearchWhereToFind]);
            [self QuickSearchClearFiltering];
        }
        else if(keyPath == g_DefaultsQuickSearchSoftFiltering) {
            m_QuickSearchIsSoftFiltering = [NSUserDefaults.standardUserDefaults boolForKey:g_DefaultsQuickSearchSoftFiltering];
            [self QuickSearchClearFiltering];
        }
        else if(keyPath == g_DefaultsQuickSearchTypingView) {
            m_QuickSearchTypingView = [NSUserDefaults.standardUserDefaults boolForKey:g_DefaultsQuickSearchTypingView];
            [self QuickSearchClearFiltering];
        }
        else if(keyPath == g_DefaultsGeneralShowDotDotEntry) {
            if([defaults boolForKey:g_DefaultsGeneralShowDotDotEntry] == false)
                m_VFSFetchingFlags |= VFSHost::F_NoDotDot;
            else
                m_VFSFetchingFlags &= ~VFSHost::F_NoDotDot;
            [self RefreshDirectory];
        }
    }
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

- (void) LoadViewState:(NSDictionary *)_state
{
    auto hard_filtering = m_Data.HardFiltering();
    hard_filtering.show_hidden = [[_state valueForKey:@"ViewHiddenFiles"] boolValue];
    [self ChangeHardFilteringTo:hard_filtering];
    
    auto sort_mode = m_Data.SortMode();
    sort_mode.sep_dirs = [[_state valueForKey:@"SeparateDirectories"] boolValue];
    sort_mode.case_sens = [[_state valueForKey:@"CaseSensitiveComparison"] boolValue];
    sort_mode.numeric_sort = [[_state valueForKey:@"NumericSort"] boolValue];
    sort_mode.sort = (PanelSortMode::Mode)[[_state valueForKey:@"SortMode"] integerValue];
    [self ChangeSortingModeTo:sort_mode];
                                      
    m_View.type = (PanelViewType)[[_state valueForKey:@"ViewMode"] integerValue];
}

- (NSDictionary *) SaveViewState
{
    auto mode = m_Data.SortMode();
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:(mode.sep_dirs != false)], @"SeparateDirectories",
        [NSNumber numberWithBool:(m_Data.HardFiltering().show_hidden != false)], @"ViewHiddenFiles",
        [NSNumber numberWithBool:(mode.case_sens != false)], @"CaseSensitiveComparison",
        [NSNumber numberWithBool:(mode.numeric_sort != false)], @"NumericSort",
        [NSNumber numberWithInt:(int)m_View.type], @"ViewMode",
        [NSNumber numberWithInt:(int)mode.sort], @"SortMode",
        nil];
}

- (bool) isActive
{
    return m_View.active;
}

- (void) HandleOpenInSystem
{
    if(auto *item = m_View.item)
    {
        string path = m_Data.DirectoryPathWithTrailingSlash();

        // non-default behaviour here: "/Abra/.." will produce "/Abra/" insted of default-way "/"
        if(!item->IsDotDot())
            path += item->Name();

        // may go async here on non-native VFS
        PanelVFSFileWorkspaceOpener::Open(path, m_Data.Host());
    }
}

- (void) ChangeSortingModeTo:(PanelSortMode)_mode
{
    panel::GenericCursorPersistance pers(m_View, m_Data);
    
    m_Data.SetSortMode(_mode);

    pers.Restore();
    
    [m_View setNeedsDisplay:true];
    [self.state SavePanelsSettings];
}

- (void) ChangeHardFilteringTo:(PanelDataHardFiltering)_filter
{
    panel::GenericCursorPersistance pers(m_View, m_Data);
    
    m_Data.SetHardFiltering(_filter);
    
    pers.Restore();
    
    [m_View setNeedsDisplay:true];
    [self.state SavePanelsSettings];
}

- (void) MakeSortWith:(PanelSortMode::Mode)_direct Rev:(PanelSortMode::Mode)_rev
{
    PanelSortMode mode = m_Data.SortMode(); // we don't want to change anything in sort params except the mode itself
    mode.sort = mode.sort != _direct ? _direct : _rev;
    [self ChangeSortingModeTo:mode];
}

- (IBAction)ToggleViewHiddenFiles:(id)sender{
    auto filtering = m_Data.HardFiltering();
    filtering.show_hidden = !filtering.show_hidden;
    [self ChangeHardFilteringTo:filtering];
}
- (IBAction)ToggleSeparateFoldersFromFiles:(id)sender{
    PanelSortMode mode = m_Data.SortMode();
    mode.sep_dirs = !mode.sep_dirs;
    [self ChangeSortingModeTo:mode];
}
- (IBAction)ToggleCaseSensitiveComparison:(id)sender{
    PanelSortMode mode = m_Data.SortMode();
    mode.case_sens = !mode.case_sens;
    [self ChangeSortingModeTo:mode];
}
- (IBAction)ToggleNumericComparison:(id)sender{
    PanelSortMode mode = m_Data.SortMode();
    mode.numeric_sort = !mode.numeric_sort;
    [self ChangeSortingModeTo:mode];
}
- (IBAction)ToggleSortByName:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByName Rev:PanelSortMode::SortByNameRev];
}
- (IBAction)ToggleSortByExt:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByExt Rev:PanelSortMode::SortByExtRev];
}
- (IBAction)ToggleSortByMTime:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByMTime Rev:PanelSortMode::SortByMTimeRev];
}
- (IBAction)ToggleSortBySize:(id)sender{
    [self MakeSortWith:PanelSortMode::SortBySize Rev:PanelSortMode::SortBySizeRev];
}
- (IBAction)ToggleSortByBTime:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByBTime Rev:PanelSortMode::SortByBTimeRev];
}
- (IBAction)ToggleShortViewMode:(id)sender {
    m_View.type = PanelViewType::ViewShort;
    [self.state SavePanelsSettings];
}
- (IBAction)ToggleMediumViewMode:(id)sender {
    m_View.type = PanelViewType::ViewMedium;
    [self.state SavePanelsSettings];
}
- (IBAction)ToggleFullViewMode:(id)sender{
    m_View.type = PanelViewType::ViewFull;
    [self.state SavePanelsSettings];
}
- (IBAction)ToggleWideViewMode:(id)sender{
    m_View.type = PanelViewType::ViewWide;
    [self.state SavePanelsSettings];
}

- (void) ResetUpdatesObservation:(string)_new_path
{
    if(m_UpdatesObservationHost) {
        m_UpdatesObservationHost->StopDirChangeObserving(m_UpdatesObservationTicket);
        m_UpdatesObservationHost.reset();
    }

    __weak PanelController *weakself = self;
    m_UpdatesObservationTicket = self.VFS->DirChangeObserve(_new_path.c_str(),
        ^{[(PanelController *)weakself RefreshDirectory];} );
    
    if(m_UpdatesObservationTicket)
        m_UpdatesObservationHost = self.VFS;
}

#if 0

- (void) GoToRelativeToHostAsync:(const char*) _path select_entry:(const char*) _entry
{
    [self GoToRelativeAsync:_path
                  WithHosts:make_shared<vector<shared_ptr<VFSHost>>>(m_HostsStack)
                SelectEntry:_entry];
}

- (int) GoToRelativeToHostSync:(const char*) _path
{
    return [self GoToRelativeSync:_path
                        WithHosts:make_shared<vector<shared_ptr<VFSHost>>>(m_HostsStack)
                      SelectEntry:0];
}

- (void) GoToRelativeToHostAsync:(const char*) _path
{
    [self GoToRelativeToHostAsync:_path select_entry:0];
}

- (void) GoToGlobalHostsPathAsync:(const char*) _path
{
    [self GoToGlobalHostsPathAsync:_path select_entry:0];
}

- (int) GoToRelativeSync:(const char*) _path
                WithHosts:(shared_ptr<vector<shared_ptr<VFSHost>>>)_hosts
              SelectEntry:(const char*) _entry_name
{
    m_DirectoryLoadingQ->Stop();
    m_DirectoryLoadingQ->Wait();

    // 1st - try to use last host with this path
    if(_hosts->back()->IsDirectory(_path, 0, 0))
    { // easy - just go there
        shared_ptr<VFSListing> listing;
        int ret = _hosts->back()->FetchDirectoryListing(_path, &listing, m_VFSFetchingFlags, 0);
        if(ret >= 0)
        {
            [self CancelBackgroundOperations]; // clean running operations if any
            [m_View SavePathState];
            
            m_HostsStack = *_hosts; // some overhead here, nevermind
            m_Data.Load(listing);
            [m_View DirectoryChanged:_entry_name];
            [self OnPathChanged:0];
            return VFSError::Ok;
        }
        return ret;
    }
    else
    { // there are 2 variants - path is going inside nested VFS host or is just invalid
        // TODO: no hosted vfs now, need a big cycle here
        char path_buf[MAXPATHLEN*8];
        char valid_path[MAXPATHLEN*8];
        strcpy(path_buf, _path);
            
        if(_hosts->back()->FindLastValidItem(path_buf, valid_path, 0, 0))
        {
            // currently we support only VFS which uses a file as a junction point
            if(!_hosts->back()->IsDirectory(valid_path, 0, 0))
            {
                auto arhost = VFSArchiveProxy::OpenFileAsArchive(valid_path, _hosts->back());
                if(arhost)
                {
                    strcpy(path_buf, path_buf + strlen(valid_path));
                    if(arhost->IsDirectory(path_buf, 0, 0))
                    { // yeah, going here!
                        shared_ptr<VFSListing> listing;
                        int ret = arhost->FetchDirectoryListing(path_buf, &listing, m_VFSFetchingFlags, 0);
                        if(ret >= 0)
                        {
                            [self CancelBackgroundOperations]; // clean running operations if any
                            [m_View SavePathState];

                            m_HostsStack = *_hosts; // some overhead here, nevermind
                            m_HostsStack.push_back(arhost);
                            m_Data.Load(listing);
                            
                            [m_View DirectoryChanged:nullptr];
                            [self OnPathChanged:0];
                            return VFSError::Ok;
                        }
                    }
                }
            }
        }
    }

    return VFSError::NotFound;
}

- (void) GoToRelativeAsync:(const char*) _path
                 WithHosts:(shared_ptr<vector<shared_ptr<VFSHost>>>)_hosts
               SelectEntry:(const char*) _entry_name
{
    string path = string(_path);
    string entryname = string(_entry_name ? _entry_name : "");
    
    // DOUBLE CHECK THIS LINES BELOW!
    if(!m_DirectoryLoadingQ->Empty())
        return;
//    [self CancelBackgroundOperations];
//    m_DirectoryLoadingQ->Wait(); // check me!
    
    m_DirectoryLoadingQ->Run(^(SerialQueue _q) {
        // 1st - try to use last host with this path
        if(_hosts->back()->IsDirectory(path.c_str(), 0, 0))
        { // easy - just go there
            shared_ptr<VFSListing> listing;
            int ret = _hosts->back()->FetchDirectoryListing(path.c_str(), &listing, m_VFSFetchingFlags, ^{return _q->IsStopped();});
            if(ret >= 0)
            {
                [self CancelBackgroundOperations]; // clean running operations if any
                dispatch_to_main_queue( ^{
                    [m_View SavePathState];
                    m_HostsStack = *_hosts; // some overhead here, nevermind
                    m_Data.Load(listing);
                    [m_View DirectoryChanged:entryname.c_str()];
                    [self OnPathChanged:0];
                });
            }
            else
            {
                // TODO: error processing
                // error processing here
/*                auto onfail = ^(NSString* _path, NSError *_error) {
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert setMessageText: [NSString stringWithFormat:@"Failed to enter directory %@", _path]];
                    [alert setInformativeText:[NSString stringWithFormat:@"Error: %@", [_error localizedFailureReason]]];
                    dispatch_to_main_queue( ^{ [alert runModal]; });
                };*/
            }
        }
        else
        { // there are 2 variants - path is going inside nested VFS host or is just invalid
            // TODO: no hosted vfs now, need a big cycle here
            char path_buf[MAXPATHLEN*8];
            char valid_path[MAXPATHLEN*8];
            strcpy(path_buf, path.c_str());
            
            if(_hosts->back()->FindLastValidItem(path_buf, valid_path, 0, 0))
            {
                // currently we support only VFS which uses a file as a junction point
                if(!_hosts->back()->IsDirectory(valid_path, 0, 0))
                {
                    auto arhost = VFSArchiveProxy::OpenFileAsArchive(valid_path, _hosts->back());
                    if(arhost)
                    {
                        strcpy(path_buf, path_buf + strlen(valid_path));
                        if(arhost->IsDirectory(path_buf, 0, 0))
                        { // yeah, going here!
                            shared_ptr<VFSListing> listing;
                            int ret = arhost->FetchDirectoryListing(path_buf, &listing, m_VFSFetchingFlags, ^{return _q->IsStopped();});
                            if(ret >= 0)
                            {
                                [self CancelBackgroundOperations]; // clean running operations if any
                                dispatch_to_main_queue( ^{
                                    [m_View SavePathState];
                                    m_HostsStack = *_hosts; // some overhead here, nevermind
                                    m_HostsStack.push_back(arhost);
                                    m_Data.Load(listing);
                                    [m_View DirectoryChanged:nullptr];
                                    [self OnPathChanged:0];
                                });
                            }
                        }
                    }
                }
            }
        }
    });
}

- (bool) GetCommonHostsStackForPath:(const char*) _path rest:(char*) _rest hosts:(shared_ptr<vector<shared_ptr<VFSHost>>>&) _hosts
{
    // no blocking ops here, can call from main thread
    // TODO later: here we assume that top-level host should began with '', but networks vfs will operate with other format
    if(m_HostsStack.empty()) return false;
    assert( strcmp(m_HostsStack[0]->JunctionPath(), "") == 0 );
    
    shared_ptr<vector<shared_ptr<VFSHost>>> hosts = make_shared<vector<shared_ptr<VFSHost>>>();

    int hn = 0;
    char rest[MAXPATHLEN*8];
    strcpy(rest, _path);
    hosts->push_back(m_HostsStack[hn++]);
    
    while(true) {
        if(hn == m_HostsStack.size()) break;
        
        char junction[MAXPATHLEN];
        strcpy(junction, m_HostsStack[hn]->JunctionPath());
        
        if(strncmp(rest, junction, strlen(junction)) == 0) {
            hosts->push_back(m_HostsStack[hn++]);
            strcpy(rest, rest + strlen(junction));
        }
        else break;
    }
    
    strcpy(_rest, rest);
    _hosts = hosts;
    
    return true;
}

- (void) GoToGlobalHostsPathAsync:(const char*) _path select_entry:(const char*) _entry
{
    if(_path == 0)
        return;

    if(_entry == 0)
    { // check we're already on this path (don't check if we're also asked to select some entry)
        char asked[MAXPATHLEN*8];
        strcpy(asked, _path);
        
        char current[MAXPATHLEN*8];
        m_Data.GetDirectoryFullHostsPathWithTrailingSlash(current);
        
        if(!IsPathWithTrailingSlash(asked))
            strcat(asked, "/");

        // will return false on the same path written other way (case insensitivity issues), but that's ok
        if(strcmp(asked, current) == 0 &&
            m_Data.Host() != 0) /* special case for initialization process*/
            return;
    }
    
    char rest[MAXPATHLEN*8];
    shared_ptr<vector<shared_ptr<VFSHost>>> stack;
    if([self GetCommonHostsStackForPath:_path rest:rest hosts:stack])
    {
        [self GoToRelativeAsync:rest WithHosts:stack SelectEntry:_entry];
    }
    else
    {
        stack = make_shared<vector<shared_ptr<VFSHost>>>();
        stack->push_back(VFSNativeHost::SharedHost());
        [self GoToRelativeAsync:_path WithHosts:stack SelectEntry:_entry];
    }
}

- (int) GoToGlobalHostsPathSync:(const char*) _path
{
    if(_path == nullptr ||
       _path[0] != '/')
        return VFSError::InvalidCall;
    
    { // check we're already on this path
        char asked[MAXPATHLEN*8];
        strcpy(asked, _path);
        
        char current[MAXPATHLEN*8];
        m_Data.GetDirectoryFullHostsPathWithTrailingSlash(current);
        
        if(!IsPathWithTrailingSlash(asked))
            strcat(asked, "/");
        
        // will return false on the same path written other way (case insensitivity issues), but that's ok
        if(strcmp(asked, current) == 0 &&
           m_Data.Host() != 0) /* special case for initialization process*/
            return 0;
    }
    
    char rest[MAXPATHLEN*8];
    shared_ptr<vector<shared_ptr<VFSHost>>> stack;
    if([self GetCommonHostsStackForPath:_path rest:rest hosts:stack])
    {
        return [self GoToRelativeSync:rest WithHosts:stack SelectEntry:0];
    }
    else
    {
        stack = make_shared<vector<shared_ptr<VFSHost>>>();
        stack->push_back(VFSNativeHost::SharedHost());
        return [self GoToRelativeSync:_path WithHosts:stack SelectEntry:0];
    }
}

#endif

- (bool) HandleGoToUpperDirectory
{
    path cur = path(m_Data.DirectoryPathWithTrailingSlash());
    if(cur.empty()) return false;
    if(cur == "/")
    {
        if(self.VFS->Parent() != nullptr)
        {
            path junct = self.VFS->JunctionPath();
            assert(!junct.empty());
            string dir = junct.parent_path().native();
            string sel_fn = junct.filename().native();
            return [self GoToDir:dir vfs:self.VFS->Parent() select_entry:sel_fn async:true] == 0;
        }
    }
    else
    {
        string dir = cur.parent_path().remove_filename().native();
        string sel_fn = cur.parent_path().filename().native();
        return [self GoToDir:dir vfs:self.VFS select_entry:sel_fn async:true] == 0;
    }
    return false;
}


- (bool) HandleGoIntoDirOrArchive
{
    const auto entry = m_View.item;
    if(entry == nullptr)
        return false;
    
    // Handle directories.
    if(entry->IsDir())
    {
        if(entry->IsDotDot())
            return [self HandleGoToUpperDirectory];
        
        path cur = path(m_Data.DirectoryPathWithTrailingSlash());
        return [self GoToDir:(cur/entry->Name()).native() vfs:self.VFS select_entry:"" async:true] == 0;
    }
    else
    { // archive stuff here
        auto arhost = VFSArchiveProxy::OpenFileAsArchive(self.GetCurrentFocusedEntryFilePathRelativeToHost,
                                                         self.VFS);
        if(arhost)
            return [self GoToDir:"/" vfs:arhost select_entry:"" async:true] == 0;
    }
    
    return false;
}

- (void) HandleGoIntoDirOrOpenInSystem
{
    if([self HandleGoIntoDirOrArchive])
        return;
    
    auto entry = m_View.item;
    if(entry == nullptr)
        return;
    
    // need more sophisticated executable handling here
    if(self.VFS->IsNativeFS() && IsEligbleToTryToExecuteInConsole(*entry))
    {
        auto path = [self GetCurrentDirectoryPathRelativeToHost];
        [(MainWindowController*)self.window.delegate RequestTerminalExecution:entry->Name() at:path.c_str()];
        
        return;
    }
    
    // If previous code didn't handle current item,
    // open item with the default associated application.
    [self HandleOpenInSystem];
}

- (void) RefreshDirectory
{
    if(m_View == nil) return; // guard agains calls from init process
    
    // going async here
    if(!m_DirectoryLoadingQ->Empty())
        return; //reducing overhead
    
    string dirpath = m_Data.DirectoryPathWithTrailingSlash();
    auto vfs = self.VFS;
    
    m_DirectoryReLoadingQ->Run(^(SerialQueue _q){
        shared_ptr<VFSListing> listing;
        int ret = vfs->FetchDirectoryListing(dirpath.c_str(), &listing, m_VFSFetchingFlags, ^{ return _q->IsStopped(); });
        if(ret >= 0)
        {
            dispatch_to_main_queue( ^{
                panel::GenericCursorPersistance pers(m_View, m_Data);
                
                m_Data.ReLoad(listing);
                
                if(![self CheckAgainstRequestedSelection])
                    pers.Restore();

                [self OnCursorChanged];
                [m_View setNeedsDisplay:true];
            });
        }
        else
        {
            dispatch_to_main_queue( ^{
                [self RecoverFromInvalidDirectory];
            });
        }
    });
}

- (bool) PanelViewProcessKeyDown:(PanelView*)_view event:(NSEvent *)event
{
    [self ClearSelectionRequest]; // on any key press we clear entry selection request if any
    
    if([self QuickSearchProcessKeyDown:event])
        return true;
    
    NSString*  const character   = event.charactersIgnoringModifiers;
    if ( character.length != 1 )
        return false;
    
    NSUInteger const modif       = event.modifierFlags;
    unichar const unicode        = [character characterAtIndex:0];
    unsigned short const keycode = event.keyCode;
    
    if(unicode == NSTabCharacter) { // Tab button
        [self.state HandleTabButton];
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
    
    if(keycode == 3 ) { // 'F' button
        if( (modif&NSDeviceIndependentModifierFlagsMask) == (NSFunctionKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask))
        {
            [self HandleFTPConnection];
            return true;
        }
    }
    
    // handle some actions manually, to prevent annoying by menu highlighting by hotkey
    auto &shortcuts = ActionsShortcutsManager::Instance();
    if(shortcuts.ShortCutFromAction("menu.file.open")->IsKeyDown(unicode, keycode, modif)) {
        [self HandleGoIntoDirOrOpenInSystem];
        return true;
    }
    if(shortcuts.ShortCutFromAction("menu.file.open_native")->IsKeyDown(unicode, keycode, modif)) {
        [self HandleOpenInSystem];
        return true;
    }
    if(shortcuts.ShortCutFromAction("menu.file.calculate_sizes")->IsKeyDown(unicode, keycode, modif)) {
        [self OnCalculateSizes:self];
        return true;
    }
    if(shortcuts.ShortCutFromAction("menu.file.calculate_all_sizes")->IsKeyDown(unicode, keycode, modif)) {
        [self OnCalculateAllSizes:self];
        return true;
    }

    return false;
}

- (void) CalculateSizesWithNames:(chained_strings) _filenames
{
    auto complet = ^(const char* _sub_dir, uint64_t _size) {
        string sub_dir = _sub_dir;
        dispatch_to_main_queue(^{
            panel::GenericCursorPersistance pers(m_View, m_Data);
            // may cause re-sorting if current sorting is by size
            if(m_Data.SetCalculatedSizeForDirectory(sub_dir.c_str(), _size))
            {
                [m_View setNeedsDisplay];
                pers.Restore();
            }
        });
    };
    
    string current_dir = m_Data.DirectoryPathWithTrailingSlash();
    __block auto dir_names = move(_filenames);
    m_DirectorySizeCountingQ->Run( ^(SerialQueue _q){
        self.VFS->CalculateDirectoriesSizes(move(dir_names),
                                                       current_dir.c_str(),
                                                       ^bool {
                                                           return _q->IsStopped();
                                                       },
                                                       complet);
    });
}

- (IBAction)OnCalculateSizes:(id)sender
{
    // suboptimal - may have regular files inside (not dirs)
    [self CalculateSizesWithNames:self.GetSelectedEntriesOrFocusedEntryWithDotDot];
}

- (IBAction)OnCalculateAllSizes:(id)sender
{
    chained_strings filenames;
    for(auto &i: *m_Data.Listing())
        if(i.IsDir() && !i.IsDotDot())
            filenames.push_back(i.Name(), nullptr);
    
    [self CalculateSizesWithNames:move(filenames)];
}

- (void) ModifierFlagsChanged:(unsigned long)_flags // to know if shift or something else is pressed
{
    [m_View ModifierFlagsChanged:_flags];

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
    const auto visual_spinning_delay = 100ull; // in 100 ms of workload should be before user will get spinning indicator
    
    if(is_anything_working == m_IsAnythingWorksInBackground)
        return; // nothing to update;
        
    if(is_anything_working)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, visual_spinning_delay * USEC_PER_SEC),
                       dispatch_get_main_queue(),
                       ^{
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

- (void) RecoverFromInvalidDirectory
{
#if 0
    // TODO: recovering to upper host needed
    char path[MAXPATHLEN];
    strcpy(path, m_Data.DirectoryPathWithoutTrailingSlash().c_str());
    if(GetFirstAvailableDirectoryFromPath(path))
//        [self GoToDirectory:path];
        [self GoToRelativeToHostAsync:path select_entry:0];
#endif
}

- (void) SelectAllEntries:(bool) _select
{
    m_Data.CustomFlagsSelectAllSorted(_select);
    [m_View setNeedsDisplay:true];
}

- (void)selectAll:(id)sender
{
    [self SelectAllEntries:true];
}

- (void)deselectAll:(id)sender
{
    [self SelectAllEntries:false];
}

- (IBAction)OnRefreshPanel:(id)sender
{
    [self RefreshDirectory];
}

- (IBAction)OnFileViewCommand:(id)sender
{
    // Close quick preview, if it is open.
    if(m_QuickLook) {
        [self.state CloseOverlay:self];
        m_QuickLook = nil;
        return;
    }
    
    m_QuickLook = [self.state RequestQuickLookView:self];
    [self OnCursorChanged];
}

- (IBAction)OnBriefSystemOverviewCommand:(id)sender
{
    if(m_BriefSystemOverview)
    {
        [self.state CloseOverlay:self];
        m_BriefSystemOverview = nil;
        return;
    }
    m_BriefSystemOverview = [self.state RequestBriefSystemOverview:self];
    [self UpdateBriefSystemOverview];
}

- (void) OnPathChanged:(int)_flags
{
    [self ResetUpdatesObservation:m_Data.DirectoryPathWithTrailingSlash()];
    [self ClearSelectionRequest];
    [self QuickSearchClearFiltering];
    [self.state PanelPathChanged:self];
    [self OnCursorChanged];
    [self UpdateBriefSystemOverview];
    
    if((_flags & PanelControllerNavigation::NoHistory) == 0) {
        auto listing = m_Data.DirectoryEntries().SharedPtr();
        m_History.Put(VFSPathStack::CreateWithVFSListing(listing));
    }
}

- (void) OnCursorChanged
{
    // need to update some UI here
    auto item = m_View.item;
    auto host = m_Data.Host();
  
    // update share button regaring current state
    m_ShareButton.enabled = m_Data.Stats().selected_entries_amount > 0 ||
                            [SharingService SharingEnabledForItem:item VFS:host];
    
    // update QuickLook if any
    [(QuickLookView *)m_QuickLook PreviewItem:[self GetCurrentFocusedEntryFilePathRelativeToHost]
                                          vfs:host];
}

- (void)OnEjectButton:(id)sender
{
    EjectVolumeContainingPath(m_Data.DirectoryPathWithoutTrailingSlash());
}

- (void)OnShareButton:(id)sender
{
    if(SharingService.IsCurrentlySharing)
        return;
    
    auto files = [self GetSelectedEntriesOrFocusedEntryWithoutDotDot];
    if(files.empty())
        return;
    
    [[SharingService new] ShowItems:move(files)
                              InDir:m_Data.DirectoryPathWithTrailingSlash()
                              InVFS:self.VFS
                     RelativeToRect:[sender bounds]
                             OfView:sender
                      PreferredEdge:NSMinYEdge];
}

- (void) UpdateBriefSystemOverview
{
    [(BriefSystemOverview *)m_BriefSystemOverview UpdateVFSTarget:[self GetCurrentDirectoryPathRelativeToHost].c_str()
                                                             host:self.VFS];
}

- (void) PanelViewCursorChanged:(PanelView*)_view
{
    [self OnCursorChanged];
}

- (void) PanelViewRequestsActivation:(PanelView*)_view
{
    [self.state ActivatePanelByController:self];
}

- (NSMenu*) PanelViewRequestsContextMenu:(PanelView*)_view
{
    const VFSListingItem* cur_focus = m_View.item;
    if(!cur_focus || cur_focus->IsDotDot())
        return nil;
    
    vector<const VFSListingItem*> items;
    
    // 2 variants - currently focused item or all selected items (if focus is also selected)
    if(m_Data.Stats().selected_entries_amount == 0 || !cur_focus->CFIsSelected())
        items.push_back(cur_focus); // use focused item solely
    else
        for(auto &i: *m_Data.Listing()) // use selected items
            if(i.CFIsSelected())
                items.push_back(&i);
    
    return [self.state RequestContextMenuOn:items
                                       path:[self GetCurrentDirectoryPathRelativeToHost].c_str()
                                        vfs:self.VFS
                                     caller:self];
}

- (void) PanelViewDoubleClick:(PanelView*)_view atElement:(int)_sort_pos
{
    [self HandleGoIntoDirOrOpenInSystem];
}

- (void) HandleFTPConnection
{
    FTPConnectionSheetController *sheet = [FTPConnectionSheetController new];
    [sheet ShowSheet:self.window
             handler:^{
                 if(sheet.server == nil)
                     return;
                 string server =  sheet.server.UTF8String;
                 
                 string username = sheet.username ? sheet.username.UTF8String : "";
                 string password = sheet.password ? sheet.password.UTF8String : "";
                 string path = sheet.path ? sheet.path.UTF8String : "/";
                 if(path.empty() || path[0] != '/')
                     path = "/";
                 
                 VFSNetFTPOptions opts;
                 opts.user = username;
                 opts.passwd = password;

                 auto host = make_shared<VFSNetFTPHost>(server.c_str());
                 if(host->Open(path.c_str(), opts) != 0)
                     return;
                
                 [self GoToDir:path vfs:host select_entry:"" async:true];
             }];
}

- (IBAction)OnCopyCurrentFileName:(id)sender {
    [NSPasteboard writeSingleString:self.GetCurrentFocusedEntryFilename.c_str()];
}

- (IBAction)OnCopyCurrentFilePath:(id)sender {
    [NSPasteboard writeSingleString:self.GetCurrentFocusedEntryFilePathRelativeToHost.c_str()];
}

- (IBAction)performFindPanelAction:(id)sender
{
    FindFilesSheetController *sheet = [FindFilesSheetController new];
    [sheet ShowSheet:self.window
             withVFS:self.VFS
            fromPath:self.GetCurrentDirectoryPathRelativeToHost
             handler:^{
                 if(auto item = sheet.SelectedItem)
                     [self GoToDir:item->dir_path vfs:self.VFS select_entry:item->filename async:true];
             }
     ];
}

- (IBAction)OnEjectVolume:(id)sender
{
    if(!self.VFS->IsNativeFS())
        return;
    
    string path = m_Data.DirectoryPathWithoutTrailingSlash();
    if(IsVolumeContainingPathEjectable(path.c_str()))
        EjectVolumeContainingPath(path);
}

- (void) SelectEntriesByMask:(NSString*)_mask select:(bool)_select
{
    bool ignore_dirs = [NSUserDefaults.standardUserDefaults boolForKey:g_DefaultsGeneralIgnoreDirsOnMaskSel];
    if(m_Data.CustomFlagsSelectAllSortedByMask(_mask, _select, ignore_dirs))
        [m_View setNeedsDisplay:true];
}

- (IBAction)OnSelectByMask:(id)sender
{
    SelectionWithMaskSheetController *sheet = [SelectionWithMaskSheetController new];
    [sheet ShowSheet:self.window handler:^{
        [self SelectEntriesByMask:sheet.Mask select:true];
    }];
}

- (IBAction)OnDeselectByMask:(id)sender
{
    SelectionWithMaskSheetController *sheet = [SelectionWithMaskSheetController new];
    [sheet SetIsDeselect:true];
    [sheet ShowSheet:self.window handler:^{
        [self SelectEntriesByMask:sheet.Mask select:false];
    }];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    auto upd_for_sort = [](NSMenuItem * _item, PanelSortMode _mode, PanelSortMode::Mode _mask){
        static NSImage *img = [NSImage imageNamed:NSImageNameRemoveTemplate];
        if(_mode.sort & _mask) {
            _item.image = _mode.isrevert() ? img : nil;
            _item.state = NSOnState;
        }
        else {
            _item.image = nil;
            _item.state = NSOffState;
        }
    };
    
    static const int tag_short_mode =         ActionsShortcutsManager::Instance().TagFromAction("menu.view.toggle_short_mode");
    static const int tag_medium_mode =        ActionsShortcutsManager::Instance().TagFromAction("menu.view.toggle_medium_mode");
    static const int tag_full_mode =          ActionsShortcutsManager::Instance().TagFromAction("menu.view.toggle_full_mode");
    static const int tag_wide_mode =          ActionsShortcutsManager::Instance().TagFromAction("menu.view.toggle_wide_mode");
    static const int tag_sort_name =          ActionsShortcutsManager::Instance().TagFromAction("menu.view.sorting_by_name");
    static const int tag_sort_ext =           ActionsShortcutsManager::Instance().TagFromAction("menu.view.sorting_by_extension");
    static const int tag_sort_mod =           ActionsShortcutsManager::Instance().TagFromAction("menu.view.sorting_by_modify_time");
    static const int tag_sort_size =          ActionsShortcutsManager::Instance().TagFromAction("menu.view.sorting_by_size");
    static const int tag_sort_creat =         ActionsShortcutsManager::Instance().TagFromAction("menu.view.sorting_by_creation_time");
    static const int tag_sort_viewhidden =    ActionsShortcutsManager::Instance().TagFromAction("menu.view.sorting_view_hidden");
    static const int tag_sort_sepfolders =    ActionsShortcutsManager::Instance().TagFromAction("menu.view.sorting_separate_folders");
    static const int tag_sort_casesens =      ActionsShortcutsManager::Instance().TagFromAction("menu.view.sorting_case_sensitive");
    static const int tag_sort_numeric =       ActionsShortcutsManager::Instance().TagFromAction("menu.view.sorting_numeric_comparison");
    
    NSInteger tag = item.tag;
    if(tag == tag_short_mode)       item.State = m_View.type == PanelViewType::ViewShort;
    else if(tag == tag_medium_mode) item.State = m_View.type == PanelViewType::ViewMedium;
    else if(tag == tag_full_mode)   item.State = m_View.type == PanelViewType::ViewFull;
    else if(tag == tag_wide_mode)   item.State = m_View.type == PanelViewType::ViewWide;
    else if(tag == tag_sort_viewhidden) item.State = m_Data.HardFiltering().show_hidden;
    else if(tag == tag_sort_sepfolders) item.State = m_Data.SortMode().sep_dirs;
    else if(tag == tag_sort_casesens)   item.State = m_Data.SortMode().case_sens;
    else if(tag == tag_sort_numeric)    item.State = m_Data.SortMode().numeric_sort;
    else if(tag == tag_sort_name)   upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByNameMask);
    else if(tag == tag_sort_ext)    upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByExtMask);
    else if(tag == tag_sort_mod)    upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByMTimeMask);
    else if(tag == tag_sort_size)   upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortBySizeMask);
    else if(tag == tag_sort_creat)  upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByBTimeMask);
    
    return true; // will disable some items in the future
}

- (IBAction)OnShowTerminal:(id)sender
{
    string path;
    if(self.VFS->IsNativeFS())
        path = self.GetCurrentDirectoryPathRelativeToHost;
    [(MainWindowController*)self.window.delegate RequestTerminal:path.c_str()];
}

- (IBAction)OnDetailedVolumeInformation:(id)sender
{
    if(!m_Data.Host()->IsNativeFS())
        return; // currently support volume info only on native fs
    
    string path = self.GetCurrentDirectoryPathRelativeToHost;
    if(m_View.item && !m_View.item->IsDotDot())
        path += m_View.item->Name();
    
    DetailedVolumeInformationSheetController *sheet = [DetailedVolumeInformationSheetController new];
    [sheet ShowSheet:self.window destpath:path.c_str()];
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender
{
    auto i = m_View.item;
    if(!i || i->IsDir()) return;
    
    string path = m_Data.DirectoryPathWithTrailingSlash() + i->Name();
    auto host = m_Data.Host();
    [(MainWindowController*)self.window.delegate RequestBigFileView:path
                                                            with_fs:host];
}

- (IBAction)OnFileAttributes:(id)sender
{
    if(!m_Data.Host()->IsNativeFS())
        return; // currently support file info only on native fs
    
    FileSysEntryAttrSheetController *sheet = [FileSysEntryAttrSheetController new];
    FileSysEntryAttrSheetCompletionHandler handler = ^(int result){
        if(result == DialogResult::Apply)
            [self.state AddOperation:[[FileSysAttrChangeOperation alloc] initWithCommand:sheet.Result]];
    };
    
    if(m_Data.Stats().selected_entries_amount > 0 )
        [sheet ShowSheet:self.window selentries:&m_Data handler:handler];
    else if(m_View.item && !m_View.item->IsDotDot())
        [sheet ShowSheet:self.window
                    data:&m_Data
                   index:m_Data.RawIndexForSortIndex(m_View.curpos)
                 handler:handler];
}

- (int) GoToDir:(string)_dir
            vfs:(VFSHostPtr)_vfs
   select_entry:(string)_filename
          async:(bool)_asynchronous
{
    if(_dir.empty() || _dir.front() != '/' || !_vfs)
        return VFSError::InvalidCall;
    
    if(_asynchronous == false)
    {
        assert(dispatch_is_main_queue());
        m_DirectoryLoadingQ->Stop();
        m_DirectoryLoadingQ->Wait();
    }
    else
    {
        if(!m_DirectoryLoadingQ->Empty())
            return 0;
    }

    __block int ret = 0;
    auto workblock = ^(SerialQueue _q) {
        if(!_vfs->IsDirectory(_dir.c_str(), 0, 0))
        {
            ret = VFSError::FromErrno(ENOTDIR);
            return;
        }
        shared_ptr<VFSListing> listing;
        ret = _vfs->FetchDirectoryListing(_dir.c_str(),
                                          &listing,
                                          m_VFSFetchingFlags,
                                          ^{return _q->IsStopped();});
        if(ret < 0)
            return;
        
        [self CancelBackgroundOperations]; // clean running operations if any
        dispatch_or_run_in_main_queue( ^{
            [m_View SavePathState];
            m_Data.Load(listing);
            [m_View DirectoryChanged:_filename.c_str()];
            [self OnPathChanged:0];
        });
    };
    
    if(_asynchronous == false)
    {
        m_DirectoryLoadingQ->RunSyncHere(workblock);
        return ret;
    }
    else
    {
        m_DirectoryLoadingQ->Run(workblock);
        return 0;
    }
}

- (IBAction)OnGoToUpperDirectory:(id)sender // cmd+up
{
    [self HandleGoToUpperDirectory];
}

- (IBAction)OnGoIntoDirectory:(id)sender // cmd+down
{
    auto item = m_View.item;
    if(item != nullptr && item->IsDotDot() == false)
        [self HandleGoIntoDirOrArchive];
}

- (IBAction)OnOpen:(id)sender // enter
{
    [self HandleGoIntoDirOrOpenInSystem];
}

- (IBAction)OnOpenNatively:(id)sender // shift+enter
{
    [self HandleOpenInSystem];
}

- (IBAction)OnGoToProcessesList:(id)sender
{
    [self GoToDir:"/" vfs:VFSPSHost::GetSharedOrNew() select_entry:"" async:true];
}

@end
