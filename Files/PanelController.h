//
//  PanelController.h
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "PanelData.h"
#include "PanelView.h"
#import "PanelFastSearchPopupViewController.h"

@class MainWindowController;

@interface PanelController : NSViewController
{
    PanelData *m_Data;
    PanelView *m_View;
    std::vector<std::shared_ptr<VFSHost>> m_HostsStack; // by default [0] is NativeHost
    
    __unsafe_unretained MainWindowController *m_WindowController;
    
    std::shared_ptr<VFSHost>    m_UpdatesObservationHost;
    unsigned long               m_UpdatesObservationTicket;
    
    // Fast searching section
    NSString *m_FastSearchString;
    uint64_t m_FastSearchLastType;
    unsigned m_FastSearchOffset;
    PanelFastSearchPopupViewController *m_FastSearchPopupView;
    
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
    
    NSButton            *m_EjectButton;
    NSButton            *m_ShareButton;
    
    // delayed entry selection support
    struct
    {
        bool        isvalid;
        char        filename[MAXPATHLEN];
        uint64_t    request_end; // time after which request is meaningless and should be removed
    } m_DelayedSelection;
}

// CONFIGURATION METHODS /////////////////////////////////////////////
- (void) SetData:(PanelData*)_data;
- (void) SetView:(PanelView*)_view;
- (void) AttachToControls:(NSProgressIndicator*)_indicator
                    eject:(NSButton*)_eject
                    share:(NSButton*)_share;
- (void) SetWindowController:(MainWindowController *)_cntrl;
//////////////////////////////////////////////////////////////////////




- (void) LoadViewState:(NSDictionary *)_state;
- (NSDictionary *) SaveViewState;

- (void) RequestActivation;




- (void) HandleReturnButton;
- (void) HandleShiftReturnButton;
- (void) HandleFileView; // F3

- (void) HandleCursorChanged; // called by PanelView


- (void) ToggleSortingByName; // user pressed ctrl+F3 by default
- (void) ToggleSortingByExt; // user pressed ctrl+F4 by default
- (void) ToggleSortingByMTime; // user pressed ctrl+F5 by default
- (void) ToggleSortingBySize; // user pressed ctrl+F6 by default
- (void) ToggleSortingByBTime; // user pressed ctrl+F8 by default
- (void) ToggleViewHiddenFiles;
- (void) ToggleSeparateFoldersFromFiles;
- (void) ToggleCaseSensitiveComparison;
- (void) ToggleNumericComparison;
- (void) ToggleShortViewMode; // user pressed ctrl+1 by default
- (void) ToggleMediumViewMode; // user pressed ctrl+2 by default
- (void) ToggleFullViewMode; // user pressed ctrl+3 by default
- (void) ToggleWideViewMode; // user pressed ctrl+4 by default

- (PanelViewType) GetViewType;
- (PanelSortMode) GetUserSortMode;

- (void) RefreshDirectory; // user pressed cmd+r by default

// MAIN NAVIGATION METHODS ////////////////////////////////////////////
- (void) GoToRelativeToHostAsync:(const char*) _path select_entry:(const char*) _entry;
- (void) GoToGlobalHostsPathAsync:(const char*) _path select_entry:(const char*) _entry;
- (int)  GoToRelativeToHostSync:(const char*) _path;
- (int)  GoToGlobalHostsPathSync:(const char*) _path;
- (void) GoToUpperDirectoryAsync;
///////////////////////////////////////////////////////////////////////

- (void) ModifierFlagsChanged:(unsigned long)_flags; // to know if shift or something else is pressed
- (void)keyDown:(NSEvent *)event;

// delayed entry selection change
// panel controller will memorize such request
// if _check_now flag is on then controller will look for requested element and if it was found - select it
// if there was another pending selection request - it will be overwrited by the new one
// controller will check for entry appearance on every directory update
// request will be removed upon directory change
// one request is accomplished it will be removed
// if on any checking it will be found that time for request has went out - it will be removed
// 500ms is just ok for _time_out_in_ms
- (void) ScheduleDelayedSelectionChangeFor:(NSString *)_item_name timeoutms:(int)_time_out_in_ms checknow:(bool)_check_now;
- (void) ScheduleDelayedSelectionChangeForC:(const char*)_item_name timeoutms:(int)_time_out_in_ms checknow:(bool)_check_now;

- (void) SelectAllEntries: (bool) _select; // if false - then deselect all
- (void) SelectEntriesByMask:(NSString*) _mask select:(bool) _select; // if false - then deselect elements by mask
@end
