//
//  PanelController.h
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PanelData.h"
#import "PanelView.h"

@class MainWindowController;
@class QuickLookView;
@class PanelFastSearchPopupViewController;
@class BriefSystemOverview;

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
    
    // QuickLook support
    __weak QuickLookView *m_QuickLook;
    
    // BriefSystemOverview support
    __weak BriefSystemOverview* m_BriefSystemOverview;
    
    NSButton            *m_EjectButton;
    NSButton            *m_ShareButton;
    
    // delayed entry selection support
    struct
    {
        /**
         * Turn on or off this selection mechanics
         */
        bool        isvalid;

        /**
         * Requested item name to select.
         */
        char        filename[MAXPATHLEN];
        
        /**
         * Time after which request is meaningless and should be removed
         */
        uint64_t    request_end;
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

- (bool) IsActivePanel;
- (void) RequestActivation;




- (void) HandleReturnButton;
- (void) HandleShiftReturnButton;
- (void) HandleFileView; // F3
- (void) HandleBriefSystemOverview;

// called by PanelView ///////////////////////////////////////////////
- (void) HandleCursorChanged;
- (void) HandleItemsContextMenu;
///////////////////////////////////////////////////////////////////////

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
- (void) GoToRelativeToHostAsync:(const char*) _path select_entry:(const char*) _entry; // _entry may be NULL
- (void) GoToGlobalHostsPathAsync:(const char*) _path select_entry:(const char*) _entry; // _entry may be NULL
- (int)  GoToRelativeToHostSync:(const char*) _path;
- (int)  GoToGlobalHostsPathSync:(const char*) _path;
- (void) GoToUpperDirectoryAsync;
///////////////////////////////////////////////////////////////////////

- (void) ModifierFlagsChanged:(unsigned long)_flags; // to know if shift or something else is pressed
- (void)keyDown:(NSEvent *)event;

- (void) SelectAllEntries: (bool) _select; // if false - then deselect all
- (void) SelectEntriesByMask:(NSString*) _mask select:(bool) _select; // if false - then deselect elements by mask
@end


#import "PanelController+DataAccess.h"
#import "PanelController+DelayedSelection.h"
