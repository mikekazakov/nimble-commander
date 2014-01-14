//
//  PanelController.m
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#import "PanelController.h"
#import "FSEventsDirUpdate.h"
#import "Common.h"
#import "MainWindowController.h"
#import "QuickPreview.h"
#import "MainWindowFilePanelState.h"
#import "filesysinfo.h"
#import "FileMask.h"
#import "PanelAux.h"
#import "SharingService.h"
#import "PanelFastSearchPopupViewController.h"
#import "BriefSystemOverview.h"

// this constant should be the same as g_FadeDelay in PanelFastSearchController,
// otherwise it may cause UI/Input inconsistency
static const uint64_t g_FastSeachDelayTresh = 5000000000; // 5 sec


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
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *un = [NSMutableCharacterSet new];
        [un formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
        [un formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
        chars = un;
    });
    
    if(_s.length == 0)
        return false;
    
    unichar u = [_s characterAtIndex:0]; // consider uing UTF-32 here
    return [chars characterIsMember:u];
}

namespace {
class GenericCursorPersistance
{
public:
    GenericCursorPersistance(PanelView* _view, PanelData *_data):
        view(_view),
        data(_data),
        oldcursorpos([_view GetCursorPosition])
    {
        if(oldcursorpos >= 0 && [view CurrentItem] != nullptr)
            oldcursorname = [view CurrentItem]->Name();
    }
 
    
    void Restore()
    {
        int newcursorrawpos = data->RawIndexForName(oldcursorname.c_str());
        if( newcursorrawpos >= 0 )
        {
            int newcursorsortpos = data->SortedIndexForRawIndex(newcursorrawpos);
            if(newcursorsortpos >= 0)
                [view SetCursorPosition:newcursorsortpos];
            else
                [view SetCursorPosition:data->SortedDirectoryEntries().empty() ? -1 : 0];
        }
        else
        {
            if( oldcursorpos < data->SortedDirectoryEntries().size() )
                [view SetCursorPosition:oldcursorpos];
            else
                [view SetCursorPosition:int(data->SortedDirectoryEntries().size()) - 1];
        }
    }
    
private:
    PanelView *view;
    PanelData *data;
    int oldcursorpos;
    string oldcursorname;
};
}

@implementation PanelController


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
        
        m_HostsStack.push_back( VFSNativeHost::SharedHost() );
        
        __weak PanelController* weakself = self;
        auto on_change = ^{ dispatch_to_main_queue( ^{ [weakself UpdateSpinningIndicator]; }); };
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
    }

    return self;
}

- (void) dealloc
{
    if(m_UpdatesObservationHost)
        m_UpdatesObservationHost->StopDirChangeObserving(m_UpdatesObservationTicket);

    [NSUserDefaults.standardUserDefaults removeObserver:self forKeyPaths:MyDefaultsKeys()];
}

// without calling SetData:0 PanelController may do something very bad. need to discover what!
- (void) SetData:(PanelData*)_data
{
    m_Data = _data;
    [self CancelBackgroundOperations];
}

- (void) SetView:(PanelView*)_view
{
    m_View = _view;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    
    if(object == defaults)
    {
        if(keyPath == g_DefaultsQuickSearchKeyModifier) {
            m_QuickSearchMode = PanelQuickSearchMode::KeyModifFromInt((int)[defaults integerForKey:g_DefaultsQuickSearchKeyModifier]);
            [self ClearFastSearchFiltering];
        }
        else if(keyPath == g_DefaultsQuickSearchWhereToFind) {
            m_QuickSearchWhere = PanelDataTextFiltering::WhereFromInt((int)[defaults integerForKey:g_DefaultsQuickSearchWhereToFind]);
            [self ClearFastSearchFiltering];
        }
        else if(keyPath == g_DefaultsQuickSearchSoftFiltering) {
            m_QuickSearchIsSoftFiltering = [NSUserDefaults.standardUserDefaults boolForKey:g_DefaultsQuickSearchSoftFiltering];
            [self ClearFastSearchFiltering];
        }
        else if(keyPath == g_DefaultsQuickSearchTypingView) {
            m_QuickSearchTypingView = [NSUserDefaults.standardUserDefaults boolForKey:g_DefaultsQuickSearchTypingView];
            [self ClearFastSearchFiltering];
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

- (void) LoadViewState:(NSDictionary *)_state
{
    auto hard_filtering = m_Data->HardFiltering();
    hard_filtering.show_hidden = [[_state valueForKey:@"ViewHiddenFiles"] boolValue];
    [self ChangeHardFilteringTo:hard_filtering];
    
    auto sort_mode = m_Data->SortMode();
    sort_mode.sep_dirs = [[_state valueForKey:@"SeparateDirectories"] boolValue];
    sort_mode.case_sens = [[_state valueForKey:@"CaseSensitiveComparison"] boolValue];
    sort_mode.numeric_sort = [[_state valueForKey:@"NumericSort"] boolValue];
    sort_mode.sort = (PanelSortMode::Mode)[[_state valueForKey:@"SortMode"] integerValue];
    [self ChangeSortingModeTo:sort_mode];
                                      
    [m_View ToggleViewType:(PanelViewType)[[_state valueForKey:@"ViewMode"] integerValue]];
}

- (NSDictionary *) SaveViewState
{
    auto mode = m_Data->SortMode();
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:(mode.sep_dirs != false)], @"SeparateDirectories",
        [NSNumber numberWithBool:(m_Data->HardFiltering().show_hidden != false)], @"ViewHiddenFiles",
        [NSNumber numberWithBool:(mode.case_sens != false)], @"CaseSensitiveComparison",
        [NSNumber numberWithBool:(mode.numeric_sort != false)], @"NumericSort",
        [NSNumber numberWithInt:(int)[m_View GetCurrentViewType]], @"ViewMode",
        [NSNumber numberWithInt:(int)mode.sort], @"SortMode",
        nil];
}

- (bool) IsActivePanel
{
    return [[self GetParentWindow] ActivePanelController] == self;
}

- (void) RequestActivation
{
    [[self GetParentWindow] ActivatePanelByController:self];
}

- (void) HandleShiftReturnButton
{
    if(auto *item = [m_View CurrentItem])
    {
        string path = m_Data->DirectoryPathWithTrailingSlash();

        // non-default behaviour here: "/Abra/.." will produce "/Abra/" insted of default-way "/"
        if(!item->IsDotDot())
            path += item->Name();

        // may go async here on non-native VFS
        PanelVFSFileWorkspaceOpener::Open(path, m_Data->Host());
    }
}

- (void) ChangeSortingModeTo:(PanelSortMode)_mode
{
    GenericCursorPersistance pers(m_View, m_Data);
    
    m_Data->SetSortMode(_mode);

    pers.Restore();
    
    [m_View setNeedsDisplay:true];
}

- (void) ChangeHardFilteringTo:(PanelDataHardFiltering)_filter
{
    GenericCursorPersistance pers(m_View, m_Data);
    
    m_Data->SetHardFiltering(_filter);
    
    pers.Restore();
    
    [m_View setNeedsDisplay:true];
}

- (void) MakeSortWith:(PanelSortMode::Mode)_direct Rev:(PanelSortMode::Mode)_rev
{
    PanelSortMode mode = m_Data->SortMode(); // we don't want to change anything in sort params except the mode itself
    if(mode.sort != _direct)  mode.sort = _direct;
    else                      mode.sort = _rev;
    [self ChangeSortingModeTo:mode];
}

- (void) ToggleViewHiddenFiles
{
    auto filtering = m_Data->HardFiltering();
    filtering.show_hidden = !filtering.show_hidden;
    [self ChangeHardFilteringTo:filtering];
}

- (void) ToggleSeparateFoldersFromFiles
{
    PanelSortMode mode = m_Data->SortMode();
    mode.sep_dirs = !mode.sep_dirs;
    [self ChangeSortingModeTo:mode];
}

- (void) ToggleCaseSensitiveComparison
{
    PanelSortMode mode = m_Data->SortMode();
    mode.case_sens = !mode.case_sens;
    [self ChangeSortingModeTo:mode];
}

- (void) ToggleNumericComparison
{
    PanelSortMode mode = m_Data->SortMode();
    mode.numeric_sort = !mode.numeric_sort;
    [self ChangeSortingModeTo:mode];
}

- (void) ToggleSortingBySize{
    [self MakeSortWith:PanelSortMode::SortBySize Rev:PanelSortMode::SortBySizeRev];}
- (void) ToggleSortingByName{
    [self MakeSortWith:PanelSortMode::SortByName Rev:PanelSortMode::SortByNameRev];}
- (void) ToggleSortingByMTime{
    [self MakeSortWith:PanelSortMode::SortByMTime Rev:PanelSortMode::SortByMTimeRev];}
- (void) ToggleSortingByBTime{
    [self MakeSortWith:PanelSortMode::SortByBTime Rev:PanelSortMode::SortByBTimeRev];}
- (void) ToggleSortingByExt{
    [self MakeSortWith:PanelSortMode::SortByExt Rev:PanelSortMode::SortByExtRev];}
- (void) ToggleShortViewMode{
    [m_View ToggleViewType:PanelViewType::ViewShort];}
- (void) ToggleMediumViewMode{
    [m_View ToggleViewType:PanelViewType::ViewMedium];}
- (void) ToggleFullViewMode{
    [m_View ToggleViewType:PanelViewType::ViewFull];}
- (void) ToggleWideViewMode{
    [m_View ToggleViewType:PanelViewType::ViewWide];}

- (void) ResetUpdatesObservation:(string)_new_path
{
    if(m_UpdatesObservationHost) {
        m_UpdatesObservationHost->StopDirChangeObserving(m_UpdatesObservationTicket);
        m_UpdatesObservationHost.reset();
    }

    __weak PanelController *weakself = self;
    m_UpdatesObservationTicket = m_HostsStack.back()->DirChangeObserve(_new_path.c_str(), ^{ [weakself RefreshDirectory]; } );
    if(m_UpdatesObservationTicket)
        m_UpdatesObservationHost = m_HostsStack.back();
}

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
            m_Data->Load(listing);
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
                // TODO: support for different VFS
                shared_ptr<VFSArchiveHost> arhost = make_shared<VFSArchiveHost>(valid_path, _hosts->back());
                if(arhost->Open() >= 0)
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
                            m_Data->Load(listing);
                            
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
                    m_Data->Load(listing);
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
                    // TODO: support for different VFS
                    shared_ptr<VFSArchiveHost> arhost = make_shared<VFSArchiveHost>(valid_path, _hosts->back());
                    if(arhost->Open() >= 0)
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
                                    m_Data->Load(listing);
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
        m_Data->GetDirectoryFullHostsPathWithTrailingSlash(current);
        
        if(!IsPathWithTrailingSlash(asked))
            strcat(asked, "/");

        // will return false on the same path written other way (case insensitivity issues), but that's ok
        if(strcmp(asked, current) == 0 &&
            m_Data->Host() != 0) /* special case for initialization process*/
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
        m_Data->GetDirectoryFullHostsPathWithTrailingSlash(current);
        
        if(!IsPathWithTrailingSlash(asked))
            strcat(asked, "/");
        
        // will return false on the same path written other way (case insensitivity issues), but that's ok
        if(strcmp(asked, current) == 0 &&
           m_Data->Host() != 0) /* special case for initialization process*/
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

- (void) GoToUpperDirectoryAsync
{
    // TODO: need some changes when VFS will became multi-root (network connections, FS like PS list etc)
    char path[MAXPATHLEN*8], last_path_entry[MAXPATHLEN];
    m_Data->GetDirectoryFullHostsPathWithTrailingSlash(path);
    string entry = m_Data->DirectoryPathShort();
    
    char *s = strrchr(path, '/');
    if(!s) return;
    *s = 0;
    s = strrchr(path, '/');
    if(!s) return;
    strcpy(last_path_entry, s+1);
    *(s+1) = 0;
    if(!entry.empty()) // normal condition
        [self GoToGlobalHostsPathAsync:path select_entry:entry.c_str()];
    else // data has no info about how it's dir is named. seems that it's a VFS,
         // and currently junction file should be selected - it is a last part of a full path
        [self GoToGlobalHostsPathAsync:path select_entry:last_path_entry];
}

- (void) HandleReturnButton
{
    const auto entry = [m_View CurrentItem];
    if(entry == nullptr)
        return;
    
    // Handle directories.
    if(entry->IsDir())
    {
        if(!entry->IsDotDot() ||
           strcmp(m_Data->Listing()->RelativePath(), "/"))
        {
            string path = m_Data->FullPathForEntry(m_Data->RawIndexForSortIndex([m_View GetCursorPosition]));
            
            string curdirname;
            if(entry->IsDotDot()) // go to parent directory
                curdirname = m_Data->DirectoryPathShort();
            
            [self GoToRelativeAsync:path.c_str()
                          WithHosts:make_shared<vector<shared_ptr<VFSHost>>>(m_HostsStack)
                        SelectEntry:curdirname.c_str()
             ];
            return;
        }
        else
        { // dot-dot entry on some root dir - therefore it's some VFS like archive
            char junct[1024];
            strcpy(junct, m_HostsStack.back()->JunctionPath());
            assert(strlen(junct) > 0);
            if(IsPathWithTrailingSlash(junct)) junct[strlen(junct)-1] = 0;
            char junct_entry[1024];
            char directory_path[1024];
            strcpy(junct_entry, strrchr(junct, '/')+1);
            *(strrchr(junct, '/')+1) = 0;
            strcpy(directory_path, junct);
            
            auto hosts = make_shared<vector<shared_ptr<VFSHost>>>(m_HostsStack);
            hosts->pop_back();
            
            [self GoToRelativeAsync:directory_path WithHosts:hosts SelectEntry:junct];
            
            return;
        }
    }
    else
    { // VFS stuff here
        string path = m_Data->FullPathForEntry(m_Data->RawIndexForSortIndex([m_View GetCursorPosition]));
        shared_ptr<VFSArchiveHost> arhost = make_shared<VFSArchiveHost>(path.c_str(), m_HostsStack.back());
        if(arhost->Open() >= 0)
        {
            m_HostsStack.push_back(arhost);
            [self GoToRelativeToHostAsync:"/" select_entry:0];
            return;
        }
    }
    
    // need more sophisticated executable handling here
    if([self GetCurrentVFSHost]->IsNativeFS() && IsEligbleToTryToExecuteInConsole(*entry))
    {
        auto path = [self GetCurrentDirectoryPathRelativeToHost];
        [m_WindowController RequestTerminalExecution:entry->Name() at:path.c_str()];
        return;
    }
    
    // If previous code didn't handle current item,
    // open item with the default associated application.
    [self HandleShiftReturnButton];
}

- (void) RefreshDirectory
{
    if(m_Data == nullptr || m_View == nil)
        return; // guard agains calls from init process
    
    // going async here
    if(!m_DirectoryLoadingQ->Empty())
        return; //reducing overhead
    
    string dirpath = m_Data->DirectoryPathWithTrailingSlash();
    
    m_DirectoryReLoadingQ->Run(^(SerialQueue _q){
        shared_ptr<VFSListing> listing;
        int ret = m_HostsStack.back()->FetchDirectoryListing(dirpath.c_str(),&listing, m_VFSFetchingFlags, ^{ return _q->IsStopped(); });
        if(ret >= 0)
        {
            dispatch_to_main_queue( ^{
                GenericCursorPersistance pers(m_View, m_Data);
                
                m_Data->ReLoad(listing);
                
                if(![self CheckAgainstRequestedSelection])
                    pers.Restore();

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

- (void) ClearFastSearchFiltering
{
    if(m_View == nil || m_Data == nullptr)
        return;
    
    GenericCursorPersistance pers(m_View, m_Data);
    
    if(m_Data->ClearTextFiltering()) {
        pers.Restore();
        [m_View setNeedsDisplay:true];
    }
    
    if(m_QuickSearchPopupView != nil) {
        [m_QuickSearchPopupView PopOut];
        m_QuickSearchPopupView = nil;
    }
}

- (void)HandleQuickSearchSoft: (NSString*) _key
{
    _key = [_key decomposedStringWithCanonicalMapping];
    uint64_t currenttime = GetTimeInNanoseconds();
    if(_key != nil)
    {
        // update soft filtering
        PanelDataTextFiltering filtering = m_Data->SoftFiltering();
        
        if(m_QuickSearchLastType + g_FastSeachDelayTresh < currenttime ||
           filtering.text == nil)
        {
            filtering.text = _key; // flush
            m_QuickSearchOffset = 0;
        }
        else
            filtering.text = [filtering.text stringByAppendingString:_key]; // append
        
        filtering.type = m_QuickSearchWhere;
        filtering.ignoredotdot = false;
        m_Data->SetSoftFiltering(filtering);
    }
    m_QuickSearchLastType = currenttime;
    
    if(m_Data->SoftFiltering().text == nil)
        return;
    
    if(!m_Data->EntriesBySoftFiltering().empty())
    {
        if(m_QuickSearchOffset >= m_Data->EntriesBySoftFiltering().size())
            m_QuickSearchOffset = (unsigned)m_Data->EntriesBySoftFiltering().size() - 1;
        [m_View SetCursorPosition:m_Data->EntriesBySoftFiltering()[m_QuickSearchOffset]];
    }
    
    if(m_QuickSearchTypingView)
    {
        if(!m_QuickSearchPopupView)
        {
            PanelFastSearchPopupViewController *view = [PanelFastSearchPopupViewController new];
            m_QuickSearchPopupView = view;
            __weak PanelController *weakself = self;
            [view SetHandlers:^{[weakself HandleFastSearchPrevious];}
                         Next:^{[weakself HandleFastSearchNext];}];
            [view PopUpWithView:m_View];
        }

        [m_QuickSearchPopupView UpdateWithString:m_Data->SoftFiltering().text
                                         Matches:(int)m_Data->EntriesBySoftFiltering().size()];
    }
}

- (void)HandleQuickSearchHard: (NSString*) _key
{
    _key = [_key decomposedStringWithCanonicalMapping];

    PanelDataHardFiltering filtering = m_Data->HardFiltering();
    
    if(_key != nil)
    {
        // update hard filtering
        if(filtering.text.text == nil)
            filtering.text.text = _key;
        else
            filtering.text.text = [filtering.text.text stringByAppendingString:_key];
    }

    if(filtering.text.text == nil)
        return;
    
    GenericCursorPersistance pers(m_View, m_Data);

    filtering.text.type = m_QuickSearchWhere;
    filtering.text.clearonnewlisting = true;
    m_Data->SetHardFiltering(filtering);

    pers.Restore();
    
    // for convinience - if we have ".." and cursor is on it - move it to first element (if any)
    if((m_VFSFetchingFlags & VFSHost::F_NoDotDot) == 0 &&
       [m_View GetCursorPosition] == 0 &&
        m_Data->SortedDirectoryEntries().size() >= 2)
        [m_View SetCursorPosition:1];
    
    [m_View setNeedsDisplay:true];
    
    if(m_QuickSearchTypingView) { // update typing UI
        if(!m_QuickSearchPopupView) {
            PanelFastSearchPopupViewController *view = [PanelFastSearchPopupViewController new];
            m_QuickSearchPopupView = view;
            [view PopUpWithView:m_View];
        }

        int total = (int)m_Data->SortedDirectoryEntries().size();
        if((m_VFSFetchingFlags & VFSHost::F_NoDotDot) == 0)
            total--;
        
        [m_QuickSearchPopupView UpdateWithString:filtering.text.text Matches:total];
    }
}

- (void)HandleFastSearchPrevious
{
    if(m_QuickSearchOffset > 0)
        m_QuickSearchOffset--;
    [self HandleQuickSearchSoft:nil];
}

- (void)HandleFastSearchNext
{
    m_QuickSearchOffset++;
    [self HandleQuickSearchSoft:nil];
}

- (bool) ProcessKeyDown:(NSEvent *)event; // return true if key was processed
{
    NSString*  const character   = [event charactersIgnoringModifiers];
    NSUInteger const modif       = [event modifierFlags];

    bool fast_search_handling = IsQuickSearchModifier(modif, m_QuickSearchMode) &&
                                IsQuickSearchStringCharacter(character);
    if( fast_search_handling ) {
        if(m_QuickSearchIsSoftFiltering)
            [self HandleQuickSearchSoft:character];
        else
            [self HandleQuickSearchHard:character];
    }
    
    [self ClearSelectionRequest]; // on any key press we clear entry selection request if any
    
    if ( [character length] != 1 ) return false;
    unichar const unicode        = [character characterAtIndex:0];
    unsigned short const keycode = [event keyCode];

    switch (unicode) {
        case NSHomeFunctionKey:       [m_View HandleFirstFile];     return true;
        case NSEndFunctionKey:        [m_View HandleLastFile];      return true;
        case NSPageDownFunctionKey:   [m_View HandleNextPage];      return true;
        case NSPageUpFunctionKey:     [m_View HandlePrevPage];      return true;
        case NSLeftArrowFunctionKey:  [m_View HandlePrevColumn];    return true;
        case NSRightArrowFunctionKey: [m_View HandleNextColumn];    return true;
        case NSUpArrowFunctionKey:
            if(IsQuickSearchModifierForArrows(modif, m_QuickSearchMode))
                [self HandleFastSearchPrevious];
            else
                [m_View HandlePrevFile];
            return true;
        case NSDownArrowFunctionKey:
            if(IsQuickSearchModifierForArrows(modif, m_QuickSearchMode))
                [self HandleFastSearchNext];
            else
                [m_View HandleNextFile];
            return true;
    }
    
    if(keycode == 53) { // Esc button
        [self CancelBackgroundOperations];
        [[self GetParentWindow] CloseOverlay:self];
        m_BriefSystemOverview = nil;
        m_QuickLook = nil;
        [self ClearFastSearchFiltering];
        return true;
    }
    if(keycode == 35 ) // 'P' button
    {
        NSUInteger modif = [event modifierFlags];
        if( (modif&NSDeviceIndependentModifierFlagsMask) == (NSFunctionKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask))
        {
            auto path = VFSPathStack::SecretFunction___CreateVFSPSPath();
            [self AsyncGoToVFSPathStack:path withFlags:0 andFocus:""];
            return true;
        }
    }
    
    // handle RETURN manually, to prevent annoying by menu highlighting by hotkey
    if(unicode == NSCarriageReturnCharacter) {
        NSUInteger modif = [event modifierFlags] & NSDeviceIndependentModifierFlagsMask;
        modif &= ~NSAlphaShiftKeyMask; // exclude CapsLock from our decision process
        if( modif == 0              ) [self HandleReturnButton];
        if( modif == NSShiftKeyMask ) [self HandleShiftReturnButton];
        if( modif == (NSShiftKeyMask|NSAlternateKeyMask)) [self HandleCalculateSizes];
        return true;
    }
    
    if(fast_search_handling)
        return true;
    
    return false;
}

- (void) HandleBriefSystemOverview
{
    if(m_BriefSystemOverview)
    {
        [[self GetParentWindow] CloseOverlay:self];
        m_BriefSystemOverview = nil;
        return;
    }
    m_BriefSystemOverview = [[self GetParentWindow] RequestBriefSystemOverview:self];
    [self UpdateBriefSystemOverview];
}

- (void) HandleFileView // F3
{
    // Close quick preview, if it is open.
    if(m_QuickLook) {
        [[self GetParentWindow] CloseOverlay:self];
        m_QuickLook = nil;
        return;
    }
    
    m_QuickLook = [[self GetParentWindow] RequestQuickLookView:self];
    [self OnCursorChanged];
}

- (void) HandleCalculateSizes
{
    auto complet = ^(const char* _sub_dir, uint64_t _size) {
        string sub_dir = _sub_dir;
        dispatch_to_main_queue(^{
            if(m_Data->SetCalculatedSizeForDirectory(sub_dir.c_str(), _size))
                [m_View setNeedsDisplay];
        });
    };
    
    string current_dir = m_Data->DirectoryPathWithTrailingSlash();    
    __block auto sub_dir_names = self.GetSelectedEntriesOrFocusedEntryWithDotDot;
    m_DirectorySizeCountingQ->Run( ^(SerialQueue _q){
        m_HostsStack.back()->CalculateDirectoriesSizes(move(sub_dir_names),
                                                       current_dir,
                                                       ^bool { return _q->IsStopped(); },
                                                       complet);
    });
}

- (void) ModifierFlagsChanged:(unsigned long)_flags // to know if shift or something else is pressed
{
    [m_View ModifierFlagsChanged:_flags];

    if(m_QuickSearchIsSoftFiltering)
        [self ClearFastSearchFiltering];
}

- (void) AttachToControls:(NSProgressIndicator*)_indicator eject:(NSButton*)_eject share:(NSButton*)_share
{
    m_SpinningIndicator = _indicator;
    m_EjectButton = _eject;
    m_ShareButton = _share;
    
    m_IsAnythingWorksInBackground = false;
    [m_SpinningIndicator stopAnimation:nil];
    [self UpdateSpinningIndicator];
    [self UpdateEjectButton];
    
    [m_EjectButton setTarget:self];
    [m_EjectButton setAction:@selector(OnEjectButton:)];
    
    [m_ShareButton setTarget:self];
    [m_ShareButton setAction:@selector(OnShareButton:)];
}

- (void) SetWindowController:(MainWindowController *)_cntrl
{
    m_WindowController = _cntrl;
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
                               if([m_SpinningIndicator isHidden])
                                   [m_SpinningIndicator setHidden:false];
                           }
                       });
    }
    else
    {
        [m_SpinningIndicator stopAnimation:nil];
        if(![m_SpinningIndicator isHidden])
            [m_SpinningIndicator setHidden:true];
        
    }
    
    m_IsAnythingWorksInBackground = is_anything_working;
}

- (void) UpdateEjectButton
{
    string path = m_Data->DirectoryPathWithoutTrailingSlash();
    bool should_be_hidden = !IsVolumeContainingPathEjectable(path.c_str());
    
    if([m_EjectButton isHidden] != should_be_hidden)
        [m_EjectButton setHidden:should_be_hidden];
}

- (PanelViewType) GetViewType
{
    return [m_View GetCurrentViewType];
}

- (PanelSortMode) GetUserSortMode
{
    return m_Data->SortMode();
}

- (PanelDataHardFiltering) GetUserHardFiltering
{
    return m_Data->HardFiltering();
}

- (void) RecoverFromInvalidDirectory
{
    // TODO: recovering to upper host needed
    char path[MAXPATHLEN];
    strcpy(path, m_Data->DirectoryPathWithoutTrailingSlash().c_str());
    if(GetFirstAvailableDirectoryFromPath(path))
//        [self GoToDirectory:path];
        [self GoToRelativeToHostAsync:path select_entry:0];
}

- (void) SelectAllEntries:(bool) _select
{
    m_Data->CustomFlagsSelectAllSorted(_select);
    [m_View setNeedsDisplay:true];
}

- (void) OnPathChanged:(int)_flags
{
    [self ResetUpdatesObservation:m_Data->DirectoryPathWithTrailingSlash()];
    [self ClearSelectionRequest];
    [self ClearFastSearchFiltering];
    [self SignalParentOfPathChanged];
    [self UpdateEjectButton];
    [self OnCursorChanged];
    [self UpdateBriefSystemOverview];
    
    if((_flags & PanelControllerNavigation::NoHistory) == 0) {
        auto listing = m_Data->DirectoryEntries().SharedPtr();
        m_History.Put(VFSPathStack::CreateWithVFSListing(listing));
    }
}

- (void) OnCursorChanged
{
    // need to update some UI here
    auto const *item = [m_View CurrentItem];
    if(item)
    {
        if(item->IsDotDot())
            [m_ShareButton setEnabled:m_Data->Stats().selected_entries_amount > 0];
        else
        {
            if(m_HostsStack.back()->IsNativeFS())
                [m_ShareButton setEnabled:true];
            else
                [m_ShareButton setEnabled:!item->IsDir() && item->Size() < [SharingService MaximumFileSizeForVFSShare]];
        }
    }
    else
        [m_ShareButton setEnabled:false];
    
    // update QuickLook if any
    if(m_QuickLook != nil)
        [m_QuickLook PreviewItem:[self GetCurrentFocusedEntryFilePathRelativeToHost]
                             vfs:m_HostsStack.back()];
}

- (MainWindowFilePanelState*) GetParentWindow
{
    NSView *parent = [m_View superview];
    while(parent && ![parent isKindOfClass: [MainWindowFilePanelState class]])
        parent = [parent superview];
    if(!parent) return nil;
    return (MainWindowFilePanelState*)parent;
}

- (void) SignalParentOfPathChanged
{
    [[self GetParentWindow] PanelPathChanged:self];
}

- (void)OnEjectButton:(id)sender
{
    if(m_Data)
        EjectVolumeContainingPath(m_Data->DirectoryPathWithoutTrailingSlash());
}

- (void) SelectEntriesByMask:(NSString*)_mask select:(bool)_select
{
    bool ignore_dirs = [NSUserDefaults.standardUserDefaults boolForKey:g_DefaultsGeneralIgnoreDirsOnMaskSel];
    if(m_Data->CustomFlagsSelectAllSortedByMask(_mask, _select, ignore_dirs))
        [m_View setNeedsDisplay:true];
}

- (void)OnShareButton:(id)sender
{
    if([SharingService IsCurrentlySharing])
        return;
    
    auto files = [self GetSelectedEntriesOrFocusedEntryWithoutDotDot];
    if(files.empty())
        return;
    
    [[SharingService new] ShowItems:move(files)
                              InDir:m_Data->DirectoryPathWithTrailingSlash()
                              InVFS:m_HostsStack.back()
                     RelativeToRect:[sender bounds]
                             OfView:sender
                      PreferredEdge:NSMinYEdge];
}

- (void) UpdateBriefSystemOverview
{
    if(m_BriefSystemOverview != nil)
        [m_BriefSystemOverview UpdateVFSTarget:[self GetCurrentDirectoryPathRelativeToHost].c_str()
                                          host:m_HostsStack.back()];
}

- (void) HandleItemsContextMenu
{
    const VFSListingItem* cur_focus = [m_View CurrentItem];
    if(!cur_focus || cur_focus->IsDotDot())
        return;
    
    vector<const VFSListingItem*> items;
    
    // 2 variants - currently focused item or all selected items (if focus is also selected)
    if(m_Data->Stats().selected_entries_amount == 0 || !cur_focus->CFIsSelected())
        items.push_back(cur_focus); // use focused item solely
    else
        for(auto &i: *m_Data->Listing()) // use selected items
            if(i.CFIsSelected())
                items.push_back(&i);

    [[self GetParentWindow] RequestContextMenuOn:items
                                            path:[self GetCurrentDirectoryPathRelativeToHost].c_str()
                                             vfs:m_HostsStack.back()
                                          caller:self];
}

@end
