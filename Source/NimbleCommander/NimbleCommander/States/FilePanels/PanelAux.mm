// Copyright (C) 2013-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <VFS/Native.h>
#include <Utility/ExtensionLowercaseComparison.h>
#include <Utility/PathManip.h>
#include <Utility/TemporaryFileStorage.h>
#include <NimbleCommander/Core/TemporaryNativeFileChangesSentinel.h>
#include <NimbleCommander/Core/LaunchServices.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/NativeVFSHostInstance.h>
#include <NimbleCommander/States/FilePanels/PanelController.h>
#include <NimbleCommander/States/MainWindowController.h>
#include "PanelAux.h"
#include "ExternalEditorInfo.h"
#include <Operations/Copying.h>
#include <Base/dispatch_cpp.h>
#include <Utility/StringExtras.h>
#include <ranges>

// TODO: remove this, DI stuff instead
#include <NimbleCommander/Bootstrap/AppDelegate.h>

using nc::vfs::easy::CopyFileToTempStorage;

namespace nc::panel {

static const std::string_view g_ConfigArchivesExtensionsWhiteList = "filePanel.general.archivesExtensionsWhitelist";
static const std::string_view g_ConfigExecutableExtensionsWhitelist = "filePanel.general.executableExtensionsWhitelist";
static const std::string_view g_ConfigDefaultVerificationSetting = "filePanel.operations.defaultChecksumVerification";
static const std::string_view g_ConfigDisableSystemCaches = "filePanel.operations.disableSystemCaches";
static const std::string_view g_CheckDelay = "filePanel.operations.vfsShadowUploadChangesCheckDelay";
static const std::string_view g_DropDelay = "filePanel.operations.vfsShadowUploadObservationDropDelay";
static const std::string_view g_QLPanel = "filePanel.presentation.showQuickLookAsFloatingPanel";

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
        const std::expected<std::vector<VFSListingItem>, Error> listing_items = storage_host.FetchFlexibleListingItems(
            changed_item_directory, {1, changed_item_filename}, vfs::Flags::None);
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

FileOpener::FileOpener(nc::utility::TemporaryFileStorage &_temp_storage,
                       nc::utility::UTIDB &_uti_db,
                       uint64_t _vfs_threshold_for_implicit_opening)
    : m_TemporaryFileStorage{_temp_storage}, //
      m_UTIDB{_uti_db},                      //
      m_VFSThresholdForImplicitOpening{_vfs_threshold_for_implicit_opening}
{
}

void FileOpener::Open(std::string_view _file_at_path,
                      std::shared_ptr<VFSHost> _in_host,
                      PanelController *_within_panel,
                      std::string_view _with_app_at_path)
{
    if( _in_host->IsNativeFS() ) {
        // TODO: this can potentially block. Think about moving this to a background thread and providing a completion
        // callback.
        NSString *const filename = [NSString stringWithUTF8StdStringView:_file_at_path];

        NSURL *const file_url = [NSURL fileURLWithPath:filename];
        if( !_with_app_at_path.empty() ) {
            NSURL *const app_url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdStringView:_with_app_at_path]];
            [[NSWorkspace sharedWorkspace] openURLs:@[file_url]
                               withApplicationAtURL:app_url
                                      configuration:[NSWorkspaceOpenConfiguration configuration]
                                  completionHandler:^(NSRunningApplication *_app, NSError *) {
                                    if( !_app )
                                        NSBeep();
                                  }];
        }
        else {
            if( ![[NSWorkspace sharedWorkspace] openURL:file_url] )
                NSBeep();
        }
    }
    else {
        auto worker = [filepath = std::string{_file_at_path},
                       panel = _within_panel,
                       host = _in_host,
                       with_app_path = std::string{_with_app_at_path},
                       this] {
            dispatch_assert_background_queue();

            auto activity_ticket = [panel registerExtActivity];
            if( host->IsDirectory(filepath, vfs::Flags::None) ) {
                NSBeep();
                return;
            }

            const std::expected<VFSStat, Error> st = host->Stat(filepath, vfs::Flags::None);
            if( !st ) {
                NSBeep(); // TODO: shown an error?
                return;
            }

            if( st->size > m_VFSThresholdForImplicitOpening ) {
                const bool allow = AskUserForPermissionToOpenLargeVFSFile(filepath, st->size, panel); // NB! Blocking!
                if( !allow ) {
                    return;
                }
            }

            if( const std::optional<std::filesystem::path> tmp_path =
                    CopyFileToTempStorage(filepath, *host, m_TemporaryFileStorage) ) {
                RegisterRemoteFileUploading(filepath, host, *tmp_path, panel);

                NSString *const fn = [NSString stringWithUTF8StdString:*tmp_path];
                dispatch_to_main_queue([=] {
                    NSURL *const file_url = [NSURL fileURLWithPath:fn];
                    if( !with_app_path.empty() ) {
                        NSURL *const app_url =
                            [NSURL fileURLWithPath:[NSString stringWithUTF8StdStringView:with_app_path]];
                        [[NSWorkspace sharedWorkspace] openURLs:@[file_url]
                                           withApplicationAtURL:app_url
                                                  configuration:[NSWorkspaceOpenConfiguration configuration]
                                              completionHandler:^(NSRunningApplication *_app, NSError *) {
                                                if( !_app )
                                                    NSBeep();
                                              }];
                    }
                    else {
                        if( ![[NSWorkspace sharedWorkspace] openURL:file_url] )
                            NSBeep();
                    }
                });
            }
            else
                NSBeep();
        };
        dispatch_to_default(std::move(worker));
    }
}

// TODO: write version with FlexListingItem as an input - it would be much simplier
void FileOpener::Open(std::span<std::string> _filepaths,
                      std::shared_ptr<VFSHost> _host,
                      PanelController *_panel,
                      std::string_view _with_app_at_path)
{
    // If there's no explicit app bundle - try to deduce default one from the input
    std::string effective_handler_app_path{_with_app_at_path};
    if( effective_handler_app_path.empty() ) {
        effective_handler_app_path = DeduceDefaultAppBundleForOpeningFiles(_filepaths, _host);
    }

    // If we have app bundle identifier - try to get app url for it
    NSURL *handler_app_url = nil;
    if( !effective_handler_app_path.empty() ) {
        handler_app_url = [NSURL fileURLWithPath:[NSString stringWithUTF8StdString:effective_handler_app_path]];
        if( !handler_app_url ) {
            NSBeep();
            return;
        }
    }

    if( _host->IsNativeFS() ) {
        NSMutableArray *const arr = [NSMutableArray arrayWithCapacity:_filepaths.size()];
        for( const std::string &path : _filepaths )
            if( NSString *const s = [NSString stringWithUTF8String:path.c_str()] )
                [arr addObject:[[NSURL alloc] initFileURLWithPath:s]];

        if( handler_app_url ) {
            // In case we managed to get an app url - use it and open all items at once
            [[NSWorkspace sharedWorkspace] openURLs:arr
                               withApplicationAtURL:handler_app_url
                                      configuration:[NSWorkspaceOpenConfiguration configuration]
                                  completionHandler:^(NSRunningApplication *_app, NSError *) {
                                    if( !_app )
                                        NSBeep();
                                  }];
        }
        else {
            // Otherwise, as a fallback, open items one by one with default app - leave it to the system
            for( NSURL *const url in arr ) {
                if( ![[NSWorkspace sharedWorkspace] openURL:url] )
                    NSBeep();
            }
        }
        return;
    }

    dispatch_to_default([filepaths = std::vector<std::string>{_filepaths.begin(), _filepaths.end()},
                         _panel,
                         _host,
                         handler_app_url,
                         this] mutable {
        auto activity_ticket = [_panel registerExtActivity];
        NSMutableArray *const arr = [NSMutableArray arrayWithCapacity:filepaths.size()];

        // Remove any directories and any items that failed to stat from the list of files to be opened.
        uint64_t total_size = 0;
        std::erase_if(filepaths, [&](const std::string &_path) {
            if( _host->IsDirectory(_path, vfs::Flags::None) )
                return true;
            const std::expected<VFSStat, Error> st = _host->Stat(_path, vfs::Flags::None);
            if( !st )
                return true;
            total_size += st->size;
            return false;
        });

        if( total_size > m_VFSThresholdForImplicitOpening ) {
            const bool allow = AskUserForPermissionToOpenLargeVFSFiles(total_size, _panel);
            if( !allow ) {
                return;
            }
        }

        for( auto &i : filepaths ) {
            if( auto tmp_path = CopyFileToTempStorage(i, *_host, m_TemporaryFileStorage) ) {
                RegisterRemoteFileUploading(i, _host, *tmp_path, _panel);
                if( NSString *const s = [NSString stringWithUTF8StdString:*tmp_path] )
                    [arr addObject:[[NSURL alloc] initFileURLWithPath:s]];
            }
        }

        if( arr.count == 0 ) {
            return;
        }

        if( handler_app_url ) {
            // In case we managed to get an app url - use it and open all items at once
            [[NSWorkspace sharedWorkspace] openURLs:arr
                               withApplicationAtURL:handler_app_url
                                      configuration:[NSWorkspaceOpenConfiguration configuration]
                                  completionHandler:^(NSRunningApplication *_app, NSError *) {
                                    if( !_app )
                                        NSBeep();
                                  }];
        }
        else {
            // Otherwise, as a fallback, open items one by one with default app - leave it to the system
            for( NSURL *const url in arr ) {
                if( ![[NSWorkspace sharedWorkspace] openURL:url] )
                    NSBeep();
            }
        }
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

            if( _host->IsDirectory(_filepath, vfs::Flags::None) ) {
                NSBeep();
                return;
            }

            const std::expected<VFSStat, Error> st = _host->Stat(_filepath, vfs::Flags::None);
            if( !st ) {
                NSBeep();
                return;
            }

            if( st->size > m_VFSThresholdForImplicitOpening ) {
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

std::string FileOpener::DeduceDefaultAppBundleForOpeningFiles(std::span<std::string> _filepaths, VFSHostPtr _host) const
{
    // TODO: this approach is ludicrously inefficient for large number of files...
    // It does much more than necessary.
    std::vector<core::LauchServicesHandlers> per_item_handlers;
    per_item_handlers.reserve(_filepaths.size());
    for( const std::string &path : _filepaths )
        per_item_handlers.emplace_back(path, *_host, m_UTIDB);

    const core::LauchServicesHandlers items_handlers{per_item_handlers};

    if( items_handlers.DefaultHandlerPath().empty() ) {
        // give up - there's no common default handler, the content is heterogeneous
        // maybe it's a bit better to "cluster" the files by their default handlers, but that's rather complex.
        return {};
    }

    try {
        const core::LaunchServiceHandler handler{items_handlers.DefaultHandlerPath()};
        return handler.Path();
    } catch( ... ) {
        return {};
    }
}

bool FileOpener::AskUserForPermissionToOpenLargeVFSFile(std::string_view _file_at_path,
                                                        uint64_t _size,
                                                        PanelController *_panel)
{
    dispatch_assert_background_queue();
    const std::string_view filename_sv = utility::PathManip::Filename(_file_at_path);
    NSString *const filename = [NSString stringWithUTF8StdStringView:filename_sv];

    NSByteCountFormatter *const size_fmt = [[NSByteCountFormatter alloc] init];
    size_fmt.formattingContext = NSFormattingContextMiddleOfSentence;
    size_fmt.countStyle = NSByteCountFormatterCountStyleFile;
    size_fmt.includesUnit = true;
    size_fmt.includesCount = true;
    size_fmt.includesActualByteCount = false;
    size_fmt.adaptive = true;
    size_fmt.zeroPadsFractionDigits = false;
    NSString *const size_str = [size_fmt stringFromByteCount:_size];
    NSString *const message_str = [NSString
        localizedStringWithFormat:NSLocalizedString(@"“%@” is %@ in size.\nAre you sure you want to open it?", ""),
                                  filename,
                                  size_str];
    NSString *const inform_str =
        NSLocalizedString(@"Nimble Commander will create a copy in a temporary location before it can be opened.", "");
    return AskUserForPermissionToOpen(message_str, inform_str, _panel);
}

bool FileOpener::AskUserForPermissionToOpenLargeVFSFiles(uint64_t _size, PanelController *_panel)
{
    dispatch_assert_background_queue();
    NSByteCountFormatter *const size_fmt = [[NSByteCountFormatter alloc] init];
    size_fmt.formattingContext = NSFormattingContextMiddleOfSentence;
    size_fmt.countStyle = NSByteCountFormatterCountStyleFile;
    size_fmt.includesUnit = true;
    size_fmt.includesCount = true;
    size_fmt.includesActualByteCount = false;
    size_fmt.adaptive = true;
    size_fmt.zeroPadsFractionDigits = false;
    NSString *const size_str = [size_fmt stringFromByteCount:_size];
    NSString *const message_str = [NSString
        localizedStringWithFormat:NSLocalizedString(
                                      @"The selected items are %@ in size.\nAre you sure you want to open them?", ""),
                                  size_str];
    NSString *const inform_str =
        NSLocalizedString(@"Nimble Commander will copy them to a temporary location before they can be opened.", "");
    return AskUserForPermissionToOpen(message_str, inform_str, _panel);
}

bool FileOpener::AskUserForPermissionToOpen(NSString *_message_str, NSString *_informative_str, PanelController *_panel)
{
    dispatch_assert_background_queue();
    std::atomic<std::optional<bool>> allow;
    dispatch_async(dispatch_get_main_queue(), [&allow, _message_str, _informative_str, _panel] {
        dispatch_assert_main_queue();
        Alert *const alert = [[Alert alloc] init];
        alert.messageText = _message_str;
        alert.informativeText = _informative_str;
        [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
        [alert.buttons objectAtIndex:0].keyEquivalent = @"\r";
        [alert.buttons objectAtIndex:0].toolTip = NSLocalizedString(@"⏎", "");
        [alert.buttons objectAtIndex:1].keyEquivalent = @"\e";
        [alert.buttons objectAtIndex:1].toolTip = NSLocalizedString(@"␛", "");
        [alert beginSheetModalForWindow:_panel.window
                      completionHandler:[&allow](NSModalResponse result) {
                          allow.store(result == NSAlertFirstButtonReturn);
                          allow.notify_one();
                      }];
    });
    allow.wait(std::nullopt);
    return allow.load().value();
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

static bool DisableSystemCaches()
{
    // TODO: make depencies on Config explicit
    return GlobalConfig().GetBool(g_ConfigDisableSystemCaches);
}

ops::CopyingOptions MakeDefaultFileCopyOptions()
{
    ops::CopyingOptions options;
    options.docopy = true;
    options.verification = DefaultChecksumVerificationSetting();
    options.disable_system_caches = DisableSystemCaches();

    return options;
}

ops::CopyingOptions MakeDefaultFileMoveOptions()
{
    ops::CopyingOptions options;
    options.docopy = false;
    options.verification = DefaultChecksumVerificationSetting();
    options.disable_system_caches = DisableSystemCaches();

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
