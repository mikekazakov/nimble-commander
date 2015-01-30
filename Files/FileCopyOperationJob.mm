//
//  FileCopyOperationJob.cpp
//  Files
//
//  Created by Michael G. Kazakov on 30/01/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "FileCopyOperationJob.h"
#import "NativeFSManager.h"

bool FileCopyOperationJob::ShouldPreallocateSpace(int64_t _bytes_to_write, int _file_des)
{
    const auto min_prealloc_size = 4096;
    if( _bytes_to_write <= min_prealloc_size )
        return false;
    
    // need to check destination fs and permit preallocation only on certain filesystems
    char path_buf[MAXPATHLEN];
    int ret = fcntl(_file_des, F_GETPATH, path_buf);
    if(ret < 0)
        return false;
    
    auto dst_fs_info = NativeFSManager::Instance().VolumeFromPathFast(path_buf);
    if( !dst_fs_info )
        return false;
    
    return dst_fs_info->fs_type_name == "hfs";
}

void FileCopyOperationJob::PreallocateSpace(int64_t _preallocate_delta, int _file_des)
{
    fstore_t preallocstore = {F_ALLOCATECONTIG, F_PEOFPOSMODE, 0, _preallocate_delta};
    if( fcntl(_file_des, F_PREALLOCATE, &preallocstore) == -1 ) {
        preallocstore.fst_flags = F_ALLOCATEALL;
        fcntl(_file_des, F_PREALLOCATE, &preallocstore);
    }
}