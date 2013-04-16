//
//  PanelController.m
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"
#import "FSEventsDirUpdate.h"
#import <mach/mach_time.h>


static const uint64_t g_FastSeachDelayTresh = 5000000000; // 5 sec

@implementation PanelController
{
    PanelData *m_Data;
    PanelView *m_View;
    unsigned long m_UpdatesObservationTicket;
    
    NSString *m_FastSearchString;
    uint64_t m_FastSearchLastType;
    unsigned m_FastSearchOffset;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
        m_UpdatesObservationTicket = 0;
        m_FastSearchLastType = 0;
        m_FastSearchOffset = 0;
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
                int newcursor_sort = 0;
                if(newcursor_raw >= 0) newcursor_sort = m_Data->FindSortedEntryIndex(newcursor_raw);
                if(newcursor_sort < 0) newcursor_sort = 0;
                    
                [m_View DirectoryChanged:newcursor_sort Type:GoIntoParentDir];
            }
            else
            {
                [m_View DirectoryChanged:0 Type:GoIntoSubDir];
            }
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

- (void) ChangeSortingModeTo:(PanelSortMode)_mode
{
    int curpos = [m_View GetCursorPosition];
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
    mode.sepdir = !mode.sepdir;
    [self ChangeSortingModeTo:mode];
}

- (void) ToggleSortingBySize{
    [self MakeSortWith:PanelSortMode::SortBySize Rev:PanelSortMode::SortBySizeRev];
}

- (void) ToggleSortingByName{
    [self MakeSortWith:PanelSortMode::SortByName Rev:PanelSortMode::SortByNameRev];
}

- (void) ToggleSortingByMTime{
    [self MakeSortWith:PanelSortMode::SortByMTime Rev:PanelSortMode::SortByMTimeRev];
}

- (void) ToggleSortingByBTime{
    [self MakeSortWith:PanelSortMode::SortByBTime Rev:PanelSortMode::SortByBTimeRev];
}

- (void) ToggleSortingByExt{
    [self MakeSortWith:PanelSortMode::SortByExt Rev:PanelSortMode::SortByExtRev];
}

- (void) ToggleShortViewMode{
    [m_View ToggleViewType:PanelViewType::ViewShort];
}

- (void) ToggleMediumViewMode{
    [m_View ToggleViewType:PanelViewType::ViewMedium];
}

- (void) ToggleFullViewMode{
    [m_View ToggleViewType:PanelViewType::ViewFull];
}

- (void) ToggleWideViewMode{
    [m_View ToggleViewType:PanelViewType::ViewWide];
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

- (void)HandleFastSearch: (NSString*) _key
{
    uint64_t currenttime = mach_absolute_time();
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
    if(m_Data->FindSuitableEntry( (__bridge CFStringRef) m_FastSearchString, m_FastSearchOffset, &ind, &range))
    {
        if(m_FastSearchOffset > range)
            m_FastSearchOffset = range;
            
        int pos = m_Data->FindSortedEntryIndex(ind);
        if(pos >= 0)
            [m_View SetCursorPosition:pos];
    }
}

- (void)keyDown:(NSEvent *)event
{
    NSString*  const character = [event charactersIgnoringModifiers];

    NSUInteger const modif       = [event modifierFlags];
    
#define ISMODIFIER(_v) ( (modif&NSDeviceIndependentModifierFlagsMask) == (_v) )

    if(ISMODIFIER(NSAlternateKeyMask))
        [self HandleFastSearch:character];
    
    if ( [character length] != 1 ) return;
    unichar const unicode        = [character characterAtIndex:0];
//    unsigned short const keycode = [event keyCode];

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
            else if(modif & NSAlternateKeyMask)
            {
                if(m_FastSearchOffset > 0)
                    m_FastSearchOffset--;
                [self HandleFastSearch:nil];
            }
            else                         [m_View HandlePrevFile];
            break;
        case NSDownArrowFunctionKey:
            if(modif & NSCommandKeyMask) [m_View HandleNextPage];
            else if(modif &  NSAlternateKeyMask)
                {
                    m_FastSearchOffset++;
                    [self HandleFastSearch:nil];
                }
            else                         [m_View HandleNextFile];
            break;
        case NSCarriageReturnCharacter: // RETURN key
            if(ISMODIFIER(NSShiftKeyMask)) [self HandleShiftReturnButton];
            else                           [self HandleReturnButton];
            break;
    }
}

- (void) ModifierFlagsChanged:(unsigned long)_flags // to know if shift or something else is pressed
{
    [m_View ModifierFlagsChanged:_flags];
    
    if(m_FastSearchString != nil && (_flags & NSAlternateKeyMask) == 0)
    {
        // user was fast searching something, need to flush that string
        m_FastSearchString = nil;
        m_FastSearchOffset = 0;
    }
}

@end
