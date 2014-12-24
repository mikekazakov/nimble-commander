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
#import "VFSError.h"
#import "FSEventsDirUpdate.h"
#import "Common.h"
#import "NativeFSManager.h"
#import "RoutedIO.h"

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
                                         VFSCancelChecker _cancel_checker)
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
                       shared_ptr<VFSFile> &_target,
                       VFSCancelChecker _cancel_checker)
{
    auto file = make_shared<VFSNativeFile>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

const shared_ptr<VFSNativeHost> &VFSNativeHost::SharedHost()
{
    static auto host = make_shared<VFSNativeHost>();
    return host;
}

// return false on error or cancellation
static int CalculateDirectoriesSizesHelper(char *_path,
                                      size_t _path_len,
                                      bool *_iscancelling,
                                      VFSCancelChecker _checker,
                                      dispatch_queue_t _stat_queue,
                                      int64_t *_size_stock)
{
    if(_checker && _checker())
    {
        *_iscancelling = true;
        return VFSError::Cancelled;
    }
    
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK);
    
    DIR *dirp = io.opendir(_path);
    if( dirp == 0 )
        return VFSError::FromErrno();
    
    dirent *entp;
    
    _path[_path_len] = '/';
    _path[_path_len+1] = 0;
    char *var = _path + _path_len + 1;
    
    while((entp = io.readdir(dirp)) != NULL)
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
                
                if(io.lstat(full_path, &st) == 0)
                    *_size_stock += st.st_size;
                
                free(full_path);
            });
        }
    }
    
cleanup:
    io.closedir(dirp);
    _path[_path_len] = 0;
    return VFSError::Ok;
}


int VFSNativeHost::CalculateDirectoriesSizes(
                                      const vector<string> &_dirs,
                                      const char *_root_path, // relative to current host path
                                      VFSCancelChecker _cancel_checker,
                                      function<void(const char* _dir_sh_name, uint64_t _size)> _completion_handler
                                      )
{
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    
    if(_dirs.empty())
        return VFSError::Ok;
    
    if(_root_path == 0 ||
       _root_path[0] != '/')
        return VFSError::InvalidCall;
    
    bool iscancelling = false;
    char path[MAXPATHLEN];
    strcpy(path, _root_path);
    if(path[strlen(path)-1] != '/') strcat(path, "/");
    char *var = path + strlen(path);
    
    dispatch_queue_t stat_queue = dispatch_queue_create(__FILES_IDENTIFIER__".VFSNativeHost.CalculateDirectoriesSizes", 0);
    
    int error = VFSError::Ok;
    
    if(_dirs.size() == 1 && strisdotdot(_dirs.front()) )
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

bool VFSNativeHost::IsDirChangeObservingAvailable(const char *_path)
{
    if(!_path)
        return false;
    return access(_path, R_OK) == 0; // should use _not_ routed I/O here!
}

VFSHostDirObservationTicket VFSNativeHost::DirChangeObserve(const char *_path, function<void()> _handler)
{
    uint64_t t = FSEventsDirUpdate::Instance().AddWatchPath(_path, _handler);
    return t ? VFSHostDirObservationTicket(t, shared_from_this()) : VFSHostDirObservationTicket();
}

void VFSNativeHost::StopDirChangeObserving(unsigned long _ticket)
{
    FSEventsDirUpdate::Instance().RemoveWatchPathWithTicket(_ticket);
}

int VFSNativeHost::Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK);
    memset(&_st, 0, sizeof(_st));
    
    struct stat st;
    
    int ret = (_flags & VFSFlags::F_NoFollow) ? io.lstat(_path, &st) : io.stat(_path, &st);
    
    if(ret == 0) {
        VFSStat::FromSysStat(st, _st);
        return VFSError::Ok;
    }
    
    return VFSError::FromErrno();
}

int VFSNativeHost::IterateDirectoryListing(const char *_path, function<bool(const VFSDirEnt &_dirent)> _handler)
{
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK);
    
    DIR *dirp = io.opendir(_path);
    if(dirp == 0)
        return VFSError::FromErrno();
        
    dirent *entp;
    VFSDirEnt vfs_dirent;
    while((entp = io.readdir(dirp)) != NULL)
    {
        if((entp->d_namlen == 1 && entp->d_name[0] == '.') ||
           (entp->d_namlen == 2 && entp->d_name[0] == '.' && entp->d_name[1] == '.'))
            continue;

        vfs_dirent.type = entp->d_type;
        vfs_dirent.name_len = entp->d_namlen;
        memcpy(vfs_dirent.name, entp->d_name, entp->d_namlen+1);
            
        if(!_handler(vfs_dirent))
            break;
    }
    
    io.closedir(dirp);
    
    return VFSError::Ok;
}

int VFSNativeHost::StatFS(const char *_path, VFSStatFS &_stat, VFSCancelChecker _cancel_checker)
{
    struct statfs info;
    if(statfs(_path, &info) < 0)
        return VFSError::FromErrno();

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

int VFSNativeHost::Unlink(const char *_path, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.unlink(_path);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno();
}

bool VFSNativeHost::IsWriteable() const
{
    return true; // dummy now
}

bool VFSNativeHost::IsWriteableAtPath(const char *_dir) const
{
    return true; // dummy now
}

int VFSNativeHost::CreateDirectory(const char* _path, int _mode, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.mkdir(_path, _mode);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno();
}

int VFSNativeHost::RemoveDirectory(const char *_path, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.rmdir(_path);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno();
}

int VFSNativeHost::ReadSymlink(const char *_path, char *_buffer, size_t _buffer_size, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    ssize_t sz = io.readlink(_path, _buffer, _buffer_size);
    if(sz < 0)
        return VFSError::FromErrno();
    
    if(sz >= _buffer_size)
        return VFSError::SmallBuffer;
    
    _buffer[sz] = 0;
    return 0;
}

int VFSNativeHost::CreateSymlink(const char *_symlink_path,
                                 const char *_symlink_value,
                                 VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    int result = io.symlink(_symlink_value, _symlink_path);
    if(result < 0)
        return VFSError::FromErrno();
    
    return 0;
}

int VFSNativeHost::SetTimes(const char *_path,
                            int _flags,
                            struct timespec *_birth_time,
                            struct timespec *_mod_time,
                            struct timespec *_chg_time,
                            struct timespec *_acc_time,
                            VFSCancelChecker _cancel_checker
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
    int flags = (_flags & VFSFlags::F_NoFollow) ? FSOPT_NOFOLLOW : 0;
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    
    if(_birth_time != nullptr) {
        attrs.commonattr = ATTR_CMN_CRTIME;
        if(setattrlist(_path, &attrs, _birth_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno();
    }
    
    if(_chg_time != nullptr) {
        attrs.commonattr = ATTR_CMN_CHGTIME;
        if(setattrlist(_path, &attrs, _chg_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno();
    }
    
    if(_mod_time != nullptr) {
        attrs.commonattr = ATTR_CMN_MODTIME;
        if(setattrlist(_path, &attrs, _mod_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno();
    }
        
    if(_acc_time != nullptr) {
        attrs.commonattr = ATTR_CMN_ACCTIME;
        if(setattrlist(_path, &attrs, _acc_time, sizeof(struct timespec), flags) < 0)
            result = VFSError::FromErrno();
    }
    
    return result;
}

int VFSNativeHost::Rename(const char *_old_path, const char *_new_path, VFSCancelChecker _cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.rename(_old_path, _new_path);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno();
}

bool VFSNativeHost::IsNativeFS() const noexcept
{
    return true;
}
