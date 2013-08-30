//
//  VFSNativeHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFSNativeHost.h"
#import "VFSNativeListing.h"
#import "VFSNativeFile.h"

VFSNativeHost::VFSNativeHost():
    VFSHost("", 0)
{
}

int VFSNativeHost::FetchDirectoryListing(const char *_path,
                                  std::shared_ptr<VFSListing> *_target,
                                  bool (^_cancel_checker)())
{
    auto listing = std::make_shared<VFSNativeListing>(_path, SharedPtr());
    
    int result = listing->LoadListingData(_cancel_checker);
    if(result != VFSError::Ok)
        return result;
    
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    
    *_target = listing;
    
    return VFSError::Ok;
}

int VFSNativeHost::CreateFile(const char* _path,
                       std::shared_ptr<VFSFile> *_target,
                       bool (^_cancel_checker)())
{
    auto file = std::make_shared<VFSNativeFile>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    *_target = file;
    return VFSError::Ok;
}

std::shared_ptr<VFSNativeHost> VFSNativeHost::SharedHost()
{
    static dispatch_once_t once;
//    static VFSNativeHost *host;
    static std::shared_ptr<VFSNativeHost> host;
    dispatch_once(&once, ^{
//        host = std::make_shared<VFSNativeHost>().get();
        host = std::make_shared<VFSNativeHost>();
    });
    return host;
}

bool VFSNativeHost::IsDirectory(const char *_path, int _flags, bool (^_cancel_checker)())
{
    assert(_path[0] == '/'); // here in VFS we work only with absolute paths
    struct stat st;
    int ret = (_flags & F_NoFollow) == 0 ? stat(_path, &st) : lstat(_path, &st);

    if(ret < 0)
        return false;

    return (st.st_mode & S_IFMT) == S_IFDIR;
}

