// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <VFS/Native.h>
#include <Utility/ExtensionLowercaseComparison.h>
#include <Utility/TemporaryFileStorage.h>
#include <NimbleCommander/Core/TemporaryNativeFileChangesSentinel.h>
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/States/FilePanels/PanelController.h>
#include <NimbleCommander/States/MainWindowController.h>
#include "PanelAux.h"
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include "ExternalEditorInfo.h"
#include <Operations/Copying.h>
#include <Habanero/dispatch_cpp.h>
#include <Utility/StringExtras.h>

using nc::vfs::easy::CopyFileToTempStorage;

namespace nc::panel {

static const auto g_ConfigArchivesExtensionsWhieList    = "filePanel.general.archivesExtensionsWhitelist";
static const auto g_ConfigExecutableExtensionsWhitelist = "filePanel.general.executableExtensionsWhitelist";
static const auto g_ConfigDefaultVerificationSetting = "filePanel.operations.defaultChecksumVerification";
static const auto g_CheckDelay = "filePanel.operations.vfsShadowUploadChangesCheckDelay";
static const auto g_DropDelay = "filePanel.operations.vfsShadowUploadObservationDropDelay";
static const auto g_QLPanel = "filePanel.presentation.showQuickLookAsFloatingPanel";
static const uint64_t g_MaxFileSizeForVFSOpen = 64*1024*1024; // 64mb

static std::chrono::milliseconds UploadingCheckDelay()
{
    static const auto fetch = []{
        const auto value = GlobalConfig().Has(g_CheckDelay) ?
            GlobalConfig().GetInt(g_CheckDelay) : 5000;
        return std::chrono::milliseconds(value);
    };
    static std::chrono::milliseconds delay = []{
        static auto ticket = GlobalConfig().Observe(g_CheckDelay, []{
            delay = fetch();
        });
        return fetch();
    }();
    return delay;
}

static std::chrono::milliseconds UploadingDropDelay()
{
    static const auto fetch = []{
        const auto value = GlobalConfig().Has(g_DropDelay) ?
            GlobalConfig().GetInt(g_DropDelay) : 3600000;         
        return std::chrono::milliseconds(value);
    };
    static std::chrono::milliseconds delay = []{
        static auto ticket = GlobalConfig().Observe(g_DropDelay, []{
            delay = fetch();
        });
        return fetch();
    }();
    return delay;
}

static void RegisterRemoteFileUploading(const std::string& _original_path,
                                        const VFSHostPtr& _original_vfs,
                                        const std::string &_native_path,
                                        PanelController *_origin )
{
    if( _original_vfs->IsNativeFS() )
       return; // no reason to watch files from native fs
       
    if( !_original_vfs->IsWritable() )
        return; // no reason to watch file we can't upload then

    __weak NCMainWindowController* origin_window = _origin.mainWindowController;
    __weak PanelController* origin_controller = _origin;
    VFSHostWeakPtr weak_host(_original_vfs);

    auto on_file_change = [=]{
        NCMainWindowController* window = origin_window;
        if( !window )
            return;
        
        auto vfs = weak_host.lock();
        if( !vfs )
            return;
        
        std::vector<VFSListingItem> listing_items;
        auto &storage_host = *VFSNativeHost::SharedHost();
        const auto changed_item_directory = boost::filesystem::path(_native_path).parent_path().native();
        const auto changed_item_filename = boost::filesystem::path(_native_path).filename().native();
        const auto ret = storage_host.FetchFlexibleListingItems(changed_item_directory,
                                                                {1, changed_item_filename},
                                                                0,
                                                                listing_items,
                                                                nullptr);
        if( ret == 0 ) {
            auto opts = panel::MakeDefaultFileCopyOptions();
            opts.exist_behavior = nc::ops::CopyingOptions::ExistBehavior::OverwriteAll;
            const auto op = std::make_shared<nc::ops::Copying>(listing_items,
                                                               _original_path,
                                                               vfs,
                                                               opts);
            if( auto pc = (PanelController*)origin_controller )
                if( !pc.receivesUpdateNotifications )
                    op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=]{
                        dispatch_to_main_queue( [=]{
                            // TODO: perhaps need to check that path didn't changed
                            [(PanelController*)origin_controller refreshPanel];
                        });
                    });
            [window enqueueOperation:op];
        }
    };
    
    auto &sentinel = TemporaryNativeFileChangesSentinel::Instance();
    sentinel.WatchFile(_native_path,
                       on_file_change,
                       UploadingCheckDelay(),
                       UploadingDropDelay());
}

FileOpener::FileOpener(nc::utility::TemporaryFileStorage &_temp_storage):
    m_TemporaryFileStorage{_temp_storage}
{
}

void FileOpener::Open(std::string _filename,
                                       std::shared_ptr<VFSHost> _host,
                                       PanelController *_panel
                                       )
{
    Open(_filename, _host, "", _panel);
}

void FileOpener::Open(std::string _filename,
                                       std::shared_ptr<VFSHost> _host,
                                       std::string _with_app_path,
                                       PanelController *_panel
                                       )
{
    if(_host->IsNativeFS())
    {
        NSString *filename = [NSString stringWithUTF8String:_filename.c_str()];
        
        if(!_with_app_path.empty())
        {
            if (![[NSWorkspace sharedWorkspace] openFile:filename
                                         withApplication:[NSString stringWithUTF8String:_with_app_path.c_str()]])
                NSBeep();
        }
        else
        {
            if (![[NSWorkspace sharedWorkspace] openFile:filename])
                NSBeep();
        }
        
        return;
    }
    
    dispatch_to_default([=]{
        auto activity_ticket = [_panel registerExtActivity];        
        if( _host->IsDirectory(_filename.c_str(), 0, 0) ) {
            NSBeep();
            return;
        }
        
        VFSStat st;
        if( _host->Stat(_filename.c_str(), st, 0, 0) < 0 ) {
            NSBeep();
            return;
        }
        
        if( st.size > g_MaxFileSizeForVFSOpen ) {
            NSBeep();
            return;
        }
        
        if( auto tmp_path = CopyFileToTempStorage(_filename, *_host, m_TemporaryFileStorage) ) {
            RegisterRemoteFileUploading( _filename, _host, *tmp_path, _panel );
            
            NSString *fn = [NSString stringWithUTF8StdString:*tmp_path];
            dispatch_to_main_queue([=]{
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
void FileOpener::Open(std::vector<std::string> _filenames,
                                       std::shared_ptr<VFSHost> _host,
                                       NSString *_with_app_bundle, // can be nil, use default app in such case
                                       PanelController *_panel
                                       )
{
    if(_host->IsNativeFS())
    {
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:_filenames.size()];
        for(auto &i: _filenames)
            if(NSString *s = [NSString stringWithUTF8String:i.c_str()])
                [arr addObject: [[NSURL alloc] initFileURLWithPath:s] ];
        
        if(![NSWorkspace.sharedWorkspace openURLs:arr
                          withAppBundleIdentifier:_with_app_bundle
                                          options:0
                   additionalEventParamDescriptor:nil
                                launchIdentifiers:nil])
            NSBeep();

        return;
    }
    
    dispatch_to_default([=]{
        auto activity_ticket = [_panel registerExtActivity];
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:_filenames.size()];
        for(auto &i: _filenames)
        {
            if(_host->IsDirectory(i.c_str(), 0, 0))
                continue;
            
            VFSStat st;
            if(_host->Stat(i.c_str(), st, 0, 0) < 0)
                continue;
            
            if(st.size > g_MaxFileSizeForVFSOpen)
                continue;
            
            if( auto tmp_path = CopyFileToTempStorage(i, *_host, m_TemporaryFileStorage) ) {
                RegisterRemoteFileUploading( i, _host, *tmp_path, _panel );
                if( NSString *s = [NSString stringWithUTF8StdString:*tmp_path] )
                    [arr addObject: [[NSURL alloc] initFileURLWithPath:s] ];
            }
        }

        if(![NSWorkspace.sharedWorkspace openURLs:arr
                          withAppBundleIdentifier:_with_app_bundle
                                          options:0
                   additionalEventParamDescriptor:nil
                                launchIdentifiers:nil])
            NSBeep();
    });
}

void FileOpener::OpenInExternalEditorTerminal(std::string _filepath,
                                                               VFSHostPtr _host,
                                                               std::shared_ptr<ExternalEditorStartupInfo> _ext_ed,
                                                               std::string _file_title,
                                                               PanelController *_panel)
{
    assert( !_filepath.empty() && _host && _ext_ed && _panel );
    
    if( _host->IsNativeFS() ) {
        if( NCMainWindowController* wnd = (NCMainWindowController*)_panel.window.delegate )
            [wnd RequestExternalEditorTerminalExecution:_ext_ed->Path()
                                                 params:_ext_ed->SubstituteFileName(_filepath)
                                              fileTitle:_file_title];
    }
    else
        dispatch_to_default([=]{ // do downloading down in a background thread
            auto activity_ticket = [_panel registerExtActivity];
            
            if( _host->IsDirectory(_filepath.c_str(), 0, 0) ) {
                NSBeep();
                return;
            }
            
            VFSStat st;
            if( _host->Stat(_filepath.c_str(), st, 0, 0) < 0 ) {
                NSBeep();
                return;
            }
            
            if( st.size > g_MaxFileSizeForVFSOpen ) {
                NSBeep();
                return;
            }
            
            if( auto tmp_path = CopyFileToTempStorage(_filepath, *_host, m_TemporaryFileStorage) ) {
                RegisterRemoteFileUploading( _filepath, _host, *tmp_path, _panel );
                dispatch_to_main_queue([=]{ // when we sucessfuly download a file - request terminal execution in main thread
                    if( NCMainWindowController* wnd = (NCMainWindowController*)_panel.window.delegate )
                        [wnd RequestExternalEditorTerminalExecution:_ext_ed->Path()
                                                             params:_ext_ed->SubstituteFileName(*tmp_path)
                                                          fileTitle:_file_title];
                });
            }
        });
}

bool IsEligbleToTryToExecuteInConsole(const VFSListingItem& _item)
{
    static const std::vector<std::string> extensions = []{
        std::vector<std::string> v;
        auto exts_string = GlobalConfig().GetString(g_ConfigExecutableExtensionsWhitelist);
        if( auto extensions_array = [[NSString stringWithUTF8StdString:exts_string] componentsSeparatedByString:@","] )
            for( NSString *s: extensions_array )
                if( s != nil && s.length > 0 )
                    if( auto trimmed = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] )
                        if( auto utf8 = trimmed.UTF8String )
                            v.emplace_back( ExtensionLowercaseComparison::Instance().ExtensionToLowercase(utf8) );
        return v;
    }();
    
    if( _item.IsDir() )
        return false;
    
    // TODO: need more sophisticated executable handling here
    // THIS IS WRONG!
    bool uexec = (_item.UnixMode() & S_IXUSR) ||
    (_item.UnixMode() & S_IXGRP) ||
    (_item.UnixMode() & S_IXOTH) ;
    
    if(!uexec) return false;
    
    if( !_item.HasExtension() )
        return true; // if file has no extension and had execute rights - let's try it
    
    
    const auto extension = ExtensionLowercaseComparison::Instance().ExtensionToLowercase( _item.Extension() );
    for(auto &s: extensions)
        if( s == extension )
            return true;
    
    return false;
}

static ops::CopyingOptions::ChecksumVerification DefaultChecksumVerificationSetting()
{
    if( !bootstrap::ActivationManager::Instance().HasCopyVerification() )
        return ops::CopyingOptions::ChecksumVerification::Never;
    int v = GlobalConfig().GetInt(g_ConfigDefaultVerificationSetting);
    if( v == (int)ops::CopyingOptions::ChecksumVerification::Always )
       return ops::CopyingOptions::ChecksumVerification::Always;
    else if( v == (int)ops::CopyingOptions::ChecksumVerification::WhenMoves )
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

bool IsExtensionInArchivesWhitelist( const char *_ext ) noexcept
{
    if( !_ext )
        return false;
    static const std::vector<std::string> archive_extensions = []{
        std::vector<std::string> v;
        auto exts_string = GlobalConfig().GetString(g_ConfigArchivesExtensionsWhieList);
        if( auto extensions_array = [[NSString stringWithUTF8StdString:exts_string] componentsSeparatedByString:@","] )
            for( NSString *s: extensions_array )
                if( s != nil && s.length > 0 )
                    if( auto trimmed = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] )
                        if( auto utf8 = trimmed.UTF8String)
                            v.emplace_back( ExtensionLowercaseComparison::Instance().ExtensionToLowercase(utf8) );
        return v;
    }();
    
    const auto extension = ExtensionLowercaseComparison::Instance().ExtensionToLowercase( _ext );
    return any_of(begin(archive_extensions), end(archive_extensions), [&](auto &_) { return extension == _; } );
}

    
bool ShowQuickLookAsFloatingPanel() noexcept
{
    static const auto fetch = []{
        return GlobalConfig().GetBool(g_QLPanel);
    };
    static bool value = []{
        GlobalConfig().ObserveForever(g_QLPanel, []{
            value = fetch();
        });
        return fetch();
    }();
    return value;
}
    
}
