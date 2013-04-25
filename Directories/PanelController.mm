//
//  PanelController.m
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"
#import "FSEventsDirUpdate.h"
#import "PanelSizeCalculator.h"
#import "Common.h"
#import "MainWindowController.h"
#import <mach/mach_time.h>


static const uint64_t g_FastSeachDelayTresh = 5000000000; // 5 sec

@implementation PanelController
{
    PanelData *m_Data;
    PanelView *m_View;
    __weak MainWindowController *m_WindowController;
    unsigned long m_UpdatesObservationTicket;
    
    NSString *m_FastSearchString;
    uint64_t m_FastSearchLastType;
    unsigned m_FastSearchOffset;
    
    // background directory size calculation support
    bool     m_IsStopDirectorySizeCounting; // flags current any other those tasks in queue that they need to stop
    bool     m_IsDirectorySizeCounting; // is background task currently working?
    dispatch_queue_t m_DirectorySizeCountingQ;
    
    // background directory changing (loading) support
    bool     m_IsStopDirectoryLoading; // flags current any other those tasks in queue that they need to stop
    bool     m_IsDirectoryLoading; // is background task currently working?
    dispatch_queue_t m_DirectoryLoadingQ;
    bool     m_IsStopDirectoryReLoading; // flags current any other those tasks in queue that they need to stop
    bool     m_IsDirectoryReLoading; // is background task currently working?
    dispatch_queue_t m_DirectoryReLoadingQ;
    
    // spinning indicator support
    bool                m_IsAnythingWorksInBackground;
    NSProgressIndicator *m_SpinningIndicator;
    
    // delayed entry selection support
    struct
    {
        bool        isvalid;
        char        filename[MAXPATHLEN];
        uint64_t    request_end; // time after which request is meaningless and should be removed
    } m_DelayedSelection;
}

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

- (void) LoadViewState:(NSDictionary *)_state
{
    PanelSortMode mode = m_Data->GetCustomSortMode();
    
    mode.sep_dirs = [[_state valueForKey:@"SeparateDirectories"] boolValue];
    mode.show_hidden = [[_state valueForKey:@"ViewHiddenFiles"] boolValue];
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
        [NSNumber numberWithInt:(int)[m_View GetCurrentViewType]], @"ViewMode",
        [NSNumber numberWithInt:(int)mode.sort], @"SortMode",
        nil];
}

- (void) HandleShiftReturnButton
{
    char path[__DARWIN_MAXPATHLEN];
    int pos = [m_View GetCursorPosition];
    if(pos >= 0)
    {
        int rawpos = m_Data->SortedDirectoryEntries()[pos];
        m_Data->ComposeFullPathForEntry(rawpos, path);
        BOOL success = [[NSWorkspace sharedWorkspace]
                        openFile:[NSString stringWithUTF8String:path]];
        if (!success) NSBeep();
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

- (void) ResetUpdatesObservation:(const char *) _new_path
{
    FSEventsDirUpdate::Inst()->RemoveWatchPathWithTicket(m_UpdatesObservationTicket);
    m_UpdatesObservationTicket = FSEventsDirUpdate::Inst()->AddWatchPath(_new_path);
}

- (void) GoToDirectory:(const char*) _dir
{
    assert(_dir && strlen(_dir));
    char *path = strdup(_dir);

    auto onsucc = ^(PanelData::DirectoryChangeContext* _context){
        m_IsStopDirectorySizeCounting = true;
        m_IsStopDirectoryLoading = true;
        m_IsStopDirectoryReLoading = true;        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self ResetUpdatesObservation:_context->path];
            m_Data->GoToDirectoryWithContext(_context);
            [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoOtherDir newcursor:0];
            [self ClearSelectionRequest];
            [m_WindowController UpdateTitle];
        });
    };
    
    auto onfail = ^(const char* _path, int _error) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText: [NSString stringWithFormat:@"Failed to go into directory %@", [[NSString alloc] initWithUTF8String:_path]]];
        [alert setInformativeText:[NSString stringWithFormat:@"Error: %s", strerror(_error)]];
        dispatch_async(dispatch_get_main_queue(), ^{ [alert runModal]; });
    };
    
    if(m_IsStopDirectoryLoading)
        dispatch_async(m_DirectoryLoadingQ, ^{ m_IsStopDirectoryLoading = false; } );
    dispatch_async(m_DirectoryLoadingQ, ^{
        dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryLoading:true];});
        PanelData::LoadFSDirectoryAsync(path, onsucc, onfail, ^bool(){return m_IsStopDirectoryLoading;} );
        dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryLoading:false];});
    });
}

- (bool) GoToDirectorySync:(const char*) _dir
{
    if(!m_Data->GoToDirectory(_dir))
        return false;

    // clean running operations if any
    m_IsStopDirectorySizeCounting = true;
    m_IsStopDirectoryLoading = true;
    m_IsStopDirectoryReLoading = true;
    [self ResetUpdatesObservation:_dir];
    [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoOtherDir newcursor:0];
    [m_WindowController UpdateTitle];
    return true;
}

- (void) HandleReturnButton
{
    int sort_pos = [m_View GetCursorPosition];
    if(sort_pos < 0)
        return;
    int raw_pos = m_Data->SortedDirectoryEntries()[sort_pos];
    
    // Handle directories.
    if (m_Data->DirectoryEntries()[raw_pos].isdir())
    {
        char path[__DARWIN_MAXPATHLEN];
        m_Data->ComposeFullPathForEntry(raw_pos, path);
        char *blockpath = strdup(path);
        
        auto onfail = ^(const char* _path, int _error) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setMessageText: [NSString stringWithFormat:@"Failed to enter directory %@", [[NSString alloc] initWithUTF8String:_path]]];
            [alert setInformativeText:[NSString stringWithFormat:@"Error: %s", strerror(_error)]];
            dispatch_async(dispatch_get_main_queue(), ^{ [alert runModal]; });
        };
        
        if(m_IsStopDirectoryLoading)
            dispatch_async(m_DirectoryLoadingQ, ^{ m_IsStopDirectoryLoading = false; } );
        
        if( m_Data->DirectoryEntries()[raw_pos].isdotdot() )
        { // go to parent directory
            //a bit crazy, but it's easier than handling lifetime of objects manually - let ARC do it's job
            char curdirname[__DARWIN_MAXPATHLEN];
            m_Data->GetDirectoryPathShort(curdirname);
            NSString *nscurdirname = [[NSString alloc] initWithUTF8String:curdirname];
            
            auto onsucc = ^(PanelData::DirectoryChangeContext* _context){
                m_IsStopDirectorySizeCounting = true;
                m_IsStopDirectoryLoading = true;
                m_IsStopDirectoryReLoading = true;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self ResetUpdatesObservation:_context->path];
                    m_Data->GoToDirectoryWithContext(_context);
                    
                    int newcursor_raw = m_Data->FindEntryIndex( [nscurdirname UTF8String] ), newcursor_sort = 0;
                    if(newcursor_raw >= 0) newcursor_sort = m_Data->FindSortedEntryIndex(newcursor_raw);
                    if(newcursor_sort < 0) newcursor_sort = 0;
                    [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoParentDir newcursor:newcursor_sort];
                    [self ClearSelectionRequest];
                    [m_WindowController UpdateTitle];
                });
            };
            
            dispatch_async(m_DirectoryLoadingQ, ^{
                dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryLoading:true];});
                PanelData::LoadFSDirectoryAsync(blockpath, onsucc, onfail, ^bool(){return m_IsStopDirectoryLoading;});
                dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryLoading:false];});
            });
        }
        else
        { // go into regular sub-directory
            auto onsucc = ^(PanelData::DirectoryChangeContext* _context){
                m_IsStopDirectorySizeCounting = true;
                m_IsStopDirectoryLoading = true;
                m_IsStopDirectoryReLoading = true;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self ResetUpdatesObservation:_context->path];
                    m_Data->GoToDirectoryWithContext(_context);
                    
                    [m_View DirectoryChanged:PanelViewDirectoryChangeType::GoIntoSubDir newcursor:0];
                    [self ClearSelectionRequest];
                    [m_WindowController UpdateTitle];
                });
            };
            
            dispatch_async(m_DirectoryLoadingQ, ^{
                dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryLoading:true];});
                PanelData::LoadFSDirectoryAsync(blockpath, onsucc, onfail, ^bool(){return m_IsStopDirectoryLoading;});
                dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryLoading:false];});
            });
        }
        
        return;
    }
    
    // If previous code didn't handle current item,
    // open item with the default associated application.
    char path[__DARWIN_MAXPATHLEN];
    int pos = [m_View GetCursorPosition];
    if(pos >= 0)
    {
        int rawpos = m_Data->SortedDirectoryEntries()[pos];
        m_Data->ComposeFullPathForEntry(rawpos, path);
        BOOL success = [[NSWorkspace sharedWorkspace]
                        openFile:[NSString stringWithUTF8String:path]];
        if (!success) NSBeep();
    }
}

- (void) RefreshDirectory
{    
    char dirpath[MAXPATHLEN];
    m_Data->GetDirectoryPathWithTrailingSlash(dirpath);
    char *path = strdup(dirpath);
    
    int oldcursorpos = [m_View GetCursorPosition];
    NSString *oldcursorname = (oldcursorpos >= 0 ? [[NSString alloc] initWithUTF8String:[m_View CurrentItem]->namec()] : nil);
    
    auto onfail = ^(const char* _path, int _error) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText: [NSString stringWithFormat:@"Failed to update directory directory %@", [[NSString alloc] initWithUTF8String:_path]]];
        [alert setInformativeText:[NSString stringWithFormat:@"Error: %s", strerror(_error)]];
        dispatch_async(dispatch_get_main_queue(), ^{ [alert runModal]; });
    };
    
    auto onsucc = ^(PanelData::DirectoryChangeContext* _context){
        m_IsStopDirectoryReLoading = true;
        dispatch_async(dispatch_get_main_queue(), ^{
            m_Data->ReloadDirectoryWithContext(_context);
            assert(!m_Data->DirectoryEntries().empty()); // algo logic doesn't support this case now

            int newcursorrawpos = m_Data->FindEntryIndex([oldcursorname UTF8String]);
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
    };

    if(m_IsStopDirectoryReLoading)
        dispatch_async(m_DirectoryReLoadingQ, ^{ m_IsStopDirectoryReLoading = false; } );
    dispatch_async(m_DirectoryReLoadingQ, ^{
        dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryReLoading:true];});
        PanelData::LoadFSDirectoryAsync(path, onsucc, onfail, ^bool(){return m_IsStopDirectoryReLoading;});
        dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectoryReLoading:false];});
    });
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
        case NSF3FunctionKey: [self HandleFileView]; break;
    }
    
    switch (keycode)
    {
        case 53: // Esc button
            [self CancelBackgroundOperations];
            break;
    }
}

- (void) HandleFileView // F3
{
    // dummy for now. we need to analyze the selection and/or cursor position
    
    if(m_Data->GetSelectedItemsCount())
    {
        auto files = m_Data->StringsFromSelectedEntries();
        [self StartDirectorySizeCountingFor:files];
    }
    else
    {
        auto const *item = [m_View CurrentItem];
        
        // do not try count parent directory size. TODO: need a special handling here, it count the entire directory
        if(item && !item->isdotdot())
        {
            auto files = FlexChainedStringsChunk::AllocateWithSingleString(item->namec());
            [self StartDirectorySizeCountingFor:files];
        }
    }
}

- (void) StartDirectorySizeCountingFor:(FlexChainedStringsChunk *)_files
{
    if(m_IsStopDirectorySizeCounting)
        dispatch_async(m_DirectorySizeCountingQ, ^{ m_IsStopDirectorySizeCounting = false; } );
    
    char dir[MAXPATHLEN];
    m_Data->GetDirectoryPathWithTrailingSlash(dir);
    const char *str = strdup(dir);
    
    dispatch_async(m_DirectorySizeCountingQ, ^{
        dispatch_async(dispatch_get_main_queue(), ^{[self NotifyDirectorySizeCounting:true];});
        PanelDirectorySizeCalculate(_files, str, self, ^bool{return m_IsStopDirectorySizeCounting;});
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
    }
}

- (void) DidCalculatedDirectorySizeForEntry:(const char*) _dir size:(unsigned long)_size
{
    // TODO: lock panel data?
    // CHECK ME!!!!!!!!!!!!!!!!!!!!!!
    // gues it's better to move the following line into main thread
    // it may be a race condition with possible UB here. BAD!
    if(m_Data->SetCalculatedSizeForDirectory(_dir, _size))
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [m_View setNeedsDisplay:true];
        });
    }
}

- (void) AttachToIndicator:(NSProgressIndicator*)_ind
{
    m_SpinningIndicator = _ind;
    m_IsAnythingWorksInBackground = false;
    [m_SpinningIndicator stopAnimation:nil];    
    [self UpdateSpinningIndicator];
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
                               [m_SpinningIndicator startAnimation:nil];
                       });
    }
    else
    {
        [m_SpinningIndicator stopAnimation:nil];
    }
    
    m_IsAnythingWorksInBackground = is_anything_working;
}

- (PanelViewType) GetViewType
{
    return [m_View GetCurrentViewType];
}

- (PanelSortMode) GetUserSortMode
{
    return m_Data->GetCustomSortMode();
}

///////////////////////////////////////////////////////////////////////////////////////////////
// Delayed selection support

- (void) ScheduleDelayedSelectionChangeFor:(NSString *)_item_name timeoutms:(int)_time_out_in_ms checknow:(bool)_check_now
{
    assert(dispatch_get_current_queue() == dispatch_get_main_queue()); // to preserve against fancy threading stuff
    // we assume that _item_name will not contain any forward slashes
    
    m_DelayedSelection.isvalid = true;
    m_DelayedSelection.request_end = mach_absolute_time() + _time_out_in_ms*USEC_PER_SEC;
    strcpy(m_DelayedSelection.filename, [_item_name UTF8String]);
    
    if(_check_now)
        [self CheckAgainstRequestedSelection];
}

- (void) CheckAgainstRequestedSelection
{
    assert(dispatch_get_current_queue() == dispatch_get_main_queue()); // to preserve against fancy threading stuff
    if(!m_DelayedSelection.isvalid)
        return;

    uint64_t now = mach_absolute_time();
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

@end
