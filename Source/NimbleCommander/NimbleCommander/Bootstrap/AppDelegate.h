// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.

#pragma once

#include <VFS/VFS_fwd.h>
#include <Cocoa/Cocoa.h>
#include <filesystem>

@class NCConfigObjCBridge;
@class NCMainWindowController;
@class InternalViewerWindowController;
class ExternalEditorsStorage;

namespace nc {

class ThemesManager;

namespace config {
class Config;
}

namespace utility {
class ActionsShortcutsManager;
class FSEventsFileUpdate;
class NativeFSManager;
class TemporaryFileStorage;
class UTIDB;
} // namespace utility

namespace core {
class VFSInstanceManager;
class ServicesHandler;
} // namespace core

namespace ops {
class AggregateProgressTracker;
class PoolEnqueueFilter;
} // namespace ops

namespace panel {
class PanelViewLayoutsStorage;
class FavoriteLocationsStorage;
class ClosedPanelsHistory;
class ExternalToolsStorage;
class TagsStorage;
class NetworkConnectionsManager;
class PanelDataPersistency;
} // namespace panel

namespace viewer {
class History;
}
namespace viewer::hl {
class SettingsStorage;
}

namespace vfs {
class NativeHost;
}

} // namespace nc

@interface NCAppDelegate : NSObject <NSApplicationDelegate, NSWindowRestoration>

- (InternalViewerWindowController *)findInternalViewerWindowForPath:(const std::string &)_path
                                                              onVFS:(const std::shared_ptr<VFSHost> &)_vfs;
/**
 * Searches for an existing window with corresponding path,
 * if it is not found - allocates a new non-shown one.
 */
- (InternalViewerWindowController *)retrieveInternalViewerWindowForPath:(const std::string &)_path
                                                                  onVFS:(const std::shared_ptr<VFSHost> &)_vfs;

/**
 * Runs a modal dialog window, which asks user if he wants to reset app settings.
 * Returns true if defaults were actually reset.
 */
- (bool)askToResetDefaults;

/** Returns all main windows currently present. */
@property(nonatomic, readonly) const std::vector<NCMainWindowController *> &mainWindowControllers;

/**
 * Equal to (NCAppDelegate*) ((NSApplication*)NSApp).delegate.
 */
+ (NCAppDelegate *)me;

/**
 * Support dir, ~/Library/Application Support/Nimble Commander/.
 * Is in Containers for Sandboxes versions
 */
@property(nonatomic, readonly) const std::filesystem::path &supportDirectory;

/**
 * By default this dir is ~/Library/Application Support/Nimble Commander/Config/.
 * May change in the future.
 */
@property(nonatomic, readonly) const std::filesystem::path &configDirectory;

/**
 * This dir is ~/Library/Application Support/Nimble Commander/State/.
 */
@property(nonatomic, readonly) const std::filesystem::path &stateDirectory;

@property(nonatomic, readonly) NCConfigObjCBridge *config;

@property(nonatomic, readonly) nc::config::Config &globalConfig;

@property(nonatomic, readonly) nc::config::Config &stateConfig;

@property(nonatomic, readonly) nc::panel::ExternalToolsStorage &externalTools;

@property(nonatomic, readonly) const std::shared_ptr<nc::panel::PanelViewLayoutsStorage> &panelLayouts;

@property(nonatomic, readonly) nc::ThemesManager &themesManager;

@property(nonatomic, readonly) ExternalEditorsStorage &externalEditorsStorage;

@property(nonatomic, readonly) const std::shared_ptr<nc::panel::FavoriteLocationsStorage> &favoriteLocationsStorage;

@property(nonatomic, readonly) const std::shared_ptr<nc::panel::NetworkConnectionsManager> &networkConnectionsManager;

@property(nonatomic, readonly) nc::ops::AggregateProgressTracker &operationsProgressTracker;

@property(nonatomic, readonly) const std::shared_ptr<nc::panel::ClosedPanelsHistory> &closedPanelsHistory;

@property(nonatomic, readonly) nc::core::VFSInstanceManager &vfsInstanceManager;

@property(nonatomic, readonly) nc::core::ServicesHandler &servicesHandler;

@property(nonatomic, readonly) nc::utility::NativeFSManager &nativeFSManager;

@property(nonatomic, readonly) nc::utility::TemporaryFileStorage &temporaryFileStorage;

@property(nonatomic, readonly) nc::viewer::History &internalViewerHistory;

@property(nonatomic, readonly) nc::utility::UTIDB &utiDB;

@property(nonatomic, readonly) nc::vfs::NativeHost &nativeHost;

@property(nonatomic, readonly) const std::shared_ptr<nc::vfs::NativeHost> &nativeHostPtr;

@property(nonatomic, readonly) nc::utility::FSEventsFileUpdate &fsEventsFileUpdate;

@property(nonatomic, readonly) nc::ops::PoolEnqueueFilter &poolEnqueueFilter;

@property(nonatomic, readonly) nc::panel::TagsStorage &tagsStorage;

@property(nonatomic, readonly) nc::viewer::hl::SettingsStorage &syntaxHighlightingSettingsStorage;

@property(nonatomic, readonly) nc::panel::PanelDataPersistency &panelDataPersistency;

@property(nonatomic, readonly) nc::utility::ActionsShortcutsManager &actionsShortcutsManager;

@end
