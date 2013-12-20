//
//  VFSNativeHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//


#import <sys/types.h>
#import <sys/dirent.h>
#import <sys/stat.h>
#import <dirent.h>
#import <sys/time.h>
#import <sys/xattr.h>
#import <sys/attr.h>
#import <sys/vnode.h>
#import <sys/param.h>
#import <sys/mount.h>
#import <unistd.h>
#import <stdlib.h>

#import "VFSNativeHost.h"
#import "VFSNativeListing.h"
#import "VFSNativeFile.h"
#import "VFSError.h"
#import "FSEventsDirUpdate.h"
#import "Common.h"

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

VFSNativeHost::VFSNativeHost():
    VFSHost("", 0)
{
}

const char *VFSNativeHost::FSTag() const
{
    return "native";
}

int VFSNativeHost::FetchDirectoryListing(const char *_path,
                                         shared_ptr<VFSListing> *_target,
                                         int _flags,
                                         bool (^_cancel_checker)())
{
    auto listing = make_shared<VFSNativeListing>(_path, SharedPtr());
    
    int result = listing->LoadListingData(_flags, _cancel_checker);
    if(result != VFSError::Ok)
        return result;
    
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    
    *_target = listing;
    
    return VFSError::Ok;
}

int VFSNativeHost::CreateFile(const char* _path,
                       shared_ptr<VFSFile> *_target,
                       bool (^_cancel_checker)())
{
    auto file = make_shared<VFSNativeFile>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    *_target = file;
    return VFSError::Ok;
}

shared_ptr<VFSNativeHost> VFSNativeHost::SharedHost()
{
    static dispatch_once_t once;
    static shared_ptr<VFSNativeHost> host;
    dispatch_once(&once, ^{
        host = make_shared<VFSNativeHost>();
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

bool VFSNativeHost::FindLastValidItem(const char *_orig_path,
                               char *_valid_path,
                               int _flags,
                               bool (^_cancel_checker)())
{
    // TODO: maybe it's better to go left-to-right than right-to-left
    if(_orig_path[0] != '/') return false;
    
    
    char tmp[MAXPATHLEN*8];
    strcpy(tmp, _orig_path);
    if(IsPathWithTrailingSlash(tmp)) tmp[strlen(tmp)-1] = 0; // cut trailing slash if any
    
    while(true)
    {
        if(_cancel_checker && _cancel_checker())
            return false;
        
        struct stat st;
        int ret = (_flags & F_NoFollow) == 0 ? stat(tmp, &st) : lstat(tmp, &st);
        if(ret == 0)
        {
            strcpy(_valid_path, tmp);
            return true;
        }

        char *sl = strrchr(tmp, '/');
        assert(sl != 0);
        if(sl == tmp) return false;
        *sl = 0;
    }
    
    return false;
}

// return false on error or cancellation
static int CalculateDirectoriesSizesHelper(char *_path,
                                      size_t _path_len,
                                      bool *_iscancelling,
                                      bool (^_checker)(),
                                      dispatch_queue_t _stat_queue,
                                      int64_t *_size_stock)
{
    if(_checker && _checker())
    {
        *_iscancelling = true;
        return VFSError::Cancelled;
    }
    
    DIR *dirp = opendir(_path);
    if( dirp == 0 )
        return VFSError::FromErrno(errno);
    
    dirent *entp;
    
    _path[_path_len] = '/';
    _path[_path_len+1] = 0;
    char *var = _path + _path_len + 1;
    
    while((entp = _readdir_unlocked(dirp, 1)) != NULL)
    {
        if(_checker && _checker())
        {
            *_iscancelling = true;
            goto cleanup;
        }
        
        if(entp->d_ino == 0) continue; // apple's documentation suggest to skip such files
        if(entp->d_namlen == 1 && entp->d_name[0] == '.') continue; // do not process self entry
        if(entp->d_namlen == 2 && entp->d_name[0] == '.' && entp->d_name[1] == '.') continue; // do not process parent entry
        
        memcpy(var, entp->d_name, entp->d_namlen+1);
        if(entp->d_type == DT_DIR)
        {
            CalculateDirectoriesSizesHelper(_path,
                                      _path_len + entp->d_namlen + 1,
                                      _iscancelling,
                                      _checker,
                                      _stat_queue,
                                      _size_stock);
            if(*_iscancelling)
                goto cleanup;
        }
        else if(entp->d_type == DT_REG || entp->d_type == DT_LNK)
        {
            char *full_path = (char*) malloc(_path_len + entp->d_namlen + 2);
            memcpy(full_path, _path, _path_len + entp->d_namlen + 2);
            
            dispatch_async(_stat_queue, ^{
                if(*_iscancelling) return;
                
                struct stat st;
                
                if(lstat(full_path, &st) == 0)
                    *_size_stock += st.st_size;
                
                free(full_path);
            });
        }
    }
    
cleanup:
    closedir(dirp);
    _path[_path_len] = 0;
    return VFSError::Ok;
}


int VFSNativeHost::CalculateDirectoriesSizes(
                                      FlexChainedStringsChunk *_dirs, // transfered ownership
                                      const string &_root_path, // relative to current host path
                                      bool (^_cancel_checker)(),
                                      void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size)
                                      )
{
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    
    bool iscancelling = false;
    char path[MAXPATHLEN];
    strcpy(path, _root_path.c_str());
    if(path[_root_path.length()-1] != '/') strcat(path, "/");
    char *var = path + strlen(path);
    
    dispatch_queue_t stat_queue = dispatch_queue_create("info.filesmanager.Files.VFSNativeHost.CalculateDirectoriesSizes", 0);
    
    int error = VFSError::Ok;
    
    for(const auto &i: *_dirs)
    {
        memcpy(var, i.str(), i.len+1);
        
        int64_t total_size = 0;
        
        int result = CalculateDirectoriesSizesHelper(path,
                                                strlen(path),
                                                &iscancelling,
                                                _cancel_checker,
                                                stat_queue,
                                                &total_size);
        dispatch_sync(stat_queue, ^{});
        
        if(iscancelling || (_cancel_checker && _cancel_checker())) // check if we need to quit
            goto cleanup;
        
        if(result >= 0)
            _completion_handler(i.str(), total_size);
        else
            error = result;
    }
    
cleanup:
    dispatch_release(stat_queue);
    FlexChainedStringsChunk::FreeWithDescendants(&_dirs);
    return error;
}

int VFSNativeHost::CalculateDirectoryDotDotSize( // will pass ".." as _dir_sh_name upon completion
                                         const string &_root_path, // relative to current host path
                                         bool (^_cancel)(),
                                         void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size)
                                         )
{
    if(_cancel && _cancel())
        return VFSError::Cancelled;
    
    bool iscancelling = false;
    char path[MAXPATHLEN];
    strcpy(path, _root_path.c_str());
    dispatch_queue_t queue = dispatch_queue_create("info.filesmanager.Files.VFSNativeHost.CalculateDirectoryDotDotSize", 0);
    int64_t size = 0;
    int result = CalculateDirectoriesSizesHelper(path, strlen(path), &iscancelling, _cancel, queue, &size);
    dispatch_sync(queue, ^{});
    if(iscancelling || (_cancel && _cancel())) goto cleanup; // check if we need to quit
    if(result >= 0) _completion_handler("..", size);
cleanup:
    dispatch_release(queue);
    return result;
}

unsigned long VFSNativeHost::DirChangeObserve(const char *_path, void (^_handler)())
{
    return FSEventsDirUpdate::Inst()->AddWatchPath(_path, _handler);
}

void VFSNativeHost::StopDirChangeObserving(unsigned long _ticket)
{
    FSEventsDirUpdate::Inst()->RemoveWatchPathWithTicket(_ticket);
}

int VFSNativeHost::Stat(const char *_path, struct stat &_st, int _flags, bool (^_cancel_checker)())
{
    memset(&_st, 0, sizeof(_st));
    
    int ret = (_flags & F_NoFollow) ? lstat(_path, &_st) : stat(_path, &_st);
    
    if(ret == 0)
        return VFSError::Ok;
    
    return VFSError::FromErrno(errno);
}

int VFSNativeHost::IterateDirectoryListing(const char *_path, bool (^_handler)(struct dirent &_dirent))
{
    DIR *dirp = opendir(_path);
    if(dirp == 0)
        return VFSError::FromErrno(errno);
        
    dirent *entp;
    while((entp = readdir(dirp)) != NULL)
    {
        if((entp->d_namlen == 1 && entp->d_name[0] == '.') ||
           (entp->d_namlen == 2 && entp->d_name[0] == '.' && entp->d_name[1] == '.'))
            continue;
            
        if(!_handler(*entp))
            break;
    }
    
    closedir(dirp);
    
    return VFSError::Ok;
}

int VFSNativeHost::StatFS(const char *_path, VFSStatFS &_stat, bool (^_cancel_checker)())
{
    struct statfs info;
    if(statfs(_path, &info) < 0)
        return VFSError::FromErrno(errno);

    struct
    {
        u_int32_t attr_length;
        union
        {
            struct { attrreference val; char buf[NAME_MAX + 1]; }   __attribute__((aligned(4), packed)) name;
        };
    } __attribute__((aligned(4), packed)) attr_info;
    
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.volattr = ATTR_VOL_INFO | ATTR_VOL_NAME;
    if( getattrlist(info.f_mntonname, &attrs, &attr_info, sizeof(info), 0) != 0 )
        return VFSError::FromErrno(errno);
    
    _stat.volume_name = ((char*)&attr_info.name.val) + attr_info.name.val.attr_dataoffset;
    _stat.total_bytes = (uint64_t)info.f_blocks * (uint64_t)info.f_bsize;
    _stat.free_bytes  = (uint64_t)info.f_bfree  * (uint64_t)info.f_bsize;
    _stat.avail_bytes = (uint64_t)info.f_bavail * (uint64_t)info.f_bsize;

    return 0;
}

int VFSNativeHost::Unlink(const char *_path, bool (^_cancel_checker)())
{
    int ret = unlink(_path);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno(errno);
}

bool VFSNativeHost::IsWriteable() const
{
    return true; // dummy now
}

bool VFSNativeHost::IsWriteableAtPath(const char *_dir) const
{
    return true; // dummy now
}

