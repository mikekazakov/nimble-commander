//
//  SharingService.m
//  Files
//
//  Created by Michael G. Kazakov on 04.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <vector>
#import <string>
#import <sys/types.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <dirent.h>
#import "SharingService.h"
#import "TemporaryNativeFileStorage.h"
#import "Common.h"

static const uint64_t g_MaxFileSizeForVFSShare = 64*1024*1024; // 64mb
static atomic<int> g_IsCurrentlySharing(0);

@implementation SharingService
{
    bool                        m_DidShared;
    vector<string>    m_TmpFilepaths;
}

- (id) init
{
    self = [super init];
    if(self) {
        m_DidShared = false;
    }
    return self;
}

- (void)dealloc
{
    if(!m_DidShared && !m_TmpFilepaths.empty())
    {
        // we have some temp file copied from VFS which was not shared by user (didn't choose any sharing)
        // it's better to remove them now, to reduce hard drive wasting
        dispatch_apply(m_TmpFilepaths.size(), dispatch_get_global_queue(0, 0), ^(size_t n){
            unlink(m_TmpFilepaths[n].c_str());
        });
    }
}

+ (uint64_t) MaximumFileSizeForVFSShare
{
    return g_MaxFileSizeForVFSShare;
}

+ (bool) IsCurrentlySharing
{
    return g_IsCurrentlySharing > 0;
}

- (void) ShowItems:(chained_strings)_entries
             InDir:(string)_dir
             InVFS:(shared_ptr<VFSHost>)_host
    RelativeToRect:(NSRect)_rect
            OfView:(NSView*)_view
     PreferredEdge:(NSRectEdge)_preferredEdge
{
    ++g_IsCurrentlySharing;
    if(_host->IsNativeFS())
    {
        NSMutableArray *items = [NSMutableArray new];
        for(auto &i:_entries)
        {
            string path = _dir + i.c_str();
            NSString *s = [NSString stringWithUTF8String:path.c_str()];
            if(s)
            {
                NSURL *url = [[NSURL alloc] initFileURLWithPath:s];
                if(url)
                    [items addObject:url];
            }
        }
        
        if([items count] > 0)
        {
            NSSharingServicePicker *sharingServicePicker = [[NSSharingServicePicker alloc] initWithItems:items];
            [sharingServicePicker showRelativeToRect:_rect
                                              ofView:_view
                                       preferredEdge:_preferredEdge];
        }
        --g_IsCurrentlySharing;
    }
    else
    { // need to move selected entires to native fs now, so going async here
        __block auto entries(move(_entries));
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            for(auto &i:entries)
            {
                string path = _dir + i.c_str();
                struct stat st;
                if(_host->IsDirectory(path.c_str(), 0, 0)) continue; // will skip any directories here
                if(_host->Stat(path.c_str(), st, 0, 0) < 0) continue;
                if(st.st_size > g_MaxFileSizeForVFSShare) continue;
                
                char native_path[MAXPATHLEN];
                if(TemporaryNativeFileStorage::Instance().CopySingleFile(path.c_str(), _host, native_path))
                    m_TmpFilepaths.push_back(native_path);
            }
            
            if(!m_TmpFilepaths.empty())
            {
                NSMutableArray *items = [NSMutableArray new];
                for(const auto &i: m_TmpFilepaths)
                    if(NSString *s = [NSString stringWithUTF8String:i.c_str()])
                        if(NSURL *url = [[NSURL alloc] initFileURLWithPath:s])
                            [items addObject:url];
                
                if([items count] > 0)
                    dispatch_to_main_queue( ^{
                        NSSharingServicePicker *sharingServicePicker = [[NSSharingServicePicker alloc] initWithItems:items];
                        sharingServicePicker.delegate = self;
                        [sharingServicePicker showRelativeToRect:_rect
                                                          ofView:_view
                                                   preferredEdge:_preferredEdge];
                    });
            }
            --g_IsCurrentlySharing;
        });
    }
}

- (void)sharingServicePicker:(NSSharingServicePicker *)sharingServicePicker didChooseSharingService:(NSSharingService *)service
{
    if(service != nil)
        m_DidShared = true;
}

@end
