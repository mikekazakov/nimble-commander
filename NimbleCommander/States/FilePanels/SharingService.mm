// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/types.h>
#include <sys/stat.h>
#include "SharingService.h"
#include <NimbleCommander/Core/TemporaryNativeFileStorage.h>
#include <Habanero/dispatch_cpp.h>

static const uint64_t g_MaxFileSizeForVFSShare = 64*1024*1024; // 64mb
static std::atomic<int> g_IsCurrentlySharing(0);

@implementation SharingService
{
    bool                   m_DidShare;
    std::vector<std::string>    m_TmpFilepaths;
}

- (id) init
{
    self = [super init];
    if(self) {
        m_DidShare = false;
    }
    return self;
}

- (void)dealloc
{
    if(!m_DidShare && !m_TmpFilepaths.empty())
    {
        // we have some temp file copied from VFS which was not shared by user (didn't choose any sharing)
        // it's better to remove them now, to reduce hard drive wasting
        dispatch_apply(m_TmpFilepaths.size(), dispatch_get_global_queue(0, 0), ^(size_t n){
            unlink(m_TmpFilepaths[n].c_str());
        });
    }
}

+ (bool) SharingEnabledForItem:(const VFSListingItem&)_item
{
    if( !_item )
        return false;
    
    if(_item.IsDotDot())
        return false;
    
    if(_item.Host()->IsNativeFS())
        return true;
    
    if(_item.IsDir() == false &&
       _item.Size() < g_MaxFileSizeForVFSShare)
        return true;
    
    return false;
}

+ (bool) IsCurrentlySharing
{
    return g_IsCurrentlySharing > 0;
}

- (void) ShowItems:(const std::vector<std::string>&)_entries
             InDir:(std::string)_dir
             InVFS:(std::shared_ptr<VFSHost>)_host
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
            std::string path = _dir + i;
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
        dispatch_to_default([=]{
            for(auto &i:_entries)
            {
                std::string path = _dir + i;
                VFSStat st;
                if(_host->IsDirectory(path.c_str(), 0, 0)) continue; // will skip any directories here
                if(_host->Stat(path.c_str(), st, 0, 0) < 0) continue;
                if(st.size > g_MaxFileSizeForVFSShare) continue;
                
                if( auto native_path = TemporaryNativeFileStorage::Instance().CopySingleFile(path, *_host) )
                    m_TmpFilepaths.push_back(*native_path);
            }
            
            if(!m_TmpFilepaths.empty())
            {
                NSMutableArray *items = [NSMutableArray new];
                for(const auto &i: m_TmpFilepaths)
                    if(NSString *s = [NSString stringWithUTF8String:i.c_str()])
                        if(NSURL *url = [[NSURL alloc] initFileURLWithPath:s])
                            [items addObject:url];
                
                if([items count] > 0)
                    dispatch_to_main_queue( [=]{
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
        m_DidShare = true;
}

@end
