//
//  VFSNativeHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/algo.h>
#include "DisplayNamesCache.h"
#include "VFSNativeHost.h"
#include "VFSNativeFile.h"
#include "VFSError.h"
#include "FSEventsDirUpdate.h"
#include "Common.h"
#include "NativeFSManager.h"
#include "RoutedIO.h"

// TODO:
// do some research about this new function:
// int getattrlistbulk(int, void *, void *, size_t, uint64_t) __OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0);

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

const char *VFSNativeHost::Tag = "native";

class VFSNativeHostConfiguration
{
public:
    const char *Tag() const
    {
        return VFSNativeHost::Tag;
    }
    
    const char *Junction() const
    {
        return "";
    }
    
    bool operator==(const VFSNativeHostConfiguration&) const
    {
        return true;
    }
};

VFSMeta VFSNativeHost::Meta()
{
    VFSMeta m;
    m.Tag = Tag;
    m.SpawnWithConfig = [](const VFSHostPtr &_parent, const VFSConfiguration& _config) {
        return SharedHost();
    };
    return m;
}

VFSNativeHost::VFSNativeHost():
    VFSHost("", 0, Tag)
{
}

int VFSNativeHost::FetchFlexibleListing(const char *_path,
                                        shared_ptr<VFSFlexibleListing> &_target,
                                        int _flags,
                                        VFSCancelChecker _cancel_checker)
{
    static const auto dirents_reserve_amount = 64;
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK); // don't need it
    const bool is_native_io = !io.isrouted();
    
    const int fd = io.open(_path, O_RDONLY | O_NONBLOCK | O_DIRECTORY | O_CLOEXEC);
    if( fd < 0 )
        return VFSError::FromErrno();
    auto close_fd = at_scope_end([fd]{
        close(fd);
    });
    
    bool need_to_add_dot_dot = true; // in some fancy situations there's no ".." entry in directory - we should insert it by hand
    if(_flags & VFSFlags::F_NoDotDot)
        need_to_add_dot_dot = false;
    
    vector< tuple<string, uint64_t, uint8_t > > dirents; // name, inode, entry_type
    dirents.reserve( dirents_reserve_amount );
    
    // initial directory lookup
    if( auto dirp = fdopendir(dup(fd)) ) {
        auto close_dir = at_scope_end([=]{ closedir(dirp); });
    
        if(_cancel_checker && _cancel_checker())
            return VFSError::Cancelled;
    
        while( auto entp = ::_readdir_unlocked(dirp, 1) ) {
            if(_cancel_checker && _cancel_checker())
                return VFSError::Cancelled;
            
            if( entp->d_ino == 0 ||      // apple's documentation suggest to skip such files
                strisdot(entp->d_name) ) // do not process self entry
                continue;
               
            if( strisdotdot( entp->d_name) && need_to_add_dot_dot ) { // special case for dot-dot directory
                // TODO: handle situation when ".." is not the #0 entry
                need_to_add_dot_dot = false;
                
                if(strcmp(_path, "/") == 0)
                    continue; // skip .. for root directory
                
                // it's very nice that sometimes OSX can not set a valid flags on ".." file in a mount point
                // so for now - just fix it by hand
                if(entp->d_type == 0)
                    entp->d_type = DT_DIR; // a very-very strange bugfix
            }
            
            dirents.emplace_back(string(entp->d_name, entp->d_namlen), entp->d_ino, entp->d_type);
        }
    }
    else
        return VFSError::FromErrno();
    
    if(need_to_add_dot_dot)
        dirents.insert(begin(dirents), make_tuple("..", 0, DT_DIR)); // add ".." entry by hand
    
    // set up or listing structure
    VFSFlexibleListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(_path);
    listing_source.inodes.reset( variable_container<>::type::dense );
    listing_source.atimes.reset( variable_container<>::type::dense );
    listing_source.mtimes.reset( variable_container<>::type::dense );
    listing_source.ctimes.reset( variable_container<>::type::dense );
    listing_source.btimes.reset( variable_container<>::type::dense );
    listing_source.unix_flags.reset( variable_container<>::type::dense );
    listing_source.uids.reset( variable_container<>::type::dense );
    listing_source.gids.reset( variable_container<>::type::dense );
    listing_source.sizes.reset( variable_container<>::type::dense );
    listing_source.symlinks.reset( variable_container<>::type::sparse );
    listing_source.display_filenames.reset( variable_container<>::type::sparse );
    spinlock symlinks_guard;
    spinlock display_names_guard;
    
    unsigned amount = (unsigned)dirents.size();
    listing_source.filenames.resize(amount);
    listing_source.inodes.resize(amount);
    listing_source.unix_types.resize(amount);
    listing_source.atimes.resize(amount);
    listing_source.mtimes.resize(amount);
    listing_source.ctimes.resize(amount);
    listing_source.btimes.resize(amount);
    listing_source.unix_modes.resize(amount);
    listing_source.unix_flags.resize(amount);
    listing_source.uids.resize(amount);
    listing_source.gids.resize(amount);
    listing_source.sizes.resize(amount);
    
    for(unsigned n = 0, e = (unsigned)dirents.size(); n!=e; ++n ) {
        auto &i = dirents[n];
        listing_source.filenames[n] = move(get<0>(i));
        listing_source.inodes[n] = get<1>(i);
        listing_source.unix_types[n] = get<2>(i);
    }
    
    // stat files, read info about symlinks ands possible display names
    dispatch_apply(amount, dispatch_get_global_queue(0, 0), [&](size_t n) {
        if(_cancel_checker && _cancel_checker()) return;
        auto filename = listing_source.filenames[n].c_str();
        
        // stat the file
        struct stat stat_buffer;
        if( (is_native_io && fstatat(fd, filename, &stat_buffer, 0) == 0) ||
           (!is_native_io && io.stat((listing_source.directories[0] + filename).c_str(), &stat_buffer) == 0 ) ) {
            listing_source.atimes[n]        = stat_buffer.st_atimespec.tv_sec;
            listing_source.mtimes[n]        = stat_buffer.st_mtimespec.tv_sec;
            listing_source.ctimes[n]        = stat_buffer.st_ctimespec.tv_sec;
            listing_source.btimes[n]        = stat_buffer.st_birthtimespec.tv_sec;
            listing_source.unix_modes[n]    = stat_buffer.st_mode;
            listing_source.unix_flags[n]    = stat_buffer.st_flags;
            listing_source.uids[n]          = stat_buffer.st_uid;
            listing_source.gids[n]          = stat_buffer.st_gid;
            listing_source.sizes[n]         = stat_buffer.st_size;
            // add other stat info here. there's a lot more
        }
        
        // if we're dealing with a symlink - read it's content to know the real file path
        if( listing_source.unix_types[n] == DT_LNK ) {
            char linkpath[MAXPATHLEN];
            ssize_t sz = is_native_io ?
                readlinkat(fd, filename, linkpath, MAXPATHLEN) :
                io.readlink((listing_source.directories[0] + filename).c_str(), linkpath, MAXPATHLEN);
            if(sz != -1) {
                linkpath[sz] = 0;
                lock_guard<spinlock> guard(symlinks_guard);
                listing_source.symlinks.insert(n, linkpath);
            }
            
            // stat the original file so we can extract some interesting info from it
            struct stat link_stat_buffer;
            if( (is_native_io && fstatat(fd, filename, &link_stat_buffer, AT_SYMLINK_NOFOLLOW) == 0) ||
               (!is_native_io && io.lstat((listing_source.directories[0] + filename).c_str(), &link_stat_buffer) == 0 ) )
               if(link_stat_buffer.st_flags & UF_HIDDEN)
                listing_source.unix_flags[n] |= UF_HIDDEN; // currently using only UF_HIDDEN flag
        }
        
        if( _flags & VFSFlags::F_LoadDisplayNames )
            if( S_ISDIR(listing_source.unix_modes[n]) &&
               !strisdotdot(listing_source.filenames[n]) ) {
                static auto &dnc = DisplayNamesCache::Instance();
                if( auto display_name = dnc.DisplayNameByStat(stat_buffer, listing_source.directories[0] + filename) ) {
                    lock_guard<spinlock> guard(display_names_guard);
                    listing_source.display_filenames.insert(n, display_name);
                }
            }
    });
    
    _target = VFSFlexibleListing::Build(move(listing_source));
    
    return 0;
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
                                      bool &_iscancelling,
                                      VFSCancelChecker _checker,
                                      dispatch_queue &_stat_queue,
                                      int64_t &_size_stock)
{
    if(_checker && _checker())
    {
        _iscancelling = true;
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
            _iscancelling = true;
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
            if(_iscancelling)
                goto cleanup;
        }
        else if(entp->d_type == DT_REG || entp->d_type == DT_LNK)
        {
            char *full_path = (char*) malloc(_path_len + entp->d_namlen + 2);
            memcpy(full_path, _path, _path_len + entp->d_namlen + 2);
            
            _stat_queue.async([&,full_path]{
                if(_iscancelling) return;
                
                struct stat st;
                
                if(io.lstat(full_path, &st) == 0)
                    _size_stock += st.st_size;
                
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
    
    dispatch_queue stat_queue(__FILES_IDENTIFIER__".VFSNativeHost.CalculateDirectoriesSizes");
    
    int error = VFSError::Ok;
    
    if(_dirs.size() == 1 && strisdotdot(_dirs.front()) )
    { // special case for a single ".." entry
        int64_t size = 0;
        int result = CalculateDirectoriesSizesHelper(path, strlen(path), iscancelling, _cancel_checker, stat_queue, size);
        stat_queue.sync([]{});
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
                                                iscancelling,
                                                _cancel_checker,
                                                stat_queue,
                                                total_size);
        stat_queue.sync([]{});
        
        if(iscancelling || (_cancel_checker && _cancel_checker())) // check if we need to quit
            goto cleanup;
        
        if(result >= 0)
            _completion_handler(i.c_str(), total_size);
        else
            error = result;
    }
    
cleanup:
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

VFSConfiguration VFSNativeHost::Configuration() const
{
    static const auto aa = VFSNativeHostConfiguration();
    return aa;
}
