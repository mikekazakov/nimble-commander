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
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if(_host->IsDirectory(_filename.c_str(), 0, 0))
            return;
        
        struct stat st;
        if(_host->Stat(_filename.c_str(), st, 0, 0) < 0)
            return;
        
        if(st.st_size > g_MaxFileSizeForVFSOpen)
            return;
        
        char tmp[MAXPATHLEN];
        
        if(!TemporaryNativeFileStorage::Instance().CopySingleFile(_filename.c_str(), _host, tmp))
            return;
        
        NSString *fn = [NSString stringWithUTF8String:tmp];
        dispatch_to_main_queue( ^{
            
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
            
            struct stat st;
            if(_host->Stat(i.c_str(), st, 0, 0) < 0)
                continue;
            
            if(st.st_size > g_MaxFileSizeForVFSOpen)
                continue;
            
            char tmp[MAXPATHLEN];
            
            if(!TemporaryNativeFileStorage::Instance().CopySingleFile(i.c_str(), _host, tmp))
                continue;
            
            if(NSString *s = [NSString stringWithUTF8String:tmp])
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
