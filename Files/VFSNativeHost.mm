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

#import "NativeFSManager.h"

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

const char *VFSNativeHost::Tag = "native";

VFSNativeHost::VFSNativeHost():
    VFSHost("", 0)
{
}

const char *VFSNativeHost::FSTag() const
{
    return Tag;
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
                                      chained_strings _dirs,
                                      const string &_root_path, // relative to current host path
                                      bool (^_cancel_checker)(),
                                      void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size)
                                      )
{
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    
    if(_dirs.empty())
        return VFSError::Ok;
    
    bool iscancelling = false;
    char path[MAXPATHLEN];
    strcpy(path, _root_path.c_str());
    if(path[_root_path.length()-1] != '/') strcat(path, "/");
    char *var = path + strlen(path);
    
    dispatch_queue_t stat_queue = dispatch_queue_create("info.filesmanager.Files.VFSNativeHost.CalculateDirectoriesSizes", 0);
    
    int error = VFSError::Ok;
    
    if(_dirs.singleblock() &&
       _dirs.size() == 1 &&
       strisdotdot(_dirs.front().c_str()) )
    { // special case for a single ".." entry
        int64_t size = 0;
        int result = CalculateDirectoriesSizesHelper(path, strlen(path), &iscancelling, _cancel_checker, stat_queue, &size);
        dispatch_sync(stat_queue, ^{});
        if(iscancelling || (_cancel_checker && _cancel_checker())) // check if we need to quit
            goto cleanup;
        if(result >= 0)
            _completion_handler("..", size);
        else
            error = result;
    }
    else for(const auto &i: _dirs)
    {
        memcpy(var, i.c_str(), i.size() + 1);
        
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
            _completion_handler(i.c_str(), total_size);
        else
            error = result;
    }
    
cleanup:
    dispatch_release(stat_queue);
    return error;
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

    auto volume = NativeFSManager::Instance().VolumeFromMountPoint(info.f_mntonname);
    if(!volume)
        return VFSError::GenericError;
    
    NativeFSManager::Instance().UpdateSpaceInformation(volume);
    
    _stat.volume_name   = volume->verbose.name.UTF8String;
    _stat.total_bytes   = volume->basic.total_bytes;
    _stat.free_bytes    = volume->basic.free_bytes;
    _stat.avail_bytes   = volume->basic.available_bytes;
    
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

int VFSNativeHost::CreateDirectory(const char* _path, bool (^_cancel_checker)())
{
    int ret = mkdir(_path, 0777);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno(errno);
}

int VFSNativeHost::ReadSymlink(const char *_path, char *_buffer, size_t _buffer_size, bool (^_cancel_checker)())
{
    ssize_t sz = readlink(_path, _buffer, _buffer_size);
    if(sz < 0)
        return VFSError::FromErrno(errno);
    
    if(sz >= _buffer_size)
        return VFSError::SmallBuffer;
    
    _buffer[sz] = 0;
    return 0;
}

int VFSNativeHost::CreateSymlink(const char *_symlink_path,
                                 const char *_symlink_value,
                                 bool (^_cancel_checker)())
{
    int result = symlink(_symlink_value, _symlink_path);
    if(result < 0)
        return VFSError::FromErrno(errno);
    
    return 0;
}

int VFSNativeHost::SetTimes(const char *_path,
                            int _flags,
                            struct timespec *_birth_time,
                            struct timespec *_mod_time,
                            struct timespec *_chg_time,
                            struct timespec *_acc_time,
                            bool (^_cancel_checker)()
                            )
{
    if(_path == nullptr)
        return VFSError::InvalidCall;
    
    if(_birth_time == nullptr &&
       _mod_time == nullptr &&
       _chg_time == nullptr &&
       _acc_time == nullptr)
        return 0;
    
    // TODO: optimize this with first opening a file descriptor and then using fsetattrlist.
    // (that should be faster).
    
    int result = 0;
    int flags = (_flags & VFSHost::F_NoFollow) ? FSOPT_NOFOLLOW : 0;
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    
    if(_birth_time != nullptr) {
        attrs.commonattr = ATTR_CMN_CRTIME;
        if(setattrlist(_path, &attrs, _birth_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno(errno);
    }
    
    if(_chg_time != nullptr) {
        attrs.commonattr = ATTR_CMN_CHGTIME;
        if(setattrlist(_path, &attrs, _chg_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno(errno);
    }
    
    if(_mod_time != nullptr) {
        attrs.commonattr = ATTR_CMN_MODTIME;
        if(setattrlist(_path, &attrs, _mod_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno(errno);
    }
        
    if(_acc_time != nullptr) {
        attrs.commonattr = ATTR_CMN_ACCTIME;
        if(setattrlist(_path, &attrs, _acc_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno(errno);
    }
    
    return result;
}
