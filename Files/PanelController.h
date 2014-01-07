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
#import "PanelHistory.h"
#import "DispatchQueue.h"

@class MainWindowController;
@class QuickLookView;
@class PanelFastSearchPopupViewController;
@class BriefSystemOverview;

struct PanelControllerNavigation
{
    enum {
        NoHistory = 1
        
        
    };
};

@interface PanelController : NSObject
{
    PanelData *m_Data;
    PanelView *m_View;
    vector<shared_ptr<VFSHost>> m_HostsStack; // by default [0] is NativeHost
    
    __unsafe_unretained MainWindowController *m_WindowController;
    
    shared_ptr<VFSHost>    m_UpdatesObservationHost;
    unsigned long               m_UpdatesObservationTicket;
    
    // Fast searching section
    NSString *m_FastSearchString;
    uint64_t m_FastSearchLastType;
    unsigned m_FastSearchOffset;
    PanelFastSearchPopupViewController *m_FastSearchPopupView;
    
    // background operations' queues
    SerialQueue m_DirectorySizeCountingQ;
    SerialQueue m_DirectoryLoadingQ;
    SerialQueue m_DirectoryReLoadingQ;
    
    PanelHistory m_History;
    
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
        string      filename;
        
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




- (void) HandleReturnButton;        // 'Open' menu item
- (void) HandleShiftReturnButton;   // 'Open Natively' menu item
- (void) HandleFileView; // F3
- (void) HandleCalculateSizes;
- (void) HandleBriefSystemOverview;

// called by PanelView ///////////////////////////////////////////////
- (void) OnCursorChanged;
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

// refactor me!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
- (PanelViewType) GetViewType;
- (PanelSortMode) GetUserSortMode;
- (PanelDataHardFiltering) GetUserHardFiltering;

- (void) RefreshDirectory; // user pressed cmd+r by default

// MAIN NAVIGATION METHODS ////////////////////////////////////////////
- (void) GoToRelativeToHostAsync:(const char*) _path select_entry:(const char*) _entry; // _entry may be NULL
- (void) GoToGlobalHostsPathAsync:(const char*) _path select_entry:(const char*) _entry; // _entry may be NULL
- (void) GoToRelativeToHostAsync:(const char*) _path;
- (void) GoToGlobalHostsPathAsync:(const char*) _path;
- (int)  GoToRelativeToHostSync:(const char*) _path;
- (int)  GoToGlobalHostsPathSync:(const char*) _path;
- (void) GoToUpperDirectoryAsync;
///////////////////////////////////////////////////////////////////////

- (void) ModifierFlagsChanged:(unsigned long)_flags; // to know if shift or something else is pressed
- (bool) ProcessKeyDown:(NSEvent *)event; // return true if key was processed

- (void) SelectAllEntries: (bool) _select; // if false - then deselect all
- (void) SelectEntriesByMask:(NSString*) _mask select:(bool) _select; // if false - then deselect elements by mask
@end

// internal stuff, move it somewehere else
@interface PanelController ()
- (int) FetchFlags;
- (void) CancelBackgroundOperations;
- (void) OnPathChanged:(int)_flags;
@end

#import "PanelController+DataAccess.h"
#import "PanelController+DelayedSelection.h"
#import "PanelController+Navigation.h"
