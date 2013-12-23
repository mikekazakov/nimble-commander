//
//  PanelController.m
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#import <string>
#import "PanelController.h"
#import "FSEventsDirUpdate.h"
#import "Common.h"
#import "MainWindowController.h"
#import "QuickPreview.h"
#import "MainWindowFilePanelState.h"
#import "filesysinfo.h"
#import "FileMask.h"
#import "PanelFastSearchPopupViewController.h"
#import "PanelAux.h"
#import "SharingService.h"
#import "PanelFastSearchPopupViewController.h"
#import "BriefSystemOverview.h"

#define ISMODIFIER(_v) ( (modif&NSDeviceIndependentModifierFlagsMask) == (_v) )

static const uint64_t g_FastSeachDelayTresh = 5000000000; // 5 sec

inline static bool IsEligbleToTryToExecuteInConsole(const VFSListingItem& _item)
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

@implementation PanelController


- (id) init
{
    self = [super init];
    if(self) {
        // Initialization code here.
        m_UpdatesObservationTicket = 0;
        m_FastSearchLastType = 0;
        m_FastSearchOffset = 0;
        m_IsAnythingWorksInBackground = false;
        m_DirectorySizeCountingQ = make_shared<SerialQueueT>("com.example.paneldirsizecounting");
        m_DirectoryLoadingQ = make_shared<SerialQueueT>("com.example.paneldirsizecounting");
        m_DirectoryReLoadingQ = make_shared<SerialQueueT>("com.example.paneldirreloading");
        m_DelayedSelection.isvalid = false;
        
        m_HostsStack.push_back( VFSNativeHost::SharedHost() );
        
        __weak PanelController* weakself = self;
        auto on_change = ^{
            dispatch_to_main_queue( ^{
                [weakself UpdateSpinningIndicator];
            });
        };
        m_DirectorySizeCountingQ->OnChange(on_change);
        m_DirectoryReLoadingQ->OnChange(on_change);
        m_DirectoryLoadingQ->OnChange(on_change);
    }

    return self;
}

// without calling SetData:0 PanelController may not dealloc and crash later because of hanging obverve handlers
- (void) SetData:(PanelData*)_data
{
    m_Data = _data;
    [self CancelBackgroundOperations];
    
    if(m_Data == 0)
    {
        // we're deallocing - flush current observing if any
        if(m_UpdatesObservationHost.get() && m_UpdatesObservationTicket)
        {
            m_UpdatesObservationHost->StopDirChangeObserving(m_UpdatesObservationTicket);
            m_UpdatesObservationHost.reset();
            m_UpdatesObservationTicket = 0;
        }
    }
}

- (void) SetView:(PanelView*)_view
{
    m_View = _view;
}

- (void) LoadViewState:(NSDictionary *)_state
{
    PanelSortMode mode = m_Data->GetCustomSortMode();
    
    mode.sep_dirs = [[_state valueForKey:@"SeparateDirectories"] boolValue];
    mode.show_hidden = [[_state valueForKey:@"ViewHiddenFiles"] boolValue];
    mode.case_sens = [[_state valueForKey:@"CaseSensitiveComparison"] boolValue];
    mode.numeric_sort = [[_state valueForKey:@"NumericSort"] boolValue];
    mode.sort = (PanelSortMode::Mode)[[_state valueForKey:@"SortMode"] integerValue];
    [self ChangeSortingModeTo:mode];
                                      
    [m_View ToggleViewType:(PanelViewType)[[_state valueForKey:@"ViewMode"] integerValue]];
    
}

- (NSDictionary *) SaveViewState
{
    PanelSortMode mode = m_Data->GetCustomSortMode();
    
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:(mode.sep_dirs != false)], @"SeparateDirectories",
        [NSNumber numberWithBool:(mode.show_hidden != false)], @"ViewHiddenFiles",
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
        char path[MAXPATHLEN];
        m_Data->GetDirectoryPathWithTrailingSlash(path);

        // non-default behaviour here: "/Abra/.." will produce "/Abra/" insted of default-way "/"
        if(!item->IsDotDot())
            strcat(path, item->Name());

        // may go async here on non-native VFS
        PanelVFSFileWorkspaceOpener::Open(path, m_Data->Host());
    }
}

- (void) ChangeSortingModeTo:(PanelSortMode)_mode
{
    int curpos = [m_View GetCursorPosition];
    if(curpos >= 0)
    {
        int rawpos = m_Data->SortedDirectoryEntries()[curpos];
        m_Data->SetCustomSortMode(_mode);
        int newcurpos = m_Data->SortedIndexForRawIndex(rawpos);
        if(newcurpos >= 0)
        {
            [m_View SetCursorPosition:newcurpos];
        }
        else
        {
            // there's no such element in this representation
            if(curpos < m_Data->SortedDirectoryEntries().size())
                [m_View SetCursorPosition:curpos];
            else
                [m_View SetCursorPosition:(int)m_Data->SortedDirectoryEntries().size()-1];
        }
    }
    else
    {
        m_Data->SetCustomSortMode(_mode);
    }
    [m_View setNeedsDisplay:true];
}

- (void) MakeSortWith:(PanelSortMode::Mode)_direct Rev:(PanelSortMode::Mode)_rev
{
    PanelSortMode mode = m_Data->GetCustomSortMode(); // we don't want to change anything in sort params except the mode itself
    if(mode.sort != _direct)  mode.sort = _direct;
    else                      mode.sort = _rev;
    [self ChangeSortingModeTo:mode];
}

- (void) ToggleViewHiddenFiles
{
    PanelSortMode mode = m_Data->GetCustomSortMode();
    mode.show_hidden = !mode.show_hidden;
    [self ChangeSortingModeTo:mode];    
}

- (void) ToggleSeparateFoldersFromFiles
{
    PanelSortMode mode = m_Data->GetCustomSortMode();
    mode.sep_dirs = !mode.sep_dirs;
    [self ChangeSortingModeTo:mode];
}

- (void) ToggleCaseSensitiveComparison
{
    PanelSortMode mode = m_Data->GetCustomSortMode();
    mode.case_sens = !mode.case_sens;
    [self ChangeSortingModeTo:mode];
}

- (void) ToggleNumericComparison
{
    PanelSortMode mode = m_Data->GetCustomSortMode();
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

- (void) ResetUpdatesObservation:(const char *) _new_path
{
    if(m_UpdatesObservationHost.get() && m_UpdatesObservationTicket)
    {
        m_UpdatesObservationHost->StopDirChangeObserving(m_UpdatesObservationTicket);
        m_UpdatesObservationHost.reset();
    }

    m_UpdatesObservationTicket = m_HostsStack.back()->DirChangeObserve(_new_path, ^{ [self RefreshDirectory]; } );
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

- (int) FetchFlags
{
    bool show_dot_dot = [[NSUserDefaults standardUserDefaults] boolForKey:@"FilePanelsGeneralShowDotDotEntry"];
    return show_dot_dot ? 0 : VFSHost::F_NoDotDot;
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
        int ret = _hosts->back()->FetchDirectoryListing(_path, &listing, self.FetchFlags, 0);
        if(ret >= 0)
        {
            [self CancelBackgroundOperations]; // clean running operations if any
            m_HostsStack = *_hosts; // some overhead here, nevermind
            m_Data->Load(listing);
                    
            if(!_entry_name || !strlen(_entry_name)) // go into some sub-dir
                [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoSubDir
                               newcursor:0];
            else // go into dot-dot dir
                [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoParentDir
                               newcursor:max(m_Data->SortedIndexForName(_entry_name), 0)];
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
                        int ret = arhost->FetchDirectoryListing(path_buf, &listing, self.FetchFlags, 0);
                        if(ret >= 0)
                        {
                            [self CancelBackgroundOperations]; // clean running operations if any
                            m_HostsStack = *_hosts; // some overhead here, nevermind
                            m_HostsStack.push_back(arhost);
                            m_Data->Load(listing);
                            [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoOtherDir newcursor:0];
                            [self OnPathChanged:0];
                            return VFSError::Ok;
                        }
                    }
                }
            }
        }
    }

    return VFSError::GenericError;
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
            int ret = _hosts->back()->FetchDirectoryListing(path.c_str(), &listing, self.FetchFlags, ^{return _q->IsStopped();});
            if(ret >= 0)
            {
                [self CancelBackgroundOperations]; // clean running operations if any
                dispatch_to_main_queue( ^{
                    m_HostsStack = *_hosts; // some overhead here, nevermind
                    m_Data->Load(listing);
                    
                    if(entryname.empty()) // go into some sub-dir
                        [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoSubDir
                                       newcursor:0];
                    else // go into dot-dot dir
                        [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoParentDir
                                       newcursor:max(m_Data->SortedIndexForName(entryname.c_str()), 0)];
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
                            int ret = arhost->FetchDirectoryListing(path_buf, &listing, self.FetchFlags, ^{return _q->IsStopped();});
                            if(ret >= 0)
                            {
                                [self CancelBackgroundOperations]; // clean running operations if any
                                dispatch_to_main_queue( ^{
                                    m_HostsStack = *_hosts; // some overhead here, nevermind
                                    m_HostsStack.push_back(arhost);
                                    m_Data->Load(listing);
                                    [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoOtherDir newcursor:0];
                                    [self OnPathChanged:0];
                                });
                            }
                        }
                    }
                }
            }
        }
        
//        dispatch_to_main_queue( ^{[self NotifyDirectoryLoading:false];});
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
    char path[MAXPATHLEN*8], entry[MAXPATHLEN], last_path_entry[MAXPATHLEN];
    m_Data->GetDirectoryFullHostsPathWithTrailingSlash(path);
    m_Data->GetDirectoryPathShort(entry);
    
    char *s = strrchr(path, '/');
    if(!s) return;
    *s = 0;
    s = strrchr(path, '/');
    if(!s) return;
    strcpy(last_path_entry, s+1);
    *(s+1) = 0;
    if(strlen(entry) > 0) // normal condition
        [self GoToGlobalHostsPathAsync:path select_entry:entry];
    else // data has no info about how it's dir is named. seems that it's a VFS,
         // and currently junction file should be selected - it is a last part of a full path
        [self GoToGlobalHostsPathAsync:path select_entry:last_path_entry];
}

- (void) HandleReturnButton
{ // going async here
    int sort_pos = [m_View GetCursorPosition];
    if(sort_pos < 0)
        return;
    int raw_pos = m_Data->SortedDirectoryEntries()[sort_pos];
    
    const auto &entry = m_Data->DirectoryEntries()[raw_pos];
    
    // Handle directories.
    if(entry.IsDir())
    {
        if(!entry.IsDotDot() ||
           strcmp(m_Data->DirectoryEntries().RelativePath(), "/"))
        {
            char pathbuf[__DARWIN_MAXPATHLEN];
            m_Data->ComposeFullPathForEntry(raw_pos, pathbuf);
//            string path = string(pathbuf);
        
            string curdirname("");
            if(entry.IsDotDot())
            { // go to parent directory
                char curdirnamebuf[__DARWIN_MAXPATHLEN];
                m_Data->GetDirectoryPathShort(curdirnamebuf);
                curdirname = curdirnamebuf;
            }
            
            [self GoToRelativeAsync:pathbuf
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
//            if(strrchr(junct, '/') != junct)
                *(strrchr(junct, '/')+1) = 0;
            strcpy(directory_path, junct);
            
            auto hosts = make_shared<vector<shared_ptr<VFSHost>>>(m_HostsStack);
            hosts->pop_back();
            
            [self GoToRelativeAsync:directory_path WithHosts:hosts SelectEntry:junct_entry];
            
            return;
        }
    }
    else
    { // VFS stuff here
        char pathbuf[__DARWIN_MAXPATHLEN];
        m_Data->ComposeFullPathForEntry(raw_pos, pathbuf);
        shared_ptr<VFSArchiveHost> arhost = make_shared<VFSArchiveHost>(pathbuf, m_HostsStack.back());
        if(arhost->Open() >= 0)
        {
            m_HostsStack.push_back(arhost);
            [self GoToRelativeToHostAsync:"/" select_entry:0];
            return;
        }
    }
    
    // need more sophisticated executable handling here
    if([self GetCurrentVFSHost]->IsNativeFS() && IsEligbleToTryToExecuteInConsole(entry))
    {
        char pathbuf[__DARWIN_MAXPATHLEN];
        [self GetCurrentDirectoryPathRelativeToHost:pathbuf];
        [m_WindowController RequestTerminalExecution:entry.Name() at:pathbuf];
        return;
    }
    
    // If previous code didn't handle current item,
    // open item with the default associated application.
    [self HandleShiftReturnButton];
}

- (void) RefreshDirectory
{
    // going async here
    if(!m_DirectoryLoadingQ->Empty())
        return; //reducing overhead
    
    char dirpathbuf[MAXPATHLEN];
    m_Data->GetDirectoryPathWithTrailingSlash(dirpathbuf);
    string dirpath(dirpathbuf);
    
    m_DirectoryReLoadingQ->Run(^(SerialQueue _q){
        shared_ptr<VFSListing> listing;
        int ret = m_HostsStack.back()->FetchDirectoryListing(dirpath.c_str(),&listing, self.FetchFlags, ^{ return _q->IsStopped(); });
        if(ret >= 0)
        {
            dispatch_to_main_queue( ^{
                int oldcursorpos = [m_View GetCursorPosition];
                string oldcursorname;
                if(oldcursorpos >= 0 && [m_View CurrentItem] != 0)
                    oldcursorname = [m_View CurrentItem]->Name();
                
                m_Data->ReLoad(listing);
                
                if(![self CheckAgainstRequestedSelection]) {
                    int newcursorrawpos = m_Data->RawIndexForName(oldcursorname.c_str());
                    if( newcursorrawpos >= 0 ) {
                        [m_View SetCursorPosition:max(m_Data->SortedIndexForRawIndex(newcursorrawpos), 0)];
                    }
                    else {
                        if( oldcursorpos < m_Data->SortedDirectoryEntries().size() )
                            [m_View SetCursorPosition:oldcursorpos];
                        else
                            [m_View SetCursorPosition:int(m_Data->SortedDirectoryEntries().size() - 1)]; // assuming that any directory will have at leat ".."
                    }
                }

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

- (void)HandleFastSearch: (NSString*) _key
{
    _key = [_key decomposedStringWithCanonicalMapping];
    uint64_t currenttime = GetTimeInNanoseconds();
    if(_key != nil)
    {
        if(m_FastSearchLastType + g_FastSeachDelayTresh < currenttime || m_FastSearchString == nil)
        {
            m_FastSearchString = _key; // flush
            m_FastSearchOffset = 0;
        }
        else
            m_FastSearchString = [m_FastSearchString stringByAppendingString:_key]; // append
    }
    m_FastSearchLastType = currenttime;
    
    if(m_FastSearchString == nil)
        return;

    unsigned ind, range;
    bool found_any = m_Data->FindSuitableEntry( (__bridge CFStringRef) m_FastSearchString, m_FastSearchOffset, &ind, &range);
    if(found_any)
    {
        if(m_FastSearchOffset > range)
            m_FastSearchOffset = range;
            
        int pos = m_Data->SortedIndexForRawIndex(ind);
        if(pos >= 0)
            [m_View SetCursorPosition:pos];
    }

    if(!m_FastSearchPopupView)
    {
        m_FastSearchPopupView = [PanelFastSearchPopupViewController new];
        [m_FastSearchPopupView SetHandlers:^{[self HandleFastSearchPrevious];}
                                      Next:^{[self HandleFastSearchNext];}];
        [m_FastSearchPopupView PopUpWithView:m_View];
    }

    [m_FastSearchPopupView UpdateWithString:m_FastSearchString Matches:(found_any?range+1:0)];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, g_FastSeachDelayTresh+1000), dispatch_get_main_queue(),
                   ^{
                       if(m_FastSearchPopupView != nil)
                       {
                           uint64_t currenttime = GetTimeInNanoseconds();
                           if(m_FastSearchLastType + g_FastSeachDelayTresh <= currenttime)
                           {
                               [m_FastSearchPopupView PopOut];
                               m_FastSearchPopupView = nil;
                           }
                       }
                   });
}

- (void)HandleFastSearchPrevious
{
    if(m_FastSearchOffset > 0)
        m_FastSearchOffset--;
    [self HandleFastSearch:nil];
}

- (void)HandleFastSearchNext
{
    m_FastSearchOffset++;
    [self HandleFastSearch:nil];
}

- (bool) ProcessKeyDown:(NSEvent *)event; // return true if key was processed
{
    NSString*  const character = [event charactersIgnoringModifiers];

    NSUInteger const modif       = [event modifierFlags];

    bool fast_search_handling = false;
    if(ISMODIFIER(NSAlternateKeyMask) || ISMODIFIER(NSAlternateKeyMask|NSAlphaShiftKeyMask)) {
        [self HandleFastSearch:character];
        fast_search_handling = true;
    }
    
    [self ClearSelectionRequest]; // on any key press we clear entry selection request if any
    
    if ( [character length] != 1 ) return false;
    unichar const unicode        = [character characterAtIndex:0];
    unsigned short const keycode = [event keyCode];

    switch (unicode)
    {
        case NSHomeFunctionKey: [m_View HandleFirstFile]; return true;
        case NSEndFunctionKey:  [m_View HandleLastFile]; return true;
        case NSPageDownFunctionKey:      [m_View HandleNextPage]; return true;
        case NSPageUpFunctionKey:        [m_View HandlePrevPage]; return true;
        case NSLeftArrowFunctionKey:
            if(modif & NSCommandKeyMask) [m_View HandleFirstFile];
            else if(modif &  NSAlternateKeyMask); // now nothing wilh alt+left now
            else                         [m_View HandlePrevColumn];
            return true;
        case NSRightArrowFunctionKey:
            if(modif & NSCommandKeyMask) [m_View HandleLastFile];
            else if(modif &  NSAlternateKeyMask); // now nothing wilh alt+right now   
            else                         [m_View HandleNextColumn];
            return true;
        case NSUpArrowFunctionKey:
            if(modif & NSCommandKeyMask) [m_View HandlePrevPage];
            else if(modif & NSAlternateKeyMask) [self HandleFastSearchPrevious];
            else                         [m_View HandlePrevFile];
            return true;
        case NSDownArrowFunctionKey:
            if(modif & NSCommandKeyMask) [m_View HandleNextPage];
            else if(modif &  NSAlternateKeyMask) [self HandleFastSearchNext];
            else                         [m_View HandleNextFile];
            return true;
    }
    
    switch (keycode)
    {
        case 53: // Esc button
            [self CancelBackgroundOperations];
            [[self GetParentWindow] CloseOverlay:self];
            m_BriefSystemOverview = nil;
            m_QuickLook = nil;
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
    if (m_QuickLook != nil)
    { // Close quick preview, if it is open.
        [[self GetParentWindow] CloseOverlay:self];
        m_QuickLook = nil;
        return;
    }
    
    char dir[MAXPATHLEN];
    m_Data->GetDirectoryPathWithTrailingSlash(dir);
    
    if(m_Data->GetSelectedItemsCount())
    {
        auto files = m_Data->StringsFromSelectedEntries();
        [self StartDirectorySizeCountingFor:files InDir:dir IsDotDot:false];
    }
    else
    {
        auto const *item = [m_View CurrentItem];
        if (!item) return;
        if (item->IsDir())
        {
            bool dotdot = item->IsDotDot();
            [self StartDirectorySizeCountingFor:dotdot ? 0 :FlexChainedStringsChunk::AllocateWithSingleString(item->Name())
                                          InDir:dir
                                       IsDotDot:dotdot];
        }
        else
        {
            m_QuickLook = [[self GetParentWindow] RequestQuickLookView:self];
            [self OnCursorChanged];
        }
    }
}

- (void) StartDirectorySizeCountingFor:(FlexChainedStringsChunk *)_files InDir:(const char*)_dir IsDotDot:(bool)_isdotdot
{    
    string str(_dir);
    m_DirectoryReLoadingQ->Run(^(SerialQueue _q){
        // TODO: lock panel data?
        // guess it's better to move the following line into main thread
        // it may be a race condition with possible UB here. BAD!
        auto complet = ^(const char* _dir, uint64_t _size){
            if(m_Data->SetCalculatedSizeForDirectory(_dir, _size))
                [m_View setNeedsDisplay];
        };

        if(!_isdotdot)
            m_HostsStack.back()->CalculateDirectoriesSizes(_files, str, ^bool { return _q->IsStopped();  }, complet);
        else
            m_HostsStack.back()->CalculateDirectoryDotDotSize(str, ^bool { return _q->IsStopped(); }, complet);
    });
}

- (void) ModifierFlagsChanged:(unsigned long)_flags // to know if shift or something else is pressed
{
    [m_View ModifierFlagsChanged:_flags];
    
    if(m_FastSearchString != nil && (_flags & NSAlternateKeyMask) == 0)
    {
        // user was fast searching something, need to flush that string
        m_FastSearchString = nil;
        m_FastSearchOffset = 0;
        if(m_FastSearchPopupView != nil)
        {
            [m_FastSearchPopupView PopOut];
            m_FastSearchPopupView = nil;
        }
    }
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
    char path[MAXPATHLEN];
    m_Data->GetDirectoryPathWithoutTrailingSlash(path);
    bool should_be_hidden = !IsVolumeContainingPathEjectable(path);
    
    if([m_EjectButton isHidden] != should_be_hidden)
        [m_EjectButton setHidden:should_be_hidden];
}

- (PanelViewType) GetViewType
{
    return [m_View GetCurrentViewType];
}

- (PanelSortMode) GetUserSortMode
{
    return m_Data->GetCustomSortMode();
}

- (void) RecoverFromInvalidDirectory
{
    // TODO: recovering to upper host needed
    char path[MAXPATHLEN];
    m_Data->GetDirectoryPathWithoutTrailingSlash(path);
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
    char path[MAXPATHLEN];
    m_Data->GetDirectoryPathWithTrailingSlash(path);
    [self ResetUpdatesObservation:path];
    [self ClearSelectionRequest];   
    [self SignalParentOfPathChanged];
    [self UpdateEjectButton];
    [self OnCursorChanged];
    [self UpdateBriefSystemOverview];
    
    if((_flags & PanelControllerNavigation::NoHistory) == 0)
    {
//        auto const *item = [m_View CurrentItem];
        auto listring = m_Data->DirectoryEntries().SharedPtr();
        m_History.Put(VFSPathStack::CreateWithVFSListing(listring));
    }
}

- (void) OnCursorChanged
{
    // need to update some UI here
    auto const *item = [m_View CurrentItem];
    if(item)
    {
        if(item->IsDotDot())
            [m_ShareButton setEnabled:m_Data->GetSelectedItemsCount() > 0];
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
    {
        char path[MAXPATHLEN];
        if( [self GetCurrentFocusedEntryFilePathRelativeToHost:path] )
            [m_QuickLook PreviewItem:path vfs:m_HostsStack.back()];
    }
    
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        char path[MAXPATHLEN];
        m_Data->GetDirectoryPathWithoutTrailingSlash(path); // not thread-safe, potentialy may cause problems, but not likely
        EjectVolumeContainingPath(path);
    });
}

- (void) SelectEntriesByMask:(NSString*)_mask select:(bool)_select
{
    bool ignore_dirs = [[NSUserDefaults standardUserDefaults] boolForKey:@"FilePanelsGeneralIgnoreDirectoriesOnSelectionWithMask"];
    if(m_Data->CustomFlagsSelectAllSortedByMask(_mask, _select, ignore_dirs))
        [m_View setNeedsDisplay:true];
}

- (void)OnShareButton:(id)sender
{
    if([SharingService IsCurrentlySharing])
        return;
    
    if(FlexChainedStringsChunk *files = [self GetSelectedEntriesOrFocusedEntryWithoutDotDot])
    {
        char current_dir[MAXPATHLEN];
        m_Data->GetDirectoryPathWithTrailingSlash(current_dir);
        [[SharingService new] ShowItems:files
                InDir:current_dir
                InVFS:m_HostsStack.back()
       RelativeToRect:[sender bounds]
               OfView:sender
        PreferredEdge:NSMinYEdge];
    }
}

- (void) UpdateBriefSystemOverview
{
    if(m_BriefSystemOverview != nil)
    {
        char path[MAXPATHLEN];
        if( [self GetCurrentDirectoryPathRelativeToHost:path] )
            [m_BriefSystemOverview UpdateVFSTarget:path host:m_HostsStack.back()];
    }
}

- (void) HandleItemsContextMenu
{
    const VFSListingItem* cur_focus = [m_View CurrentItem];
    if(!cur_focus || cur_focus->IsDotDot())
        return;
    
    vector<const VFSListingItem*> items;
    
    // 2 variants - currently focused item or all selected items (if focus is also selected)
    if(m_Data->GetSelectedItemsCount() == 0 || !cur_focus->CFIsSelected())
    { // use focused items solely
        items.push_back(cur_focus);
    }
    else
    { // use selected items
        auto &listing = m_Data->DirectoryEntries();
        for(int i = 0, e = listing.Count(); i!=e; ++i)
            if(listing[i].CFIsSelected())
                items.push_back(&listing[i]);
    }

    char path[MAXPATHLEN];
    if( [self GetCurrentDirectoryPathRelativeToHost:path] )
        [[self GetParentWindow] RequestContextMenuOn:items
                                                path:path
                                                 vfs:m_HostsStack.back()
                                              caller:self];
}

@end
