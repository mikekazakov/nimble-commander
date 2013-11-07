//
//  PanelAux.mm
//  Files
//
//  Created by Michael G. Kazakov on 18.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/types.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <dirent.h>
#import "PanelAux.h"
#import "Common.h"
#import "TemporaryNativeFileStorage.h"

static const uint64_t g_MaxFileSizeForVFSOpen = 64*1024*1024; // 64mb

void PanelVFSFileWorkspaceOpener::Open(const char* _filename,
                                       std::shared_ptr<VFSHost> _host
                                       )
{
    Open(_filename, _host, 0);
}

void PanelVFSFileWorkspaceOpener::Open(const char* _filename,
                 std::shared_ptr<VFSHost> _host,
                 const char* _with_app_path
                 )
{
    if(_host->IsNativeFS())
    {
        NSString *filename = [NSString stringWithUTF8String:_filename];
        
        if(_with_app_path != 0)
        {
            if (![[NSWorkspace sharedWorkspace] openFile:filename withApplication:[NSString stringWithUTF8String:_with_app_path]])
                NSBeep();
        }
        else
        {
            if (![[NSWorkspace sharedWorkspace] openFile:filename])
                NSBeep();
        }
        
        return;
    }
    
    std::string path = _filename;
    std::string app_path = _with_app_path != 0 ? _with_app_path : "";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if(_host->IsDirectory(path.c_str(), 0, 0))
            return;
        
        struct stat st;
        if(_host->Stat(path.c_str(), st, 0, 0) < 0)
            return;
        
        if(st.st_size > g_MaxFileSizeForVFSOpen)
            return;
        
        char tmp[MAXPATHLEN];
        
        if(!TemporaryNativeFileStorage::Instance().CopySingleFile(path.c_str(), _host, tmp))
            return;
        
        NSString *fn = [NSString stringWithUTF8String:tmp];
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if(!app_path.empty())
            {
                if (![[NSWorkspace sharedWorkspace] openFile:fn withApplication:[NSString stringWithUTF8String:app_path.c_str()]])
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
