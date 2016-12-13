//
//  PanelController.h
//  Directories
//
//  Created by Michael G. Kazakov on 22.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Habanero/DispatchQueue.h>
#include "../../Bootstrap/Config.h"
#include "PanelData.h"
#include "PanelView.h"
#include "PanelViewLayoutSupport.h"
#include "PanelHistory.h"

@class PanelController;
@class QuickLookView;
@class BriefSystemOverview;
@class MainWindowFilePanelState;
@class MainWindowController;

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
        void Restore() const;
        
    private:
        PanelView                  *m_View;
        const PanelData            &m_Data;
        string                      m_OldCursorName;
        PanelData::EntrySortKeys    m_OldEntrySortKeys;
    };
    
    class ActivityTicket
    {
    public:
        ActivityTicket();
        ActivityTicket(PanelController *_panel, uint64_t _ticket);
        ActivityTicket(const ActivityTicket&) = delete;
        ActivityTicket(ActivityTicket&&);
        ~ActivityTicket();
        void operator=(const ActivityTicket&) = delete;
        void operator=(ActivityTicket&&);
        
    private:
        void Reset();
        uint64_t                ticket;
        __weak PanelController *panel;
    };
}

/**
 * PanelController is reponder to enable menu events processing
 */
@interface PanelController : NSResponder<PanelViewDelegate>
{
    // Main controller's possessions
    PanelData                   m_Data;   // owns
    PanelView                   *m_View;  // create and owns
    
    // VFS changes observation
    VFSHostDirObservationTicket  m_UpdatesObservationTicket;
    
    // VFS listing fetch flags
    int                         m_VFSFetchingFlags;
    
    // Quick searching section
    bool                                m_QuickSearchIsSoftFiltering;
    bool                                m_QuickSearchTypingView;
    PanelQuickSearchMode::KeyModif      m_QuickSearchMode;
    PanelData::TextualFilter::Where     m_QuickSearchWhere;
    nanoseconds                         m_QuickSearchLastType;
    unsigned                            m_QuickSearchOffset;
    
    // background operations' queues
    SerialQueue m_DirectorySizeCountingQ;
    SerialQueue m_DirectoryLoadingQ;
    SerialQueue m_DirectoryReLoadingQ;
    
    // navigation support
    PanelHistory m_History;
    
    // spinning indicator support
    bool                m_IsAnythingWorksInBackground;
    NSProgressIndicator *m_SpinningIndicator;
    
    // Tickets to show some external activities on this panel
    uint64_t            m_NextActivityTicket;
    vector<uint64_t>    m_ActivitiesTickets;
    spinlock            m_ActivitiesTicketsLock;
    
    // QuickLook support
    __weak QuickLookView *m_QuickLook;
    
    // BriefSystemOverview support
    __weak BriefSystemOverview* m_BriefSystemOverview;
    
    // drag & drop support, caching
    struct {
        int                 last_valid_items;
    } m_DragDrop;
    
    NSButton            *m_ShareButton;
    
    string              m_LastNativeDirectory;
    
    // delayed entry selection support
    struct
    {
        /**
         * Requested item name to select. Empty filename means that request is invalid.
         */
        string      filename;
        
        /**
         * Time after which request is meaningless and should be removed
         */
        nanoseconds    request_end;

        /**
         * Called when changed a cursor position
         */
        function<void()> done;
    } m_DelayedSelection;
    
    __weak MainWindowFilePanelState* m_FilePanelState;
    
    vector<GenericConfig::ObservationTicket> m_ConfigObservers;

    int                                 m_ViewLayoutIndex;
    shared_ptr<const PanelViewLayout>   m_AssignedViewLayout;
    PanelViewLayoutsStorage::ObservationTicket m_LayoutsObservation;
}

@property (nonatomic) MainWindowFilePanelState* state;
@property (nonatomic, readonly) MainWindowController* mainWindowController;
@property (nonatomic, readonly) PanelView* view;
@property (nonatomic, readonly) PanelData& data;
@property (nonatomic, readonly) const PanelHistory& history;
@property (nonatomic, readonly) bool isActive;
@property (nonatomic, readonly) bool isUniform; // return true if panel's listing has common vfs host and directory for it's items
@property (nonatomic, readonly) NSWindow* window;
@property (nonatomic, readonly) const string& lastNativeDirectoryPath;
@property (nonatomic, readonly) bool receivesUpdateNotifications; // returns true if underlying vfs will notify controller that content has changed
@property (nonatomic, readonly) bool ignoreDirectoriesOnSelectionByMask;
@property (nonatomic) int layoutIndex;

- (optional<rapidjson::StandaloneValue>) encodeRestorableState;
- (bool) loadRestorableState:(const rapidjson::StandaloneValue&)_state;

- (void) AttachToControls:(NSProgressIndicator*)_indicator
                    share:(NSButton*)_share;
- (void) RefreshDirectory; // user pressed cmd+r by default
- (void) ModifierFlagsChanged:(unsigned long)_flags; // to know if shift or something else is pressed
- (void) markRestorableStateAsInvalid; // will actually call window controller's invalidateRestorableState

/**
 * Will copy view options and sorting options.
 */
- (void) copyOptionsFromController:(PanelController*)_pc;

/**
 * RAII principle - when ActivityTicket dies - it will clear activity flag.
 * Thread-safe.
 */
- (panel::ActivityTicket) registerExtActivity;

- (void) changeSortingModeTo:(PanelData::PanelSortMode)_mode;

@end

// internal stuff, move it somewehere else
@interface PanelController ()
- (void) finishExtActivityWithTicket:(uint64_t)_ticket;
- (void) CancelBackgroundOperations;
- (void) OnPathChanged;
- (void) OnCursorChanged;
- (void) handleOpenInSystem;
- (bool) HandleGoToUpperDirectory;
- (bool) handleGoIntoDirOrArchiveSync:(bool)_whitelist_archive_only;
- (void) handleGoIntoDirOrOpenInSystemSync;
- (void) SelectEntriesByMask:(NSString*)_mask select:(bool)_select;
- (void) SelectAllEntries:(bool) _select;
- (void) invertSelection;
- (void) UpdateBriefSystemOverview;
- (void) CalculateSizes:(const vector<VFSListingItem>&) _items;
- (void) ChangeHardFilteringTo:(PanelData::HardFilter)_filter;
- (void) MakeSortWith:(PanelData::PanelSortMode::Mode)_direct Rev:(PanelData::PanelSortMode::Mode)_rev;
+ (bool) ensureCanGoToNativeFolderSync:(const string&)_path;
- (bool) ensureCanGoToNativeFolderSync:(const string&)_path; // checks only stuff related to sandbox model, not posix perms/acls.
- (bool) writeFilesnamesPBoard:(NSPasteboard *)pboard;
- (bool) writeURLSPBoard:(NSPasteboard *)pboard;
@end

#import "PanelController+DataAccess.h"
#import "PanelController+DelayedSelection.h"
#import "PanelController+Navigation.h"
#import "PanelController+QuickSearch.h"
#import "PanelController+DragAndDrop.h"
#import "PanelController+Menu.h"
#import "PanelController+NavigationMenu.h"
