//
//  PanelAux.mm
//  Files
//
//  Created by Michael G. Kazakov on 18.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include "Operations/Copy/FileCopyOperation.h"
#include "Operations/OperationsController.h"
#include "vfs/vfs_native.h"
#include "TemporaryNativeFileStorage.h"
#include "TemporaryNativeFileChangesSentinel.h"
#include "ExtensionLowercaseComparison.h"
#include "Config.h"
#include "PanelController.h"
#include "MainWindowController.h"
#include "PanelAux.h"

static const auto g_ConfigExecutableExtensionsWhitelist = "filePanel.general.executableExtensionsWhitelist";
static const uint64_t g_MaxFileSizeForVFSOpen = 64*1024*1024; // 64mb

static void RegisterRemoteFileUploading(const string& _original_path,
                                        const VFSHostPtr& _original_vfs,
                                        const string &_native_path,
                                        PanelController *_origin )
{
    if( _original_vfs->IsNativeFS() )
       return; // no reason to watch files from native fs
       
    if( !_original_vfs->IsWriteable() )
        return; // no reason to watch file we can't upload then
    
    __weak MainWindowController* origin_window = _origin.mainWindowController;
    VFSHostWeakPtr weak_host(_original_vfs);
    
    TemporaryNativeFileChangesSentinel::Instance().WatchFile(_native_path, [=]{
        if( MainWindowController* window = origin_window )
            if( auto vfs = weak_host.lock() ) {
                vector<VFSListingItem> items;
                int ret = VFSNativeHost::SharedHost()->FetchFlexibleListingItems(path(_native_path).parent_path().native(),
                                                                                 vector<string>(1, path(_native_path).filename().native()),
                                                                                 0,
                                                                                 items,
                                                                                 nullptr);
                if( ret == 0 ) {
                    FileCopyOperationOptions opts;
                    opts.force_overwrite = true;
                    auto operation = [[FileCopyOperation alloc] initWithItems:items
                                                              destinationPath:_original_path
                                                              destinationHost:vfs
                                                                      options:opts];
                    
                    [window.OperationsController AddOperation:operation];
                }
                
            }
    });
}

void PanelVFSFileWorkspaceOpener::Open(string _filename,
                                       shared_ptr<VFSHost> _host,
                                       PanelController *_panel
                                       )
{
    Open(_filename, _host, "", _panel);
}

void PanelVFSFileWorkspaceOpener::Open(string _filename,
                                       shared_ptr<VFSHost> _host,
                                       string _with_app_path,
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
        if(_host->IsDirectory(_filename.c_str(), 0, 0))
            return;
        
        VFSStat st;
        if(_host->Stat(_filename.c_str(), st, 0, 0) < 0)
            return;
        
        if(st.size > g_MaxFileSizeForVFSOpen)
            return;
        
        string tmp_path;
        
        if(!TemporaryNativeFileStorage::Instance().CopySingleFile(_filename, _host, tmp_path))
            return;
  
        RegisterRemoteFileUploading( _filename, _host, tmp_path, _panel );
        
        NSString *fn = [NSString stringWithUTF8StdString:tmp_path];
        dispatch_to_main_queue([=]{
            
            if(!_with_app_path.empty())
            {
                if (![[NSWorkspace sharedWorkspace] openFile:fn
                                             withApplication:[NSString stringWithUTF8String:_with_app_path.c_str()]])
                    NSBeep();
            }
            else
            {
                if (![[NSWorkspace sharedWorkspace] openFile:fn])
                    NSBeep();
            }
        });
    });
}

// TODO: write version with FlexListingItem as an input - it would be much simplier
void PanelVFSFileWorkspaceOpener::Open(vector<string> _filenames,
                                       shared_ptr<VFSHost> _host,
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
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
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
            
            string tmp;
            if(!TemporaryNativeFileStorage::Instance().CopySingleFile(i, _host, tmp))
                continue;
            
            RegisterRemoteFileUploading( i, _host, tmp, _panel );
            
            if(NSString *s = [NSString stringWithUTF8StdString:tmp])
                [arr addObject: [[NSURL alloc] initFileURLWithPath:s] ];
        }

        if(![NSWorkspace.sharedWorkspace openURLs:arr
                          withAppBundleIdentifier:_with_app_bundle
                                          options:0
                   additionalEventParamDescriptor:nil
                                launchIdentifiers:nil])
            NSBeep();
    });
}

bool panel::IsEligbleToTryToExecuteInConsole(const VFSListingItem& _item)
{
    static const vector<string> extensions = []{
        vector<string> v;
        if( auto exts_string = GlobalConfig().GetString(g_ConfigExecutableExtensionsWhitelist) ) {
            // load from config
            if( auto extensions_array = [[NSString stringWithUTF8StdString:*exts_string] componentsSeparatedByString:@","] )
                for( NSString *s: extensions_array )
                    if( s != nil && s.length > 0 )
                        if( auto trimmed = [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] )
                            if( auto utf8 = trimmed.UTF8String )
                                v.emplace_back( ExtensionLowercaseComparison::Instance().ExtensionToLowercase(utf8) );
        }
        else // hardcoded fallback case if something went wrong
            v = {"sh", "pl", "rb", "py"};
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
