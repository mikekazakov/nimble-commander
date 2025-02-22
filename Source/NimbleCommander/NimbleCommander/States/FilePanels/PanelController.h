// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/MIMResponder.h>

#include "PanelViewDelegate.h"
#include <Panel/PanelViewKeystrokeSink.h>
#include <Panel/QuickSearch.h>
#include <VFS/VFS.h>
#include <fmt/format.h>
#include <fmt/ranges.h>

@class PanelController;
@class NCPanelContextMenu;
@class PanelView;
@class BriefSystemOverview;
@class MainWindowFilePanelState;
@class NCMainWindowController;

namespace nc {

namespace core {
class VFSInstancePromise;
class VFSInstanceManager;
} // namespace core

namespace utility {
class NativeFSManager;
}

namespace vfs {
class NativeHost;
}

namespace panel {

namespace data {
struct SortMode;
struct HardFilter;
class Model;
} // namespace data

class History;
struct PersistentLocation;
class PanelViewLayoutsStorage;

class DirectoryAccessProvider
{
public:
    virtual ~DirectoryAccessProvider() = default;

    /**
     * Checks whether an additional permission is required to access the specified directory.
     */
    virtual bool HasAccess(PanelController *_panel, const std::string &_directory_path, VFSHost &_host) = 0;

    /**
     * Requests a permission to access the specified directory.
     * May block the calling thread to show some modal UI.
     * Should be called only as a reaction to an action started by the user.
     */
    virtual bool RequestAccessSync(PanelController *_panel, const std::string &_directory_path, VFSHost &_host) = 0;
};

class ActivityTicket
{
public:
    ActivityTicket();
    ActivityTicket(PanelController *_panel, uint64_t _ticket);
    ActivityTicket(const ActivityTicket &) = delete;
    ActivityTicket(ActivityTicket &&) noexcept;
    ~ActivityTicket();
    void operator=(const ActivityTicket &) = delete;
    ActivityTicket &operator=(ActivityTicket &&) noexcept;

private:
    void Reset();
    uint64_t ticket;
    __weak PanelController *panel;
};

struct DelayedFocusing {
    std::string filename;
    std::chrono::milliseconds timeout = std::chrono::milliseconds{500};
    bool check_now = true;

    /**
     * called by PanelController when succesfully changed the cursor position regarding this request.
     */
    std::function<void()> done;
};

struct DirectoryChangeRequest {
    /* required */
    std::string RequestedDirectory = "";
    std::shared_ptr<VFSHost> VFS = nullptr;

    /* optional */
    std::string RequestFocusedEntry = "";
    std::vector<std::string> RequestSelectedEntries = {};
    bool PerformAsynchronous = true;
    bool LoadPreviousViewState = false;
    bool InitiatedByUser = false;

    /**
     * This will be called from a thread which is loading a vfs listing with the result - either nothing or an error.
     * This thread may be main or background depending on PerformAsynchronous.
     * Will be called on any error canceling process or with {} on successful loading.
     */
    std::function<void(const std::expected<void, Error> &)> LoadingResultCallback = nullptr;
};

using ContextMenuProvider =
    std::function<NCPanelContextMenu *(std::vector<VFSListingItem> _items, PanelController *_panel)>;

} // namespace panel
} // namespace nc

/**
 * PanelController is reponder to enable menu events processing
 */
@interface PanelController : AttachedResponder <PanelViewDelegate, NCPanelViewKeystrokeSink, NCPanelQuickSearchDelegate>

@property(nonatomic) MainWindowFilePanelState *state;
@property(nonatomic, readonly) NCMainWindowController *mainWindowController;
@property(nonatomic, readonly) PanelView *view;
@property(nonatomic, readonly) const nc::panel::data::Model &data;

// Monotonically increasing number representing the number of times this Panel's content was
// changed. I.e. it means a complete change of location/type/etc instead of reloading/updating
// the existing listing.
@property(nonatomic, readonly) unsigned long dataGeneration;

@property(nonatomic, readonly) nc::panel::History &history;
@property(nonatomic, readonly) bool isActive;
@property(nonatomic, readonly)
    bool isUniform; // return true if panel's listing has common vfs host and directory for it's items
@property(nonatomic, readonly) NSWindow *window;
@property(nonatomic, readonly) bool ignoreDirectoriesOnSelectionByMask;
@property(nonatomic, readonly) unsigned long vfsFetchingFlags;
@property(nonatomic) int layoutIndex;
@property(nonatomic, readonly) nc::panel::PanelViewLayoutsStorage &layoutStorage;
@property(nonatomic, readonly) nc::core::VFSInstanceManager &vfsInstanceManager;
@property(nonatomic, readonly) bool isDoingBackgroundLoading;

- (instancetype)initWithView:(PanelView *)_panel_view
                     layouts:(std::shared_ptr<nc::panel::PanelViewLayoutsStorage>)_layouts
          vfsInstanceManager:(nc::core::VFSInstanceManager &)_vfs_mgr
     directoryAccessProvider:(nc::panel::DirectoryAccessProvider &)_directory_access_provider
         contextMenuProvider:(nc::panel::ContextMenuProvider)_context_menu_provider
             nativeFSManager:(nc::utility::NativeFSManager &)_native_fs_mgr
                  nativeHost:(nc::vfs::NativeHost &)_native_host;

- (void)refreshPanel;                 // reload panel contents
- (void)forceRefreshPanel;            // user pressed cmd+r by default
- (void)markRestorableStateAsInvalid; // will actually call window controller's invalidateRestorableState

- (void)commitCancelableLoadingTask:(std::function<void(const std::function<bool()> &_is_cancelled)>)_task;

/**
 * Will copy view options and sorting options.
 */
- (void)copyOptionsFromController:(PanelController *)_pc;

/**
 * RAII principle - when ActivityTicket dies - it will clear activity flag.
 * Thread-safe.
 */
- (nc::panel::ActivityTicket)registerExtActivity;

// panel sorting settings
- (void)changeSortingModeTo:(nc::panel::data::SortMode)_mode;
- (void)changeHardFilteringTo:(nc::panel::data::HardFilter)_filter;

// PanelView callback hooks
- (void)panelViewDidBecomeFirstResponder;
- (void)panelViewDidChangePresentationLayout;

// managing entries selection
- (void)selectEntriesWithFilenames:(const std::vector<std::string> &)_filenames;
- (void)setEntriesSelection:(const std::vector<bool> &)_selection;
- (void)setSelectionForItemAtIndex:(int)_index selected:(bool)_selected;

- (void)calculateSizesOfItems:(const std::vector<VFSListingItem> &)_items;

/**
 * This is the main directory loading facility for an external code,
 * which also works as a sync for other loading methods.
 * It can work either synchronously or asynchronously depending on the request.
 * A calling code can also set intended outcomes like focus, selection, view state restoration
 * and a completion callback.
 */
- (std::expected<void, nc::Error>)GoToDirWithContext:(std::shared_ptr<nc::panel::DirectoryChangeRequest>)_context;

/**
 * Loads existing listing into the panel. Save to call from any thread.
 */
- (void)loadListing:(const VFSListingPtr &)_listing;

/**
 * Delayed entry selection change - panel controller will memorize such request.
 * If _check_now flag is on then controller will look for requested element and if it was found - select it.
 * If there was another pending selection request - it will be overwrited by the new one.
 * Controller will check for entry appearance on every directory update.
 * Request will be removed upon directory change.
 * Once request is accomplished it will be removed.
 * If on any checking it will be found that time for request has went out - it will be removed (500ms is just ok for
 * _time_out_in_ms). Will also deselect any currenly selected items.
 */
- (void)scheduleDelayedFocusing:(const nc::panel::DelayedFocusing &)request;

- (void)requestQuickRenamingOfItem:(VFSListingItem)_item to:(const std::string &)_new_filename;

// Tells PanelController that the underground VFS was changed.
// If the current VFS doesn't provide change notifications ->
//    this will end up in reloading the listing immediately.
// Otherwise PanelController will memorize the hint and will check after some period of time that the notification
// callback actually came ->
//     If it did then the hint will be forgotten.
//     Otherwise the listing will be reloaded forcefully.
- (void)hintAboutFilesystemChange;

- (void)updateAttachedQuickLook;
- (void)updateAttachedBriefSystemOverview;

/**
 * Allows changing Data options and ensures consitency with View afterwards.
 */
- (void)changeDataOptions:(const std::function<void(nc::panel::data::Model &_data)> &)_workload;

@end

// internal stuff, move it somewehere else
@interface PanelController ()
- (void)finishExtActivityWithTicket:(uint64_t)_ticket;
- (void)CancelBackgroundOperations;
- (void)contextMenuDidClose:(NSMenu *)_menu;
@end

#include "PanelController+DataAccess.h"

template <>
struct fmt::formatter<nc::panel::DirectoryChangeRequest> : fmt::formatter<std::string> {
    constexpr auto parse(fmt::format_parse_context &ctx) { return ctx.begin(); }

    template <typename FormatContext>
    auto format(const nc::panel::DirectoryChangeRequest &_req, FormatContext &_ctx) const
    {

        return fmt::format_to(
            _ctx.out(),
            "(RequestedDirectory='{}', VFS='{}', RequestFocusedEntry='{}', RequestSelectedEntries='{}', "
            "PerformAsynchronous={}, LoadPreviousViewState={}, InitiatedByUser={})",
            _req.RequestedDirectory,
            _req.VFS->Tag(),
            _req.RequestFocusedEntry,
            _req.RequestSelectedEntries,
            _req.PerformAsynchronous,
            _req.LoadPreviousViewState,
            _req.InitiatedByUser);
    }
};
