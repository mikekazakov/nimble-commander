// Copyright (C) 2018-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AppDelegate+MainWindowCreation.h"
#include "AppDelegate.Private.h"
#include <VFSIcon/IconRepositoryImpl.h>
#include <VFSIcon/IconBuilderImpl.h>
#include <VFSIcon/QLThumbnailsCacheImpl.h>
#include <VFSIcon/WorkspaceIconsCacheImpl.h>
#include <VFSIcon/WorkspaceExtensionIconsCacheImpl.h>
#include <Utility/BriefOnDiskStorageImpl.h>
#include <Utility/SystemInformation.h>
#include <VFSIcon/QLVFSThumbnailsCacheImpl.h>
#include <VFSIcon/VFSBundleIconsCacheImpl.h>
#include <VFSIcon/ExtensionsWhitelistImpl.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/States/MainWindow.h>
#include <NimbleCommander/States/FilePanels/MainWindowFilePanelState.h>
#include <NimbleCommander/States/FilePanels/PanelController.h>
#include <NimbleCommander/States/FilePanels/PanelView.h>
#include <NimbleCommander/States/FilePanels/PanelViewHeader.h>
#include <NimbleCommander/States/FilePanels/PanelViewHeaderThemeImpl.h>
#include <NimbleCommander/States/FilePanels/PanelViewFooter.h>
#include <NimbleCommander/States/FilePanels/PanelViewFooterThemeImpl.h>
#include <NimbleCommander/States/FilePanels/PanelControllerActionsDispatcher.h>
#include <NimbleCommander/States/FilePanels/PanelControllerActions.h>
#include <NimbleCommander/States/FilePanels/PanelAux.h>
#include <NimbleCommander/States/FilePanels/ContextMenu.h>
#include <NimbleCommander/States/FilePanels/NCPanelOpenWithMenuDelegate.h>
#include <NimbleCommander/States/FilePanels/StateActionsDispatcher.h>
#include <NimbleCommander/States/FilePanels/StateActions.h>
#include <NimbleCommander/States/FilePanels/Views/QuickLookPanel.h>
#include <NimbleCommander/States/FilePanels/Views/QuickLookVFSBridge.h>
#include <Operations/Pool.h>
#include <Operations/PoolEnqueueFilter.h>
#include <Operations/AggregateProgressTracker.h>
#include "Config.h"
#include <Base/CommonPaths.h>
#include <Base/algo.h>
#include <Base/debug.h>
#include <NimbleCommander/Core/SandboxManager.h>
#include "AppDelegate+ViewerCreation.h"
#include <ranges>

static const auto g_ConfigRestoreLastWindowState = "filePanel.general.restoreLastWindowState";

namespace {

enum class CreationContext : uint8_t {
    Default,
    ManualRestoration,
    SystemRestoration
};

class DirectoryAccessProviderImpl : public nc::panel::DirectoryAccessProvider
{
public:
    bool HasAccess(PanelController *_panel, const std::string &_directory_path, VFSHost &_host) override;
    bool RequestAccessSync(PanelController *_panel, const std::string &_directory_path, VFSHost &_host) override;
};

} // namespace

static bool RestoreFilePanelStateFromLastOpenedWindow(MainWindowFilePanelState *_state);

@implementation NCAppDelegate (MainWindowCreation)

- (NCMainWindow *)allocateMainWindow
{
    auto window = [[NCMainWindow alloc] init];
    if( !window )
        return nil;
    window.restorationClass = self.class;
    return window;
}

- (const nc::panel::PanelActionsMap &)panelActionsMap
{
    [[clang::no_destroy]] static auto actions_map = nc::panel::BuildPanelActionsMap(
        self.globalConfig,
        *self.networkConnectionsManager,
        self.nativeFSManager,
        self.nativeHost,
        self.tagsStorage,
        self.fileOpener,
        self.panelOpenWithMenuDelegate,
        [self](NSRect rc) { return [self makeViewerWithFrame:rc]; },
        [self] { return [self makeViewerController]; });
    return actions_map;
}

- (const nc::panel::StateActionsMap &)stateActionsMap
{
    [[clang::no_destroy]] static auto actions_map = nc::panel::BuildStateActionsMap(self.globalConfig,
                                                                                    *self.networkConnectionsManager,
                                                                                    self.temporaryFileStorage,
                                                                                    self.nativeFSManager,
                                                                                    self.tagsStorage);
    return actions_map;
}

static std::vector<std::string> CommaSeparatedStrings(const nc::config::Config &_config, std::string_view _path)
{
    const auto strings = _config.GetString(_path);

    std::vector<std::string> split;
    for( const auto str : std::views::split(std::string_view{strings}, ',') )
        if( auto trimmed = nc::base::Trim(std::string_view{str}); !trimmed.empty() )
            split.emplace_back(trimmed);
    return split;
}

- (std::unique_ptr<nc::vfsicon::IconRepository>)allocateIconRepository
{
    [[clang::no_destroy]] static const auto ql_cache = std::make_shared<nc::vfsicon::QLThumbnailsCacheImpl>();
    [[clang::no_destroy]] static const auto ws_cache = std::make_shared<nc::vfsicon::WorkspaceIconsCacheImpl>();
    [[clang::no_destroy]] static const auto ext_cache =
        std::make_shared<nc::vfsicon::WorkspaceExtensionIconsCacheImpl>(self.utiDB);
    [[clang::no_destroy]] static const auto brief_storage = std::make_shared<nc::utility::BriefOnDiskStorageImpl>(
        nc::base::CommonPaths::AppTemporaryDirectory(), nc::utility::GetBundleID() + ".ico");
    [[clang::no_destroy]] static const auto vfs_cache =
        std::make_shared<nc::vfsicon::QLVFSThumbnailsCacheImpl>(brief_storage);
    [[clang::no_destroy]] static const auto vfs_bi_cache = std::make_shared<nc::vfsicon::VFSBundleIconsCacheImpl>();
    [[clang::no_destroy]] static const auto extensions_whitelist =
        std::make_shared<nc::vfsicon::ExtensionsWhitelistImpl>(
            self.utiDB, CommaSeparatedStrings(self.globalConfig, "filePanel.presentation.quickLookIconsWhitelist"));

    [[clang::no_destroy]] static const auto icon_builder = std::make_shared<nc::vfsicon::IconBuilderImpl>(
        ql_cache, ws_cache, ext_cache, vfs_cache, vfs_bi_cache, extensions_whitelist);
    const auto concurrency_per_repo = 4;
    using Que = nc::vfsicon::detail::IconRepositoryImplBase::GCDLimitedConcurrentQueue;

    return std::make_unique<nc::vfsicon::IconRepositoryImpl>(icon_builder, std::make_unique<Que>(concurrency_per_repo));
}

- (nc::panel::DirectoryAccessProvider &)directoryAccessProvider
{
    [[clang::no_destroy]] static auto provider = DirectoryAccessProviderImpl{};
    return provider;
}

- (nc::panel::ControllerStateJSONDecoder &)controllerStateJSONDecoder
{
    static auto decoder =
        nc::panel::ControllerStateJSONDecoder(self.nativeFSManager, self.vfsInstanceManager, self.panelDataPersistency);
    return decoder;
}

- (PanelView *)allocatePanelView
{
    const auto header =
        [[NCPanelViewHeader alloc] initWithFrame:NSRect()
                                           theme:std::make_unique<nc::panel::HeaderThemeImpl>(self.themesManager)];
    const auto footer =
        [[NCPanelViewFooter alloc] initWithFrame:NSRect()
                                           theme:std::make_unique<nc::panel::FooterThemeImpl>(self.themesManager)];

    const auto pv_rect = NSMakeRect(0, 0, 100, 100);
    return [[PanelView alloc] initWithFrame:pv_rect
                             iconRepository:[self allocateIconRepository]
                    actionsShortcutsManager:self.actionsShortcutsManager
                                  nativeVFS:self.nativeHost
                                     header:header
                                     footer:footer];
}

- (PanelController *)allocatePanelController
{
    auto panel = [[PanelController alloc] initWithView:[self allocatePanelView]
                                               layouts:self.panelLayouts
                                    vfsInstanceManager:self.vfsInstanceManager
                               directoryAccessProvider:self.directoryAccessProvider
                                   contextMenuProvider:[self makePanelContextMenuProvider]
                                       nativeFSManager:self.nativeFSManager
                                            nativeHost:self.nativeHost];
    auto actions_dispatcher =
        [[NCPanelControllerActionsDispatcher alloc] initWithController:panel
                                                            actionsMap:self.panelActionsMap
                                               actionsShortcutsManager:self.actionsShortcutsManager];
    [panel setNextAttachedResponder:actions_dispatcher];
    [panel.view addKeystrokeSink:actions_dispatcher];
    panel.view.actionsDispatcher = actions_dispatcher;

    return panel;
}

static PanelController *PanelFactory()
{
    return [NCAppDelegate.me allocatePanelController];
}

- (MainWindowFilePanelState *)allocateFilePanelsWithFrame:(NSRect)_frame
                                                inContext:(CreationContext)_context
                                              withOpsPool:(nc::ops::Pool &)_operations_pool
{
    auto &ctrl_state_json_decoder = self.controllerStateJSONDecoder;
    if( _context == CreationContext::Default ) {
        return [[MainWindowFilePanelState alloc] initWithFrame:_frame
                                                       andPool:_operations_pool
                                            loadDefaultContent:true
                                                  panelFactory:PanelFactory
                                    controllerStateJSONDecoder:ctrl_state_json_decoder
                                                QLPanelAdaptor:self.QLPanelAdaptor];
    }
    else if( _context == CreationContext::ManualRestoration ) {
        if( NCMainWindowController.canRestoreDefaultWindowStateFromLastOpenedWindow ) {
            auto state = [[MainWindowFilePanelState alloc] initWithFrame:_frame
                                                                 andPool:_operations_pool
                                                      loadDefaultContent:false
                                                            panelFactory:PanelFactory
                                              controllerStateJSONDecoder:ctrl_state_json_decoder
                                                          QLPanelAdaptor:self.QLPanelAdaptor];
            RestoreFilePanelStateFromLastOpenedWindow(state);
            [state loadDefaultPanelContent];
            return state;
        }
        else if( GlobalConfig().GetBool(g_ConfigRestoreLastWindowState) ) {
            auto state = [[MainWindowFilePanelState alloc] initWithFrame:_frame
                                                                 andPool:_operations_pool
                                                      loadDefaultContent:false
                                                            panelFactory:PanelFactory
                                              controllerStateJSONDecoder:ctrl_state_json_decoder
                                                          QLPanelAdaptor:self.QLPanelAdaptor];
            if( ![NCMainWindowController restoreDefaultWindowStateFromConfig:state] )
                [state loadDefaultPanelContent];
            return state;
        }
        else { // if we can't restore a window - fall back into a default creation context
            return [self allocateFilePanelsWithFrame:_frame
                                           inContext:CreationContext::Default
                                         withOpsPool:_operations_pool];
        }
    }
    else if( _context == CreationContext::SystemRestoration ) {
        return [[MainWindowFilePanelState alloc] initWithFrame:_frame
                                                       andPool:_operations_pool
                                            loadDefaultContent:false
                                                  panelFactory:PanelFactory
                                    controllerStateJSONDecoder:ctrl_state_json_decoder
                                                QLPanelAdaptor:self.QLPanelAdaptor];
    }
    return nil;
}

- (NCMainWindowController *)allocateMainWindowInContext:(CreationContext)_context
{
    const auto window = [self allocateMainWindow];
    const auto frame = window.contentView.frame;
    const auto operations_pool = nc::ops::Pool::Make();
    operations_pool->SetConcurrency(self.globalConfig.GetInt("filePanel.operations.concurrencyPerWindow"));
    operations_pool->SetEnqueuingCallback(
        [filter = &NCAppDelegate.me.poolEnqueueFilter](const nc::ops::Operation &_operation) {
            return filter->ShouldEnqueue(_operation);
        });

    const auto window_controller = [[NCMainWindowController alloc] initWithWindow:window];
    window_controller.operationsPool = *operations_pool;
    self.operationsProgressTracker.AddPool(*operations_pool);

    const auto file_state = [self allocateFilePanelsWithFrame:frame inContext:_context withOpsPool:*operations_pool];
    auto actions_dispatcher = [[NCPanelsStateActionsDispatcher alloc] initWithState:file_state
                                                                         actionsMap:self.stateActionsMap
                                                         andActionsShortcutsManager:self.actionsShortcutsManager];
    actions_dispatcher.hasTerminal = !nc::base::AmISandboxed();
    file_state.attachedResponder = actions_dispatcher;

    file_state.closedPanelsHistory = self.closedPanelsHistory;
    file_state.favoriteLocationsStorage = self.favoriteLocationsStorage;

    window_controller.filePanelsState = file_state;

    [self addMainWindow:window_controller];
    return window_controller;
}

- (NCMainWindowController *)allocateDefaultMainWindow
{
    return [self allocateMainWindowInContext:CreationContext::Default];
}

- (NCMainWindowController *)allocateMainWindowRestoredManually
{
    return [self allocateMainWindowInContext:CreationContext::ManualRestoration];
}

- (NCMainWindowController *)allocateMainWindowRestoredBySystem
{
    return [self allocateMainWindowInContext:CreationContext::SystemRestoration];
}

- (nc::panel::QuickLookVFSBridge &)QLVFSBridge
{
    static const auto instance = new nc::panel::QuickLookVFSBridge(self.temporaryFileStorage);
    return *instance;
}

- (NCPanelQLPanelAdaptor *)QLPanelAdaptor
{
    static const auto instance = [[NCPanelQLPanelAdaptor alloc] initWithBridge:[self QLVFSBridge]];
    return instance;
}

- (nc::panel::FileOpener &)fileOpener
{
    static auto instance = nc::panel::FileOpener{self.temporaryFileStorage};
    return instance;
}

- (NCPanelOpenWithMenuDelegate *)panelOpenWithMenuDelegate
{
    static const auto delegate = [[NCPanelOpenWithMenuDelegate alloc] initWithFileOpener:self.fileOpener
                                                                                   utiDB:self.utiDB];
    return delegate;
}

- (nc::panel::ContextMenuProvider)makePanelContextMenuProvider
{
    auto provider = [self](std::vector<VFSListingItem> _items, PanelController *_panel) -> NCPanelContextMenu * {
        return [[NCPanelContextMenu alloc] initWithItems:std::move(_items)
                                                 ofPanel:_panel
                                          withFileOpener:self.fileOpener
                                               withUTIDB:self.utiDB];
    };
    return nc::panel::ContextMenuProvider{std::move(provider)};
}

@end

static bool RestoreFilePanelStateFromLastOpenedWindow(MainWindowFilePanelState *_state)
{
    const auto last = NCMainWindowController.lastFocused;
    if( !last )
        return false;

    const auto source_state = last.filePanelsState;
    [_state.leftPanelController copyOptionsFromController:source_state.leftPanelController];
    [_state.rightPanelController copyOptionsFromController:source_state.rightPanelController];
    return true;
}

bool DirectoryAccessProviderImpl::HasAccess([[maybe_unused]] PanelController *_panel,
                                            const std::string &_directory_path,
                                            VFSHost &_host)
{
    // at this moment we (thankfully) care only about sanboxed versions
    if( !nc::base::AmISandboxed() )
        return true;

    if( _host.IsNativeFS() )
        return SandboxManager::Instance().CanAccessFolder(_directory_path);
    else
        return true;
}

bool DirectoryAccessProviderImpl::RequestAccessSync([[maybe_unused]] PanelController *_panel,
                                                    const std::string &_directory_path,
                                                    VFSHost &_host)
{
    if( !nc::base::AmISandboxed() )
        return true;

    if( _host.IsNativeFS() )
        return SandboxManager::EnsurePathAccess(_directory_path); // <-- the code smell see I here!
    else
        return true;

    return true;
}
