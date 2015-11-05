//
//  PanelAux.mm
//  Files
//
//  Created by Michael G. Kazakov on 18.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/types.h>
#import <sys/stat.h>
#import <dirent.h>
#import "PanelAux.h"
#import "Common.h"
#import "TemporaryNativeFileStorage.h"

static const uint64_t g_MaxFileSizeForVFSOpen = 64*1024*1024; // 64mb

void PanelVFSFileWorkspaceOpener::Open(string _filename,
                                       shared_ptr<VFSHost> _host
                                       )
{
    Open(_filename, _host, "");
}

void PanelVFSFileWorkspaceOpener::Open(string _filename,
                 shared_ptr<VFSHost> _host,
                 string _with_app_path
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
        
        string tmp;
        
        if(!TemporaryNativeFileStorage::Instance().CopySingleFile(_filename, _host, tmp))
            return;
        
        NSString *fn = [NSString stringWithUTF8StdString:tmp];
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
                                       NSString *_with_app_bundle // can be nil, use default app in such case
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

bool panel::IsEligbleToTryToExecuteInConsole(const VFSFListingItem& _item)
{
    static vector<string> extensions;
    static once_flag once;
    call_once(once, []{
        bool any = false;
        
        // load from defaults
        if(NSString *exts_string = [NSUserDefaults.standardUserDefaults stringForKey:@"FilePanelsGeneralExecutableExtensionsList"])
            if(NSArray *extensions_array = [exts_string componentsSeparatedByString:@","])
                for(NSString *s: extensions_array)
                    if(s != nil && s.length > 0)
                        if(const char *utf8 = s.UTF8String) {
                            extensions.emplace_back(utf8);
                            any = true;
                        }
        
        // hardcoded fallback case if something went wrong
        if(!any)
            extensions = vector<string>{"sh", "pl", "rb", "py"};
    });
    
    if(_item.IsDir())
        return false;
    
    // TODO: need more sophisticated executable handling here
    // THIS IS WRONG!
    bool uexec = (_item.UnixMode() & S_IXUSR) ||
    (_item.UnixMode() & S_IXGRP) ||
    (_item.UnixMode() & S_IXOTH) ;
    
    if(!uexec) return false;
    
    if(!_item.HasExtension())
        return true; // if file has no extension and had execute rights - let's try it
    
    const char *ext = _item.Extension();
    
    for(auto &s: extensions)
        if(s == ext)
            return true;
    
    return false;
}
