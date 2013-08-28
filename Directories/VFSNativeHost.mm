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
    static VFSNativeHost *host;
    dispatch_once(&once, ^{
        host = std::make_shared<VFSNativeHost>().get();
    });
    return host->SharedPtr();
}
