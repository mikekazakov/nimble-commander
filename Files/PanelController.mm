//
//  PanelController.m
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//
#import <string>
#import "PanelController.h"
#import "PanelController+DataAccess.h"
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

static const uint64_t g_FastSeachDelayTresh = 5000000000; // 5 sec

@implementation PanelController


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
        m_UpdatesObservationTicket = 0;
        m_FastSearchLastType = 0;
        m_FastSearchOffset = 0;
        m_IsStopDirectorySizeCounting = false;
        m_IsStopDirectoryLoading = false;
        m_IsStopDirectoryReLoading = false;
        m_IsDirectorySizeCounting = false;
        m_IsAnythingWorksInBackground = false;
        m_IsDirectoryLoading = false;
        m_IsDirectoryReLoading = false;
        m_DirectorySizeCountingQ = dispatch_queue_create("com.example.paneldirsizecounting", 0);
        m_DirectoryLoadingQ = dispatch_queue_create("com.example.paneldirloading", 0);
        m_DirectoryReLoadingQ = dispatch_queue_create("com.example.paneldirreloading", 0);
        m_DelayedSelection.isvalid = false;
        
        m_HostsStack.push_back( VFSNativeHost::SharedHost() );
    }

    return self;
}

- (void) dealloc
{
    if(m_DirectorySizeCountingQ)
        dispatch_release(m_DirectorySizeCountingQ);
    if(m_DirectoryLoadingQ)
        dispatch_release(m_DirectoryLoadingQ);
    if(m_DirectoryReLoadingQ)
        dispatch_release(m_DirectoryReLoadingQ);
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
    [self setView:_view]; // do we need it?
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

- (void) RequestActivation
{
    [[self GetParentWindow] ActivatePanelByController:self];
}

- (void) HandleShiftReturnButton
{
    char path[MAXPATHLEN];
    int pos = [m_View GetCursorPosition];
    if(pos >= 0)
    {
        int rawpos = m_Data->SortPosToRawPos(pos);
        const auto &ent = m_Data->EntryAtRawPosition(rawpos);

        m_Data->GetDirectoryPathWithTrailingSlash(path);
        if(!ent.IsDotDot())
            strcat(path, ent.Name());
        
        if(m_Data->Host()->IsNativeFS())
        {
            bool success = [[NSWorkspace sharedWorkspace]
                            openFile:[NSString stringWithUTF8String:path]];
            if (!success) NSBeep();
        }
        else
            PanelVFSFileWorkspaceOpener::Open(path, m_Data->Host()); // going async here
    }
}

- (void) ChangeSortingModeTo:(PanelSortMode)_mode
{
    int curpos = [m_View GetCursorPosition];
    if(curpos >= 0)
    {
        int rawpos = m_Data->SortedDirectoryEntries()[curpos];
        m_Data->SetCustomSortMode(_mode);
        int newcurpos = m_Data->FindSortedEntryIndex(rawpos);
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

- (void) FlushStopFlags
{
    m_IsStopDirectorySizeCounting = true;
    m_IsStopDirectoryLoading = true;
    m_IsStopDirectoryReLoading = true;
}

- (void) GoToRelativeToHostAsync:(const char*) _path select_entry:(const char*) _entry
{
    [self GoToRelativeAsync:_path
                  WithHosts:std::make_shared<std::vector<std::shared_ptr<VFSHost>>>(m_HostsStack)
                SelectEntry:_entry];
}

- (int) GoToRelativeToHostSync:(const char*) _path
{
    return [self GoToRelativeSync:_path
                        WithHosts:std::make_shared<std::vector<std::shared_ptr<VFSHost>>>(m_HostsStack)
                      SelectEntry:0];
}

- (int) FindSortIndexForEntryOrZero:(const char*) _entry
{
    int sort = 0;
    int raw = m_Data->FindEntryIndex(_entry);

    if(raw >= 0)
        sort = m_Data->FindSortedEntryIndex(raw);
    if(sort < 0)
        sort = 0;
    
    return sort;
}

- (int) FetchFlags
{
    bool show_dot_dot = [[NSUserDefaults standardUserDefaults] boolForKey:@"FilePanelsGeneralShowDotDotEntry"];
    return show_dot_dot ? 0 : VFSHost::F_NoDotDot;
}

- (int) GoToRelativeSync:(const char*) _path
                WithHosts:(std::shared_ptr<std::vector<std::shared_ptr<VFSHost>>>)_hosts
              SelectEntry:(const char*) _entry_name
{
    if(m_IsDirectoryLoading)
        m_IsStopDirectoryLoading = true;

    // 1st - try to use last host with this path
    if(_hosts->back()->IsDirectory(_path, 0, 0))
    { // easy - just go there
        std::shared_ptr<VFSListing> listing;
        int ret = _hosts->back()->FetchDirectoryListing(_path, &listing, self.FetchFlags, 0);
        if(ret >= 0)
        {
            [self FlushStopFlags]; // clean running operations if any
            m_HostsStack = *_hosts; // some overhead here, nevermind
            m_Data->Load(listing);
                    
            if(!_entry_name || !strlen(_entry_name)) // go into some sub-dir
                [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoSubDir
                               newcursor:0];
            else // go into dot-dot dir
                [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoParentDir
                               newcursor:[self FindSortIndexForEntryOrZero:_entry_name]];
            [self OnPathChanged];
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
                std::shared_ptr<VFSArchiveHost> arhost = std::make_shared<VFSArchiveHost>(valid_path, _hosts->back());
                if(arhost->Open() >= 0)
                {
                    strcpy(path_buf, path_buf + strlen(valid_path));
                    if(arhost->IsDirectory(path_buf, 0, 0))
                    { // yeah, going here!
                        std::shared_ptr<VFSListing> listing;
                        int ret = arhost->FetchDirectoryListing(path_buf, &listing, self.FetchFlags, 0);
                        if(ret >= 0)
                        {
                            [self FlushStopFlags]; // clean running operations if any
                            m_HostsStack = *_hosts; // some overhead here, nevermind
                            m_HostsStack.push_back(arhost);
                            m_Data->Load(listing);
                            [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoOtherDir newcursor:0];
                            [self OnPathChanged];
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
                 WithHosts:(std::shared_ptr<std::vector<std::shared_ptr<VFSHost>>>)_hosts
               SelectEntry:(const char*) _entry_name
{
    std::string path = std::string(_path);
    
    std::string entryname = std::string(_entry_name ? _entry_name : "");
    
//    if(m_IsDirectoryLoading)
//    m_IsStopDirectoryLoading = true;
    [self FlushStopFlags];
    
//    if(m_IsStopDirectoryLoading)
    dispatch_async(m_DirectoryLoadingQ, ^{ m_IsStopDirectoryLoading = false; } );
    
    dispatch_async(m_DirectoryLoadingQ, ^{
        dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryLoading:true];});
        
        // 1st - try to use last host with this path
        if(_hosts->back()->IsDirectory(path.c_str(), 0, 0))
        { // easy - just go there
            std::shared_ptr<VFSListing> listing;
            int ret = _hosts->back()->FetchDirectoryListing(path.c_str(), &listing, self.FetchFlags, ^{return m_IsStopDirectoryLoading;});
            if(ret >= 0)
            {
                [self FlushStopFlags]; // clean running operations if any
                dispatch_async(dispatch_get_main_queue(), ^{
                    m_HostsStack = *_hosts; // some overhead here, nevermind
                    m_Data->Load(listing);
                    
                    if(entryname.empty()) // go into some sub-dir
                        [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoSubDir
                                       newcursor:0];
                    else // go into dot-dot dir
                        [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoParentDir
                                       newcursor:[self FindSortIndexForEntryOrZero:entryname.c_str()]];
                    [self OnPathChanged];
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
                    dispatch_async(dispatch_get_main_queue(), ^{ [alert runModal]; });
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
                    std::shared_ptr<VFSArchiveHost> arhost = std::make_shared<VFSArchiveHost>(valid_path, _hosts->back());
                    if(arhost->Open() >= 0)
                    {
                        strcpy(path_buf, path_buf + strlen(valid_path));
                        if(arhost->IsDirectory(path_buf, 0, 0))
                        { // yeah, going here!
                            std::shared_ptr<VFSListing> listing;
                            int ret = arhost->FetchDirectoryListing(path_buf, &listing, self.FetchFlags, ^{return m_IsStopDirectoryLoading;});
                            if(ret >= 0)
                            {
                                [self FlushStopFlags]; // clean running operations if any
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    m_HostsStack = *_hosts; // some overhead here, nevermind
                                    m_HostsStack.push_back(arhost);
                                    m_Data->Load(listing);
                                    [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoOtherDir newcursor:0];
                                    [self OnPathChanged];
                                });
                            }
                        }
                    }
                }
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryLoading:false];});
    });
}

- (bool) GetCommonHostsStackForPath:(const char*) _path rest:(char*) _rest hosts:(std::shared_ptr<std::vector<std::shared_ptr<VFSHost>>>&) _hosts
{
    // no blocking ops here, can call from main thread
    // TODO later: here we assume that top-level host should began with '', but networks vfs will operate with other format
    if(m_HostsStack.empty()) return false;
    assert( strcmp(m_HostsStack[0]->JunctionPath(), "") == 0 );
    
    std::shared_ptr<std::vector<std::shared_ptr<VFSHost>>> hosts = std::make_shared<std::vector<std::shared_ptr<VFSHost>>>();

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
    char rest[MAXPATHLEN*8];
    std::shared_ptr<std::vector<std::shared_ptr<VFSHost>>> stack;
    if([self GetCommonHostsStackForPath:_path rest:rest hosts:stack])
    {
        [self GoToRelativeAsync:rest WithHosts:stack SelectEntry:_entry];
    }
    else
    {
        stack = std::make_shared<std::vector<std::shared_ptr<VFSHost>>>();
        stack->push_back(VFSNativeHost::SharedHost());
        [self GoToRelativeAsync:_path WithHosts:stack SelectEntry:_entry];
    }
}

- (int) GoToGlobalHostsPathSync:(const char*) _path
{
    char rest[MAXPATHLEN*8];
    std::shared_ptr<std::vector<std::shared_ptr<VFSHost>>> stack;
    if([self GetCommonHostsStackForPath:_path rest:rest hosts:stack])
    {
        return [self GoToRelativeSync:rest WithHosts:stack SelectEntry:0];
    }
    else
    {
        stack = std::make_shared<std::vector<std::shared_ptr<VFSHost>>>();
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
    // Handle directories.
    if (m_Data->DirectoryEntries()[raw_pos].IsDir())
    {
        if(!m_Data->DirectoryEntries()[raw_pos].IsDotDot() ||
           strcmp(m_Data->DirectoryEntries().RelativePath(), "/"))
        {
            char pathbuf[__DARWIN_MAXPATHLEN];
            m_Data->ComposeFullPathForEntry(raw_pos, pathbuf);
//            std::string path = std::string(pathbuf);
        
            std::string curdirname("");
            if( m_Data->DirectoryEntries()[raw_pos].IsDotDot())
            { // go to parent directory
                char curdirnamebuf[__DARWIN_MAXPATHLEN];
                m_Data->GetDirectoryPathShort(curdirnamebuf);
                curdirname = curdirnamebuf;
            }
            
            [self GoToRelativeAsync:pathbuf
                          WithHosts:std::make_shared<std::vector<std::shared_ptr<VFSHost>>>(m_HostsStack)
                        SelectEntry:curdirname.c_str()
             ];
            return;
        }
        else
        { // dot-dot entry on some root dir - therefore it's some VFS like archive
            char junct[1024];
            strcpy(junct, m_HostsStack.back()->JunctionPath());
            assert(strlen(junct) > 0);
            if( junct[strlen(junct)-1] == '/' ) junct[strlen(junct)-1] = 0;
            char junct_entry[1024];
            char directory_path[1024];
            strcpy(junct_entry, strrchr(junct, '/')+1);
//            if(strrchr(junct, '/') != junct)
                *(strrchr(junct, '/')+1) = 0;
            strcpy(directory_path, junct);
            
            auto hosts = std::make_shared<std::vector<std::shared_ptr<VFSHost>>>(m_HostsStack);
            hosts->pop_back();
            
            [self GoToRelativeAsync:directory_path WithHosts:hosts SelectEntry:junct_entry];
            
            return;
        }
    }
    else
    { // VFS stuff here
        char pathbuf[__DARWIN_MAXPATHLEN];
        m_Data->ComposeFullPathForEntry(raw_pos, pathbuf);
        std::shared_ptr<VFSArchiveHost> arhost = std::make_shared<VFSArchiveHost>(pathbuf, m_HostsStack.back());
        if(arhost->Open() >= 0)
        {
            m_HostsStack.push_back(arhost);
            [self GoToRelativeToHostAsync:"/" select_entry:0];
            return;
        }
    }
    
    // If previous code didn't handle current item,
    // open item with the default associated application.
    [self HandleShiftReturnButton];
}

- (void) RefreshDirectory
{ // going async here
    
    if(m_IsDirectoryLoading)
        return; //reducing overhead
    
    char dirpathbuf[MAXPATHLEN];
    m_Data->GetDirectoryPathWithTrailingSlash(dirpathbuf);
    std::string dirpath(dirpathbuf);
    
    int oldcursorpos = [m_View GetCursorPosition];
    std::string oldcursorname = (oldcursorpos >= 0 ? [m_View CurrentItem]->Name() : "");
    
    if(m_IsStopDirectoryReLoading)
        dispatch_async(m_DirectoryReLoadingQ, ^{ m_IsStopDirectoryReLoading = false; } );
    dispatch_async(m_DirectoryReLoadingQ, ^{
        dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryReLoading:true];});

        
        std::shared_ptr<VFSListing> listing;
        int ret = m_HostsStack.back()->FetchDirectoryListing(dirpath.c_str(), &listing, self.FetchFlags, ^{return m_IsStopDirectoryReLoading;});
        if(ret >= 0)
        {
            m_IsStopDirectoryReLoading = true;
            dispatch_async(dispatch_get_main_queue(), ^{
                m_Data->ReLoad(listing);
                int newcursorrawpos = m_Data->FindEntryIndex(oldcursorname.c_str());
                if( newcursorrawpos >= 0 )
                {
                    int sortpos = m_Data->FindSortedEntryIndex(newcursorrawpos);
                    [m_View SetCursorPosition:sortpos >= 0 ? sortpos : 0];
                }
                else
                {
                    if( oldcursorpos < m_Data->SortedDirectoryEntries().size() )
                        [m_View SetCursorPosition:oldcursorpos];
                    else
                        [m_View SetCursorPosition:int(m_Data->SortedDirectoryEntries().size() - 1)]; // assuming that any directory will have at leat ".."
                }                
            
                [self CheckAgainstRequestedSelection];
                [m_View setNeedsDisplay:true];
            });
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self RecoverFromInvalidDirectory];
            });
        }

        dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryReLoading:false];});
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
            
        int pos = m_Data->FindSortedEntryIndex(ind);
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

- (void)keyDown:(NSEvent *)event
{
    NSString*  const character = [event charactersIgnoringModifiers];

    NSUInteger const modif       = [event modifierFlags];
    
#define ISMODIFIER(_v) ( (modif&NSDeviceIndependentModifierFlagsMask) == (_v) )

    if(ISMODIFIER(NSAlternateKeyMask) || ISMODIFIER(NSAlternateKeyMask|NSAlphaShiftKeyMask))
        [self HandleFastSearch:character];
    
    [self ClearSelectionRequest]; // on any key press we clear entry selection request if any
    
    if ( [character length] != 1 ) return;
    unichar const unicode        = [character characterAtIndex:0];
    unsigned short const keycode = [event keyCode];

    switch (unicode)
    {
        case NSHomeFunctionKey: [m_View HandleFirstFile]; break;
        case NSEndFunctionKey:  [m_View HandleLastFile]; break;
        case NSPageDownFunctionKey:      [m_View HandleNextPage]; break;
        case NSPageUpFunctionKey:        [m_View HandlePrevPage]; break;            
        case NSLeftArrowFunctionKey:
            if(modif & NSCommandKeyMask) [m_View HandleFirstFile];
            else if(modif &  NSAlternateKeyMask); // now nothing wilh alt+left now
            else                         [m_View HandlePrevColumn];
            break;
        case NSRightArrowFunctionKey:
            if(modif & NSCommandKeyMask) [m_View HandleLastFile];
            else if(modif &  NSAlternateKeyMask); // now nothing wilh alt+right now   
            else                         [m_View HandleNextColumn];
            break;
        case NSUpArrowFunctionKey:
            if(modif & NSCommandKeyMask) [m_View HandlePrevPage];
            else if(modif & NSAlternateKeyMask) [self HandleFastSearchPrevious];
            else                         [m_View HandlePrevFile];
            break;
        case NSDownArrowFunctionKey:
            if(modif & NSCommandKeyMask) [m_View HandleNextPage];
            else if(modif &  NSAlternateKeyMask) [self HandleFastSearchNext];
            else                         [m_View HandleNextFile];
            break;
        case NSCarriageReturnCharacter: // RETURN key
            if(ISMODIFIER(NSShiftKeyMask)) [self HandleShiftReturnButton];
            else                           [self HandleReturnButton];
            break;
    }
    
    switch (keycode)
    {
        case 53: // Esc button
            [self CancelBackgroundOperations];
            [QuickPreview Hide];
            break;
    }
}

- (void) HandleFileView // F3
{
    // dummy for now. we need to analyze the selection and/or cursor position
    
    // Close quick preview, if it is open.
    if ([QuickPreview IsVisible])
    {
        [QuickPreview Hide];
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
            [QuickPreview Show];
            [m_View UpdateQuickPreview];
        }
    }
}

- (void) StartDirectorySizeCountingFor:(FlexChainedStringsChunk *)_files InDir:(const char*)_dir IsDotDot:(bool)_isdotdot
{    
    std::string str(_dir);
    dispatch_async(m_DirectorySizeCountingQ, ^{
        m_IsStopDirectorySizeCounting = false;
        dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectorySizeCounting:true];});
        // TODO: lock panel data?
        // guess it's better to move the following line into main thread
        // it may be a race condition with possible UB here. BAD!
        auto complet = ^(const char* _dir, uint64_t _size){
            if(m_Data->SetCalculatedSizeForDirectory(_dir, _size)){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [m_View setNeedsDisplay:true];
                });
            }
        };

        if(!_isdotdot)
            m_HostsStack.back()->CalculateDirectoriesSizes(_files, str, ^bool { return m_IsStopDirectorySizeCounting; }, complet);
        else
            m_HostsStack.back()->CalculateDirectoryDotDotSize(str, ^bool { return m_IsStopDirectorySizeCounting; }, complet);
        
        dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectorySizeCounting:false];});
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

- (void) NotifyDirectorySizeCounting:(bool) _is_running // true if task will start now, or false if it has just stopped
{
    m_IsDirectorySizeCounting = _is_running;
    [self UpdateSpinningIndicator];
}

- (void) NotifyDirectoryLoading:(bool) _is_running // true if task will start now, or false if it has just stopped
{
    m_IsDirectoryLoading = _is_running;
    [self UpdateSpinningIndicator];
}

- (void) NotifyDirectoryReLoading:(bool) _is_running // true if task will start now, or false if it has just stopped
{
    m_IsDirectoryReLoading = _is_running;
    [self UpdateSpinningIndicator];
}

- (void) CancelBackgroundOperations
{
    m_IsStopDirectorySizeCounting = true;
    m_IsStopDirectoryLoading = true;
    m_IsStopDirectoryReLoading = true;
}

- (void) UpdateSpinningIndicator
{
    bool is_anything_working = m_IsDirectorySizeCounting || m_IsDirectoryLoading || m_IsDirectoryReLoading;
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
    m_Data->GetDirectoryPath(path);
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
    m_Data->GetDirectoryPath(path);
    if(GetFirstAvailableDirectoryFromPath(path))
//        [self GoToDirectory:path];
        [self GoToRelativeToHostAsync:path select_entry:0];
}

///////////////////////////////////////////////////////////////////////////////////////////////
// Delayed cursors movement support

- (void) ScheduleDelayedSelectionChangeFor:(NSString *)_item_name timeoutms:(int)_time_out_in_ms checknow:(bool)_check_now
{
    [self ScheduleDelayedSelectionChangeForC:[_item_name fileSystemRepresentation]
                                   timeoutms:_time_out_in_ms
                                    checknow:_check_now];
}

- (void) ScheduleDelayedSelectionChangeForC:(const char*)_item_name timeoutms:(int)_time_out_in_ms checknow:(bool)_check_now
{
    assert(dispatch_get_current_queue() == dispatch_get_main_queue()); // to preserve against fancy threading stuff
    assert(_item_name);
    // we assume that _item_name will not contain any forward slashes
    
    m_DelayedSelection.isvalid = true;
    m_DelayedSelection.request_end = GetTimeInNanoseconds() + _time_out_in_ms*USEC_PER_SEC;
    strcpy(m_DelayedSelection.filename, _item_name);
    
    if(_check_now)
        [self CheckAgainstRequestedSelection];
}

- (void) CheckAgainstRequestedSelection
{
    assert(dispatch_get_current_queue() == dispatch_get_main_queue()); // to preserve against fancy threading stuff
    if(!m_DelayedSelection.isvalid)
        return;

    uint64_t now = GetTimeInNanoseconds();
    if(now > m_DelayedSelection.request_end)
    {
        m_DelayedSelection.isvalid = false;
        return;
    }
    
    // now try to find it
    int entryindex = m_Data->FindEntryIndex(m_DelayedSelection.filename);
    if( entryindex >= 0 )
    {
        // we found this entry. regardless of appearance of this entry in current directory presentation
        // there's no reason to search for it again
        m_DelayedSelection.isvalid = false;
        
        int sortpos = m_Data->FindSortedEntryIndex(entryindex);
        if( sortpos >= 0 )
            [m_View SetCursorPosition:sortpos];
    }
}

- (void) ClearSelectionRequest
{
    m_DelayedSelection.isvalid = false;
}



- (void) SelectAllEntries:(bool) _select
{
    m_Data->CustomFlagsSelectAllSorted(_select);
    [m_View setNeedsDisplay:true];
}

- (void) OnPathChanged
{
    char path[MAXPATHLEN];
    m_Data->GetDirectoryPathWithTrailingSlash(path);
    [self ResetUpdatesObservation:path];
    [self ClearSelectionRequest];   
    [self SignalParentOfPathChanged];
    [self UpdateEjectButton];
    [self HandleCursorChanged];
}

- (MainWindowFilePanelState*) GetParentWindow
{
    NSView *parent = [m_View superview];
    while(parent && ![parent isKindOfClass: [MainWindowFilePanelState class]])
        parent = [parent superview];
    assert(parent);
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
        m_Data->GetDirectoryPath(path); // not thread-safe, potentialy may cause problems, but not likely
        EjectVolumeContainingPath(path);
    });
}

- (void) SelectEntriesByMask:(NSString*)_mask select:(bool)_select
{
    const int stripe_size = 100;
    
    FileMask mask(_mask), *maskp = &mask;
    auto &entries = m_Data->DirectoryEntries();
    auto &sorted_entries = m_Data->SortedDirectoryEntries();
    bool ignore_dirs = [[NSUserDefaults standardUserDefaults] boolForKey:@"FilePanelsGeneralIgnoreDirectoriesOnSelectionWithMask"];

    dispatch_apply(sorted_entries.size() / stripe_size + 1, dispatch_get_global_queue(0, 0), ^(size_t n){
        size_t max = sorted_entries.size();
        for(size_t i = n*stripe_size; i < (n+1)*stripe_size && i < max; ++i) {
            const auto &entry = entries[i];
            if(ignore_dirs && entry.IsDir())
                continue;
            if(entry.IsDotDot())
                continue;
            if(maskp->MatchName((__bridge NSString*)entry.CFName()))
                m_Data->CustomFlagsSelect(i, _select);
        }
    });
    
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

- (void) HandleCursorChanged
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
}

@end
