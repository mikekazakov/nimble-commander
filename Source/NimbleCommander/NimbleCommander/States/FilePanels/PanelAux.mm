// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <VFS/Native.h>
#include <Utility/ExtensionLowercaseComparison.h>
#include <Utility/TemporaryFileStorage.h>
#include <NimbleCommander/Core/TemporaryNativeFileChangesSentinel.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/NativeVFSHostInstance.h>
#include <NimbleCommander/States/FilePanels/PanelController.h>
#include <NimbleCommander/States/MainWindowController.h>
#include "PanelAux.h"
#include "ExternalEditorInfo.h"
#include <Operations/Copying.h>
#include <Base/dispatch_cpp.h>
#include <Utility/StringExtras.h>

// TODO: remove this, DI stuff instead
#include <NimbleCommander/Bootstrap/AppDelegate.h>

using nc::vfs::easy::CopyFileToTempStorage;

namespace nc::panel {

static const auto g_ConfigArchivesExtensionsWhiteList = "filePanel.general.archivesExtensionsWhitelist";
static const auto g_ConfigExecutableExtensionsWhitelist = "filePanel.general.executableExtensionsWhitelist";
static const auto g_ConfigDefaultVerificationSetting = "filePanel.operations.defaultChecksumVerification";
static const auto g_CheckDelay = "filePanel.operations.vfsShadowUploadChangesCheckDelay";
static const auto g_DropDelay = "filePanel.operations.vfsShadowUploadObservationDropDelay";
static const auto g_QLPanel = "filePanel.presentation.showQuickLookAsFloatingPanel";
static const uint64_t g_MaxFileSizeForVFSOpen = 64ull * 1024ull * 1024ull; // 64mb

static std::chrono::milliseconds UploadingCheckDelay()
{
    static const auto fetch = [] {
        const auto value = GlobalConfig().Has(g_CheckDelay) ? GlobalConfig().GetInt(g_CheckDelay) : 5000;
        return std::chrono::milliseconds(value);
    };
    static std::chrono::milliseconds delay = [] {
        [[clang::no_destroy]] static auto ticket = GlobalConfig().Observe(g_CheckDelay, [] { delay = fetch(); });
        return fetch();
    }();
    return delay;
}

static std::chrono::milliseconds UploadingDropDelay()
{
    static const auto fetch = [] {
        const auto value = GlobalConfig().Has(g_DropDelay) ? GlobalConfig().GetInt(g_DropDelay) : 3600000;
        return std::chrono::milliseconds(value);
    };
    static std::chrono::milliseconds delay = [] {
        [[clang::no_destroy]] static auto ticket = GlobalConfig().Observe(g_DropDelay, [] { delay = fetch(); });
        return fetch();
    }();
    return delay;
}

static void RegisterRemoteFileUploading(const std::string &_original_path,
                                        const VFSHostPtr &_original_vfs,
                                        const std::string &_native_path,
                                        PanelController *_origin)
{
    if( _original_vfs->IsNativeFS() )
        return; // no reason to watch files from native fs

    if( !_original_vfs->IsWritable() )
        return; // no reason to watch file we can't upload then

    __weak NCMainWindowController *origin_window = _origin.mainWindowController;
    __weak PanelController *origin_controller = _origin;
    const VFSHostWeakPtr weak_host(_original_vfs);

    auto on_file_change = [=] {
        NCMainWindowController *const window = origin_window;
        if( !window )
            return;

        auto vfs = weak_host.lock();
        if( !vfs )
            return;

        auto &storage_host = nc::bootstrap::NativeVFSHostInstance();
        const auto changed_item_directory = std::filesystem::path(_native_path).parent_path().native();
        const auto changed_item_filename = std::filesystem::path(_native_path).filename().native();
        // TODO: why is FetchFlexibleListingItems() used here instead of FetchSingleItemListing()?
        const std::expected<std::vector<VFSListingItem>, Error> listing_items =
            storage_host.FetchFlexibleListingItems(changed_item_directory, {1, changed_item_filename}, 0);
        if( listing_items ) {
            auto opts = panel::MakeDefaultFileCopyOptions();
            opts.exist_behavior = nc::ops::CopyingOptions::ExistBehavior::OverwriteAll;
            const auto op = std::make_shared<nc::ops::Copying>(*listing_items, _original_path, vfs, opts);
            if( static_cast<PanelController *>(origin_controller) )
                op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=] {
                    dispatch_to_main_queue([=] {
                        // TODO: perhaps need to check that path didn't changed
                        [static_cast<PanelController *>(origin_controller) hintAboutFilesystemChange];
                    });
                });
            [window enqueueOperation:op];
        }
    };

    auto &sentinel = TemporaryNativeFileChangesSentinel::Instance();
    sentinel.WatchFile(_native_path, on_file_change, UploadingCheckDelay(), UploadingDropDelay());
}

FileOpener::FileOpener(nc::utility::TemporaryFileStorage &_temp_storage) : m_TemporaryFileStorage{_temp_storage}
{
}

void FileOpener::Open(std::string _filepath, std::shared_ptr<VFSHost> _host, PanelController *_panel)
{
    Open(_filepath, _host, "", _panel);
}

void FileOpener::Open(std::string _filepath,
                      std::shared_ptr<VFSHost> _host,
                      std::string _with_app_path,
                      PanelController *_panel)
{
    if( _host->IsNativeFS() ) {
        NSString *const filename = [NSString stringWithUTF8String:_filepath.c_str()];

        if( !_with_app_path.empty() ) {
            if( ![[NSWorkspace sharedWorkspace] openFile:filename
                                         withApplication:[NSString stringWithUTF8String:_with_app_path.c_str()]] )
                NSBeep();
        }
        else {
            if( ![[NSWorkspace sharedWorkspace] openFile:filename] )
                NSBeep();
        }

        return;
    }

    dispatch_to_default([=, this] {
        auto activity_ticket = [_panel registerExtActivity];
        if( _host->IsDirectory(_filepath, 0, nullptr) ) {
            NSBeep();
            return;
        }

        const std::expected<VFSStat, Error> st = _host->Stat(_filepath, 0);
        if( !st ) {
            NSBeep();
            return;
        }

        if( st->size > g_MaxFileSizeForVFSOpen ) {
            NSBeep();
            return;
        }

        if( auto tmp_path = CopyFileToTempStorage(_filepath, *_host, m_TemporaryFileStorage) ) {
            RegisterRemoteFileUploading(_filepath, _host, *tmp_path, _panel);

            NSString *const fn = [NSString stringWithUTF8StdString:*tmp_path];
            dispatch_to_main_queue([=] {
                if( !_with_app_path.empty() ) {
                    if( ![NSWorkspace.sharedWorkspace openFile:fn
                                               withApplication:[NSString stringWithUTF8StdString:_with_app_path]] )
                        NSBeep();
                }
                else {
                    if( ![NSWorkspace.sharedWorkspace openFile:fn] )
                        NSBeep();
                }
            });
        }
        else
            NSBeep();
    });
}

// TODO: write version with FlexListingItem as an input - it would be much simplier
void FileOpener::Open(std::vector<std::string> _filepaths,
                      std::shared_ptr<VFSHost> _host,
                      NSString *_with_app_bundle, // can be nil, use default app in such case
                      PanelController *_panel)
{
    if( _host->IsNativeFS() ) {
        NSMutableArray *const arr = [NSMutableArray arrayWithCapacity:_filepaths.size()];
        for( auto &i : _filepaths )
            if( NSString *const s = [NSString stringWithUTF8String:i.c_str()] )
                [arr addObject:[[NSURL alloc] initFileURLWithPath:s]];

        if( ![NSWorkspace.sharedWorkspace openURLs:arr
                           withAppBundleIdentifier:_with_app_bundle
                                           options:0
                    additionalEventParamDescriptor:nil
                                 launchIdentifiers:nil] )
            NSBeep();

        return;
    }

    dispatch_to_default([=, this] {
        auto activity_ticket = [_panel registerExtActivity];
        NSMutableArray *const arr = [NSMutableArray arrayWithCapacity:_filepaths.size()];
        for( auto &i : _filepaths ) {
            if( _host->IsDirectory(i, 0, nullptr) )
                continue;

            const std::expected<VFSStat, Error> st = _host->Stat(i, 0);
            if( !st )
                continue;

            if( st->size > g_MaxFileSizeForVFSOpen )
                continue;

            if( auto tmp_path = CopyFileToTempStorage(i, *_host, m_TemporaryFileStorage) ) {
                RegisterRemoteFileUploading(i, _host, *tmp_path, _panel);
                if( NSString *const s = [NSString stringWithUTF8StdString:*tmp_path] )
                    [arr addObject:[[NSURL alloc] initFileURLWithPath:s]];
            }
        }

        if( ![NSWorkspace.sharedWorkspace openURLs:arr
                           withAppBundleIdentifier:_with_app_bundle
                                           options:0
                    additionalEventParamDescriptor:nil
                                 launchIdentifiers:nil] )
            NSBeep();
    });
}

void FileOpener::OpenInExternalEditorTerminal(std::string _filepath,
                                              VFSHostPtr _host,
                                              std::shared_ptr<ExternalEditorStartupInfo> _ext_ed,
                                              std::string _file_title,
                                              PanelController *_panel)
{
    assert(!_filepath.empty() && _host && _ext_ed && _panel);

    if( _host->IsNativeFS() ) {
        if( auto wnd = static_cast<NCMainWindowController *>(_panel.window.delegate) )
            [wnd RequestExternalEditorTerminalExecution:_ext_ed->Path()
                                                 params:_ext_ed->SubstituteFileName(_filepath)
                                              fileTitle:_file_title];
    }
    else
        dispatch_to_default([=,
                             this] { // do downloading down in a background thread
            auto activity_ticket = [_panel registerExtActivity];

            if( _host->IsDirectory(_filepath, 0, nullptr) ) {
                NSBeep();
                return;
            }

            const std::expected<VFSStat, Error> st = _host->Stat(_filepath, 0);
            if( !st ) {
                NSBeep();
                return;
            }

            if( st->size > g_MaxFileSizeForVFSOpen ) {
                NSBeep();
                return;
            }

            if( auto tmp_path = CopyFileToTempStorage(_filepath, *_host, m_TemporaryFileStorage) ) {
                RegisterRemoteFileUploading(_filepath, _host, *tmp_path, _panel);
                dispatch_to_main_queue([=] { // when we sucessfuly download a file -
                                             // request terminal execution in main
                                             // thread
                    if( auto wnd = static_cast<NCMainWindowController *>(_panel.window.delegate) )
                        [wnd RequestExternalEditorTerminalExecution:_ext_ed->Path()
                                                             params:_ext_ed->SubstituteFileName(*tmp_path)
                                                          fileTitle:_file_title];
                });
            }
        });
}

bool IsEligbleToTryToExecuteInConsole(const VFSListingItem &_item)
{
    if( _item.IsDir() )
        return false;

    // TODO: need more sophisticated executable handling here
    // THIS IS WRONG!
    const bool uexec = (_item.UnixMode() & S_IXUSR) || (_item.UnixMode() & S_IXGRP) || (_item.UnixMode() & S_IXOTH);

    if( !uexec )
        return false;

    if( !_item.HasExtension() )
        return true; // if file has no extension and had execute rights - let's try it

    [[clang::no_destroy]] static const utility::ExtensionsLowercaseList extensions(
        GlobalConfig().GetString(g_ConfigExecutableExtensionsWhitelist));

    return extensions.contains(_item.Extension());
}

static ops::CopyingOptions::ChecksumVerification DefaultChecksumVerificationSetting()
{
    // TODO: make depencies on Config explicit
    const int v = GlobalConfig().GetInt(g_ConfigDefaultVerificationSetting);
    if( v == static_cast<int>(ops::CopyingOptions::ChecksumVerification::Always) )
        return ops::CopyingOptions::ChecksumVerification::Always;
    else if( v == static_cast<int>(ops::CopyingOptions::ChecksumVerification::WhenMoves) )
        return ops::CopyingOptions::ChecksumVerification::WhenMoves;
    else
        return ops::CopyingOptions::ChecksumVerification::Never;
}

ops::CopyingOptions MakeDefaultFileCopyOptions()
{
    ops::CopyingOptions options;
    options.docopy = true;
    options.verification = DefaultChecksumVerificationSetting();

    return options;
}

ops::CopyingOptions MakeDefaultFileMoveOptions()
{
    ops::CopyingOptions options;
    options.docopy = false;
    options.verification = DefaultChecksumVerificationSetting();

    return options;
}

bool IsExtensionInArchivesWhitelist(std::string_view _ext) noexcept
{
    if( _ext.empty() )
        return false;
    [[clang::no_destroy]] static const utility::ExtensionsLowercaseList archive_extensions(
        GlobalConfig().GetString(g_ConfigArchivesExtensionsWhiteList));
    return archive_extensions.contains(_ext);
}

bool ShowQuickLookAsFloatingPanel() noexcept
{
    static const auto fetch = [] { return GlobalConfig().GetBool(g_QLPanel); };
    static bool value = [] {
        GlobalConfig().ObserveForever(g_QLPanel, [] { value = fetch(); });
        return fetch();
    }();
    return value;
}

} // namespace nc::panel
