//
//  PanelController.m
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"
#include "FSEventsDirUpdate.h"

@interface PanelController ()

@end

@implementation PanelController
{
    PanelData *m_Data;
    PanelView *m_View;
    unsigned long m_UpdatesObservationTicket;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
        m_UpdatesObservationTicket = 0;
    }
    
    return self;
}

- (void) SetData:(PanelData*)_data
{
    m_Data = _data;
}

- (void) SetView:(PanelView*)_view
{
    m_View = _view;
    [self setView:_view]; // do we need it?
}

- (void) HandleReturnButton
{
    int sort_pos = [m_View GetCursorPosition];
    int raw_pos = m_Data->SortedDirectoryEntries()[sort_pos];
    if( m_Data->DirectoryEntries()[raw_pos].isdir() )
    {
        char newpath[__DARWIN_MAXPATHLEN];
        char oldpathname[__DARWIN_MAXPATHLEN];
        char oldpathname_full[__DARWIN_MAXPATHLEN];
            
        bool gotoparent = m_Data->DirectoryEntries()[raw_pos].isdotdot();
            
        m_Data->GetDirectoryPathShort(oldpathname);
        m_Data->GetDirectoryPathWithTrailingSlash(oldpathname_full);
        m_Data->ComposeFullPathForEntry(raw_pos, newpath);
        
        if(m_Data->GoToDirectory(newpath))
        {
            if(gotoparent)
            {
                int newcursor_raw = m_Data->FindEntryIndex(oldpathname);
                int newcursor = 0;
                if(newcursor_raw >= 0) newcursor = m_Data->FindSortedEntryIndex(newcursor_raw);
                    
                [m_View DirectoryChanged:newcursor Type:GoIntoParentDir];
            }
            else
            {
                [m_View DirectoryChanged:0 Type:GoIntoSubDir];
            }
//            FSEventsDirUpdate::Inst()->RemoveWatchPath(oldpathname_full);
            FSEventsDirUpdate::Inst()->RemoveWatchPathWithTicket(m_UpdatesObservationTicket);
            m_UpdatesObservationTicket = FSEventsDirUpdate::Inst()->AddWatchPath(newpath);
        }
    }
}

- (void) HandleShiftReturnButton
{
    char path[__DARWIN_MAXPATHLEN];
    int pos = [m_View GetCursorPosition];
    int rawpos = m_Data->SortedDirectoryEntries()[pos];
    m_Data->ComposeFullPathForEntry(rawpos, path);
    [[NSWorkspace sharedWorkspace] openFile:[NSString stringWithUTF8String:path]];
}

- (void) MakeSortWith:(PanelSortMode::Mode)_direct Rev:(PanelSortMode::Mode)_rev
{
    PanelSortMode mode = m_Data->GetCustomSortMode(); // we don't want to change anything in sort params except the mode itself
    if(mode.sort != _direct)  mode.sort = _direct;
    else                      mode.sort = _rev;
    
    int curpos = [m_View GetCursorPosition];
    int rawpos = m_Data->SortedDirectoryEntries()[curpos];
    
    m_Data->SetCustomSortMode(mode);
    int newcurpos = m_Data->FindSortedEntryIndex(rawpos);
    [m_View SetCursorPosition:newcurpos];
    [m_View setNeedsDisplay:true];
}

- (void) ToggleSortingBySize
{
    [self MakeSortWith:PanelSortMode::SortBySize Rev:PanelSortMode::SortBySizeRev];
}

- (void) ToggleSortingByName
{
    [self MakeSortWith:PanelSortMode::SortByName Rev:PanelSortMode::SortByNameRev];
}

- (void) ToggleSortingByMTime
{
    [self MakeSortWith:PanelSortMode::SortByMTime Rev:PanelSortMode::SortByMTimeRev];
}

- (void) ToggleSortingByBTime
{
    [self MakeSortWith:PanelSortMode::SortByBTime Rev:PanelSortMode::SortByBTimeRev];
}

- (void) ToggleSortingByExt
{
    [self MakeSortWith:PanelSortMode::SortByExt Rev:PanelSortMode::SortByExtRev];
}

- (void) ToggleShortViewMode
{
    [m_View ToggleViewType:PanelViewType::ViewShort];
}

- (void) ToggleMediumViewMode
{
    [m_View ToggleViewType:PanelViewType::ViewMedium];
}

- (void) FireDirectoryChanged: (const char*) _dir ticket:(unsigned long)_ticket
{
    // check if this tickes is ours
    if(_ticket == m_UpdatesObservationTicket) // integers comparison - just a blazing fast check
    {
        // update directory now!
        [self RefreshDirectory];
    }
}

- (bool) GoToDirectory:(const char*) _dir
{
    char oldpathname_full[__DARWIN_MAXPATHLEN];
    m_Data->GetDirectoryPathWithTrailingSlash(oldpathname_full);
    
    if(m_Data->GoToDirectory(_dir))
    {
        FSEventsDirUpdate::Inst()->RemoveWatchPathWithTicket(m_UpdatesObservationTicket);
        m_UpdatesObservationTicket = FSEventsDirUpdate::Inst()->AddWatchPath(_dir);
        [m_View SetCursorPosition:0];
        [m_View setNeedsDisplay:true];
        return true;
    }
    else
    {
        // TODO: error handling?
        return false;
    }
}

- (void) RefreshDirectory
{
    char oldcursorname[__DARWIN_MAXPATHLEN];
    int oldcursorpos = [m_View GetCursorPosition];
    strcpy(oldcursorname,
           m_Data->DirectoryEntries()[m_Data->SortedDirectoryEntries()[oldcursorpos]].namec()
           );
    
    m_Data->ReloadDirectory();
    
    int newcursorrawpos = m_Data->FindEntryIndex(oldcursorname);
    if( newcursorrawpos >= 0 )
    {
        int sortpos = m_Data->FindSortedEntryIndex(newcursorrawpos);
        assert(sortpos >= 0);
        [m_View SetCursorPosition:sortpos];
    }
    else
    {
        if( oldcursorpos >= m_Data->SortedDirectoryEntries().size() )
            oldcursorpos = (int)m_Data->SortedDirectoryEntries().size() - 1; // assuming that any directory will have at leat ".."
        [m_View SetCursorPosition:oldcursorpos];
    }
    
    [m_View setNeedsDisplay:true];
}

@end
