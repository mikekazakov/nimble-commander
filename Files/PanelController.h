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

@class QuickLookView;
@class PanelFastSearchPopupViewController;
@class BriefSystemOverview;
@class MainWindowFilePanelState;

struct PanelControllerNavigation
{
    enum {
        NoHistory = 1
    };
};

struct PanelQuickSearchMode
{
    enum KeyModif { // persistancy-bound values, don't change it
        WithAlt         = 0,
        WithCtrlAlt     = 1,
        WithShiftAlt    = 2,
        WithoutModif    = 3,
        Disabled        = 4
    };
    
    static KeyModif KeyModifFromInt(int _k)
    {
        if(_k >= 0 && _k <= Disabled)
            return (KeyModif)_k;
        return WithAlt;
    }
    
};

namespace panel
{
    class GenericCursorPersistance
    {
    public:
        GenericCursorPersistance(PanelView* _view, const PanelData &_data);
        void Restore();
        
    private:
        PanelView *view;
        const PanelData &data;
        int oldcursorpos;
        string oldcursorname;
    };
}

@interface PanelController : NSObject<PanelViewDelegate/*, NSDraggingSource, NSPasteboardItemDataProvider*/>
{
    // Main controller's possessions
    PanelData                   m_Data;   // owns
    PanelView                   *m_View;  // create and owns
    vector<shared_ptr<VFSHost>> m_HostsStack; // by default [0] is NativeHost
    
    // VFS changes observation
    shared_ptr<VFSHost>         m_UpdatesObservationHost;
    unsigned long               m_UpdatesObservationTicket;
    
    // VFS listing fetch flags
    int                         m_VFSFetchingFlags;
    
    // Quick searching section
    bool                                m_QuickSearchIsSoftFiltering;
    bool                                m_QuickSearchTypingView;
    PanelQuickSearchMode::KeyModif      m_QuickSearchMode;
    PanelDataTextFiltering::WhereEnum   m_QuickSearchWhere;
    uint64_t                            m_QuickSearchLastType;
    unsigned                            m_QuickSearchOffset;
    PanelFastSearchPopupViewController *m_QuickSearchPopupView;
    
    // background operations' queues
    SerialQueue m_DirectorySizeCountingQ;
    SerialQueue m_DirectoryLoadingQ;
    SerialQueue m_DirectoryReLoadingQ;
    
    // navigation support
    PanelHistory m_History;
    
    // spinning indicator support
    bool                m_IsAnythingWorksInBackground;
    NSProgressIndicator *m_SpinningIndicator;
    
    // QuickLook support
    __weak QuickLookView *m_QuickLook;
    
    // BriefSystemOverview support
    __weak BriefSystemOverview* m_BriefSystemOverview;
    
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

@property (weak) MainWindowFilePanelState* state;

// CONFIGURATION METHODS /////////////////////////////////////////////
- (void) AttachToControls:(NSProgressIndicator*)_indicator
                    share:(NSButton*)_share;
//////////////////////////////////////////////////////////////////////

- (PanelData&) Data;
- (PanelView*) View;


- (void) LoadViewState:(NSDictionary *)_state;
- (NSDictionary *) SaveViewState;

- (bool) IsActivePanel;


- (void) HandleReturnButton;        // 'Open' menu item
- (void) HandleShiftReturnButton;   // 'Open Natively' menu item
- (void) HandleFileView;            // F3
- (void) HandleCalculateSizes;      // alt+shift+return
- (void) HandleBriefSystemOverview; // cmd+L
- (void) HandleFileSearch;
- (void) HandleEjectVolume;

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
- (void) CancelBackgroundOperations;
- (void) OnPathChanged:(int)_flags;
@end

#import "PanelController+DataAccess.h"
#import "PanelController+DelayedSelection.h"
#import "PanelController+Navigation.h"
#import "PanelController+QuickSearch.h"
#import "PanelController+DragAndDrop.h"
