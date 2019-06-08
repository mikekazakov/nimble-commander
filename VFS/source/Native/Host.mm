// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <OpenDirectory/OpenDirectory.h>
#include <sys/attr.h>
#include <sys/errno.h>
#include <sys/vnode.h>
#include <Habanero/algo.h>
#include <Utility/PathManip.h>
#include <Utility/FSEventsDirUpdate.h>
#include <Utility/NativeFSManager.h>
#include <RoutedIO/RoutedIO.h>
#include "DisplayNamesCache.h"
#include "Host.h"
#include "File.h"
#include <VFS/VFSError.h>
#include "../ListingInput.h"
#include "Fetching.h"
#include <Habanero/DispatchGroup.h>
#include <Utility/ObjCpp.h>
#include <sys/mount.h>

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

namespace nc::vfs {

static uint32_t MergeUnixFlags( uint32_t _symlink_flags, uint32_t _target_flags ) noexcept;
    
using namespace native;

const char *NativeHost::UniqueTag = "native";

class VFSNativeHostConfiguration
{
public:
    const char *Tag() const
    {
        return VFSNativeHost::UniqueTag;
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

VFSMeta NativeHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = []([[maybe_unused]] const VFSHostPtr &_parent,
                           [[maybe_unused]] const VFSConfiguration& _config,
                           [[maybe_unused]] VFSCancelChecker _cancel_checker) {
        return SharedHost();
    };
    return m;
}

NativeHost::NativeHost():
    Host("", 0, UniqueTag)
{
    AddFeatures(HostFeatures::FetchUsers |
                HostFeatures::FetchGroups |
                HostFeatures::SetOwnership |
                HostFeatures::SetFlags |
                HostFeatures::SetPermissions |
                HostFeatures::SetTimes );
}

bool NativeHost::ShouldProduceThumbnails() const
{
    return true;
}

int NativeHost::FetchDirectoryListing(const char *_path,
                                      std::shared_ptr<VFSListing> &_target,
                                      unsigned long _flags,
                                      const VFSCancelChecker &_cancel_checker)
{
    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    const auto need_to_add_dot_dot = !(_flags & VFSFlags::F_NoDotDot) &&
                                     strcmp(_path, "/") != 0;
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK);
    const bool is_native_io = !io.isrouted();
    const int fd = io.open(_path, O_RDONLY | O_NONBLOCK | O_DIRECTORY | O_CLOEXEC);
    if( fd < 0 )
        return VFSError::FromErrno();
    auto close_fd = at_scope_end([fd]{
        close(fd);
    });
    
    const int approx_entries_count = [&]{
        auto count = Fetching::CountDirEntries(fd);
        if( count < 0 ) // negative means error
            count = 64;
         return count + (need_to_add_dot_dot ? 1 : 0);
    }();
    
    using nc::base::variable_container;
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(_path);
    listing_source.inodes.reset( variable_container<>::type::dense );
    listing_source.atimes.reset( variable_container<>::type::dense );
    listing_source.mtimes.reset( variable_container<>::type::dense );
    listing_source.ctimes.reset( variable_container<>::type::dense );
    listing_source.btimes.reset( variable_container<>::type::dense );
    listing_source.add_times.reset( variable_container<>::type::sparse );
    listing_source.unix_flags.reset( variable_container<>::type::dense );
    listing_source.uids.reset( variable_container<>::type::dense );
    listing_source.gids.reset( variable_container<>::type::dense );
    listing_source.sizes.reset( variable_container<>::type::dense );
    listing_source.symlinks.reset( variable_container<>::type::sparse );
    listing_source.display_filenames.reset( variable_container<>::type::sparse );
    
    auto resize_dense = [&](int _sz) {
        listing_source.filenames.resize( _sz );
        listing_source.inodes.resize( _sz );
        listing_source.unix_types.resize( _sz );
        listing_source.atimes.resize( _sz );
        listing_source.mtimes.resize( _sz );
        listing_source.ctimes.resize( _sz);
        listing_source.btimes.resize( _sz );
        listing_source.unix_modes.resize( _sz );
        listing_source.unix_flags.resize( _sz );
        listing_source.uids.resize( _sz );
        listing_source.gids.resize( _sz );
        listing_source.sizes.resize( _sz );
    };
    
    auto fill = [&]( int _n, const Fetching::CallbackParams &_params ) {
        listing_source.filenames[_n]     = _params.filename;
        listing_source.inodes[_n]        = _params.inode;
        listing_source.unix_types[_n]    = IFTODT(_params.mode);
        listing_source.atimes[_n]        = _params.acc_time;
        listing_source.mtimes[_n]        = _params.mod_time;
        listing_source.ctimes[_n]        = _params.chg_time;
        listing_source.btimes[_n]        = _params.crt_time;
        listing_source.unix_modes[_n]    = _params.mode;
        listing_source.unix_flags[_n]    = _params.flags;
        listing_source.uids[_n]          = _params.uid;
        listing_source.gids[_n]          = _params.gid;
        listing_source.sizes[_n]         = _params.size;
        if( _params.add_time >= 0 )
            listing_source.add_times.insert(_n, _params.add_time );
        
        if( _flags & VFSFlags::F_LoadDisplayNames )
            if( S_ISDIR(listing_source.unix_modes[_n]) &&
               !listing_source.filenames[_n].empty() &&
               !strisdotdot(listing_source.filenames[_n]) ) {
                static auto &dnc = DisplayNamesCache::Instance();
                if( auto display_name = dnc.DisplayName( _params.inode, _params.dev, listing_source.directories[0] + listing_source.filenames[_n]) )
                    listing_source.display_filenames.insert(_n, display_name);
            }
    };
    
    resize_dense( approx_entries_count );
    
    int next_entry_index = 0;
    auto cb_param = [&](const Fetching::CallbackParams &_params){
        fill(next_entry_index++, _params);
    };
    
    if( need_to_add_dot_dot ) {
        Fetching::ReadSingleEntryAttributesByPath( io, _path, cb_param );
        listing_source.filenames[0] = "..";
    }
    
    auto cb_fetch = [&](int _fetched_now){
        // check if final entries count is more than previous approximate
        if( next_entry_index + _fetched_now > approx_entries_count )
            resize_dense( next_entry_index + _fetched_now );
    };

    // when Admin Mode is on - we use different fetch route
    const int ret = is_native_io ?
        Fetching::ReadDirAttributesBulk( fd, cb_fetch, cb_param ) :
        Fetching::ReadDirAttributesStat( fd, listing_source.directories[0].c_str(), cb_fetch, cb_param);
    if( ret != 0 )
        return VFSError::FromErrno(ret);
    
    if( _cancel_checker && _cancel_checker() ) return  VFSError::Cancelled;
    
    // check if final entries count is less than approximate
    if( next_entry_index < approx_entries_count )
        resize_dense( next_entry_index );
    
    // a little more work with symlinks, if there are any
    for( int n = 0; n < next_entry_index; ++n )
        if( listing_source.unix_types[n] == DT_LNK ) {
            // read an actual link path
            char linkpath[MAXPATHLEN];
            const ssize_t sz = is_native_io ?
                readlinkat(fd,
                           listing_source.filenames[n].c_str(),
                           linkpath,
                           MAXPATHLEN) :
                io.readlink((listing_source.directories[0] + listing_source.filenames[n]).c_str(),
                            linkpath,
                            MAXPATHLEN);
            if( sz != -1 ) {
                linkpath[sz] = 0;
                listing_source.symlinks.insert(n, linkpath);
            }
            
            // stat the target file
            struct stat stat_buffer;
            const auto stat_ret = is_native_io ?
                fstatat(fd,
                        listing_source.filenames[n].c_str(),
                        &stat_buffer,
                        0) :
                io.stat((listing_source.directories[0] + listing_source.filenames[n]).c_str(),
                        &stat_buffer);
            if( stat_ret == 0 ) {
                listing_source.unix_modes[n]    = stat_buffer.st_mode;
                listing_source.unix_flags[n]    = MergeUnixFlags(listing_source.unix_flags[n],
                                                                 stat_buffer.st_flags);
                listing_source.uids[n]          = stat_buffer.st_uid;
                listing_source.gids[n]          = stat_buffer.st_gid;
                listing_source.sizes[n]         = S_ISDIR(stat_buffer.st_mode) ?
                                                    -1 :
                                                    stat_buffer.st_size;
            }
        }

    _target = VFSListing::Build(std::move(listing_source));
        
    return 0;
}

int NativeHost::FetchSingleItemListing(const char *_path,
                                       std::shared_ptr<VFSListing> &_target,
                                       unsigned long _flags,
                                       const VFSCancelChecker &_cancel_checker)
{
    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    if( _cancel_checker && _cancel_checker() )
        return VFSError::Cancelled;
    
    char path[MAXPATHLEN], directory[MAXPATHLEN], filename[MAXPATHLEN];
    strcpy(path, _path);
    
    if( !EliminateTrailingSlashInPath(path) ||
        !GetDirectoryContainingItemFromPath(path, directory) ||
        !GetFilenameFromPath(path, filename) )
        return VFSError::InvalidCall;
    
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK);

    using nc::base::variable_container;
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = directory;
    listing_source.inodes.reset( variable_container<>::type::common );
    listing_source.atimes.reset( variable_container<>::type::common );
    listing_source.mtimes.reset( variable_container<>::type::common );
    listing_source.ctimes.reset( variable_container<>::type::common );
    listing_source.btimes.reset( variable_container<>::type::common );
    listing_source.add_times.reset( variable_container<>::type::sparse );
    listing_source.unix_flags.reset( variable_container<>::type::common );
    listing_source.uids.reset( variable_container<>::type::common );
    listing_source.gids.reset( variable_container<>::type::common );
    listing_source.sizes.reset( variable_container<>::type::common );
    listing_source.symlinks.reset( variable_container<>::type::sparse );
    listing_source.display_filenames.reset( variable_container<>::type::sparse );

    listing_source.unix_modes.resize(1);
    listing_source.unix_types.resize(1);
    listing_source.filenames.emplace_back( filename );

    auto cb_param = [&](const Fetching::CallbackParams &_params){
        listing_source.inodes[0]        = _params.inode;
        listing_source.unix_types[0]    = IFTODT(_params.mode);
        listing_source.atimes[0]        = _params.acc_time;
        listing_source.mtimes[0]        = _params.mod_time;
        listing_source.ctimes[0]        = _params.chg_time;
        listing_source.btimes[0]        = _params.crt_time;
        listing_source.unix_modes[0]    = _params.mode;
        listing_source.unix_flags[0]    = _params.flags;
        listing_source.uids[0]          = _params.uid;
        listing_source.gids[0]          = _params.gid;
        listing_source.sizes[0]         = _params.size;
        if( _params.add_time >= 0 )
            listing_source.add_times.insert(0, _params.add_time );
        
        if( _flags & VFSFlags::F_LoadDisplayNames )
            if( S_ISDIR(listing_source.unix_modes[0]) &&
               !listing_source.filenames[0].empty() &&
               !strisdotdot(listing_source.filenames[0]) ) {
                static auto &dnc = DisplayNamesCache::Instance();
                if( auto display_name = dnc.DisplayName(_params.inode,
                                                        _params.dev,
                                                        path) )
                    listing_source.display_filenames.insert(0, display_name);
            }
    };
    
    int ret = Fetching::ReadSingleEntryAttributesByPath( io, _path, cb_param );
    if( ret != 0 )
        return VFSError::FromErrno(ret);
    
  // a little more work with symlink, if any
    if( listing_source.unix_types[0] == DT_LNK ) {
        // read an actual link path
        char linkpath[MAXPATHLEN];
        const ssize_t sz = io.readlink(path, linkpath, MAXPATHLEN);
        if( sz != -1 ) {
            linkpath[sz] = 0;
            listing_source.symlinks.insert(0, linkpath);
        }
        
        // stat the target file
        struct stat stat_buffer;
        const auto stat_ret = io.stat(path, &stat_buffer);
        if( stat_ret == 0 ) {
            listing_source.unix_modes[0]    = stat_buffer.st_mode;
            listing_source.unix_flags[0]    = MergeUnixFlags(listing_source.unix_flags[0],
                                                             stat_buffer.st_flags);
            listing_source.uids[0]          = stat_buffer.st_uid;
            listing_source.gids[0]          = stat_buffer.st_gid;
            listing_source.sizes[0]         = stat_buffer.st_size;
        }
    }
    
    _target = VFSListing::Build( std::move(listing_source) );
    
    return 0;
}

int NativeHost::CreateFile(const char* _path,
                           std::shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker)
{
    auto file = std::make_shared<File>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

const std::shared_ptr<NativeHost> &NativeHost::SharedHost() noexcept
{
    static auto host = std::make_shared<NativeHost>();
    return host;
}

// return false on error or cancellation
static int CalculateDirectoriesSizesHelper(char *_path,
                                      size_t _path_len,
                                      bool &_iscancelling,
                                      const VFSCancelChecker &_checker,
                                      dispatch_queue &_stat_queue,
                                      int64_t &_size_stock)
{
    if(_checker && _checker())
    {
        _iscancelling = true;
        return VFSError::Cancelled;
    }
    
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK);
    
    const auto dirp = io.opendir(_path);
    if( dirp == 0 )
        return VFSError::FromErrno();
    
    dirent *entp;
    
    _path[_path_len] = '/';
    _path[_path_len+1] = 0;
    char *var = _path + _path_len + 1;
    
    while((entp = io.readdir(dirp)) != NULL) {
        if( _checker && _checker() ) {
            _iscancelling = true;
            goto cleanup;
        }
        
        if( entp->d_ino == 0 )
            continue; // apple's documentation suggest to skip such files
        if( entp->d_namlen == 1 && entp->d_name[0] == '.' )
            continue; // do not process self entry
        if( entp->d_namlen == 2 && entp->d_name[0] == '.' && entp->d_name[1] == '.' )
            continue; // do not process parent entry
        
        memcpy(var, entp->d_name, entp->d_namlen+1);
        if( entp->d_type == DT_DIR ) {
            CalculateDirectoriesSizesHelper(_path,
                                      _path_len + entp->d_namlen + 1,
                                      _iscancelling,
                                      _checker,
                                      _stat_queue,
                                      _size_stock);
            if(_iscancelling)
                goto cleanup;
        }
        else if( entp->d_type == DT_REG || entp->d_type == DT_LNK ) {
            std::string full_path = _path;
            _stat_queue.async([&,full_path = move(full_path)]{
                if( _iscancelling )
                    return;
                
                struct stat st;
                if( io.lstat(full_path.c_str(), &st) == 0 )
                    _size_stock += st.st_size;
            });
        }
    }
    
cleanup:
    io.closedir(dirp);
    _path[_path_len] = 0;
    return VFSError::Ok;
}


ssize_t NativeHost::CalculateDirectorySize(const char *_path,
                                           const VFSCancelChecker &_cancel_checker)
{
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    
    if(_path == 0 ||
       _path[0] != '/')
        return VFSError::InvalidCall;
    
    bool iscancelling = false;
    char path[MAXPATHLEN];
    strcpy(path, _path);
    
    dispatch_queue stat_queue("VFSNativeHost.CalculateDirectoriesSizes");
    
    int64_t size = 0;
    int result = CalculateDirectoriesSizesHelper(path, strlen(path), iscancelling, _cancel_checker, stat_queue, size);
    stat_queue.sync([]{});
    if(result >= 0)
        return size;
    else
        return result;
}

bool NativeHost::IsDirChangeObservingAvailable(const char *_path)
{
    if(!_path)
        return false;
    return access(_path, R_OK) == 0; // should use _not_ routed I/O here!
}

HostDirObservationTicket NativeHost::DirChangeObserve(const char *_path,
                                                      std::function<void()> _handler)
{
    auto &inst = nc::utility::FSEventsDirUpdate::Instance();
    uint64_t t = inst.AddWatchPath(_path, std::move(_handler));
    return t ? HostDirObservationTicket(t, shared_from_this()) : HostDirObservationTicket();
}

void NativeHost::StopDirChangeObserving(unsigned long _ticket)
{
    auto &inst = nc::utility::FSEventsDirUpdate::Instance();    
    inst.RemoveWatchPathWithTicket(_ticket);
}

int NativeHost::Stat(const char *_path,
                     VFSStat &_st,
                     unsigned long _flags,
                     [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
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

int NativeHost::IterateDirectoryListing(const char *_path,
                                        const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    auto &io = RoutedIO::InterfaceForAccess(_path, R_OK);
    
    DIR *dirp = io.opendir(_path);
    if(dirp == 0)
        return VFSError::FromErrno();
    const auto close_dirp = at_scope_end([&]{ io.closedir(dirp); });
        
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
    
    
    return VFSError::Ok;
}

int NativeHost::StatFS(const char *_path,
                       VFSStatFS &_stat,
                       [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    struct statfs info;
    if(statfs(_path, &info) < 0)
        return VFSError::FromErrno();

    auto volume = utility::NativeFSManager::Instance().VolumeFromMountPoint(info.f_mntonname);
    if(!volume)
        return VFSError::GenericError;
    
    utility::NativeFSManager::Instance().UpdateSpaceInformation(volume);
    
    _stat.volume_name   = volume->verbose.name.UTF8String;
    _stat.total_bytes   = volume->basic.total_bytes;
    _stat.free_bytes    = volume->basic.free_bytes;
    _stat.avail_bytes   = volume->basic.available_bytes;
    
    return 0;
}

int NativeHost::Unlink(const char *_path,
                       [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.unlink(_path);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno();
}

bool NativeHost::IsWritable() const
{
    return true; // dummy now
}

int NativeHost::CreateDirectory(const char* _path,
                                int _mode,
                                [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.mkdir(_path, mode_t(_mode));
    if(ret == 0)
        return 0;
    return VFSError::FromErrno();
}

int NativeHost::RemoveDirectory(const char *_path,
                                [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.rmdir(_path);
    if(ret == 0)
        return 0;
    return VFSError::FromErrno();
}

int NativeHost::ReadSymlink(const char *_path,
                            char *_buffer,
                            size_t _buffer_size,
                            [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    auto &io = RoutedIO::Default;
    ssize_t sz = io.readlink(_path, _buffer, _buffer_size);
    if(sz < 0)
        return VFSError::FromErrno();
    
    if(sz >= (long)_buffer_size)
        return VFSError::SmallBuffer;
    
    _buffer[sz] = 0;
    return 0;
}

int NativeHost::CreateSymlink(const char *_symlink_path,
                              const char *_symlink_value,
                              [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    auto &io = RoutedIO::Default;
    int result = io.symlink(_symlink_value, _symlink_path);
    if(result < 0)
        return VFSError::FromErrno();
    
    return 0;
}

int NativeHost::SetTimes(const char *_path,
                         std::optional<time_t> _birth_time,
                         std::optional<time_t> _mod_time,
                         std::optional<time_t> _chg_time,
                         std::optional<time_t> _acc_time,
                         [[maybe_unused]] const VFSCancelChecker &_cancel_checker
                         )
{
    if(_path == nullptr)
        return VFSError::InvalidCall;
    
    if( !_birth_time  && !_mod_time && !_chg_time  && !_acc_time )
        return VFSError::Ok;
    
    auto &io = RoutedIO::Default;
    if( _birth_time && io.chbtime(_path, *_birth_time) != 0 )
        return VFSError::FromErrno();
    if( _mod_time && io.chmtime(_path, *_mod_time) != 0 )
        return VFSError::FromErrno();
    if( _chg_time && io.chctime(_path, *_chg_time) != 0 )
        return VFSError::FromErrno();
    if( _acc_time && io.chatime(_path, *_acc_time) != 0 )
        return VFSError::FromErrno();
    
    return VFSError::Ok;
}

int NativeHost::Rename(const char *_old_path,
                       const char *_new_path,
                       [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    auto &io = RoutedIO::Default;
    int ret = io.rename(_old_path, _new_path);
    if(ret == 0)
        return VFSError::Ok;
    return VFSError::FromErrno();
}

bool NativeHost::IsNativeFS() const noexcept
{
    return true;
}

VFSConfiguration NativeHost::Configuration() const
{
    static const auto aa = VFSNativeHostConfiguration();
    return aa;
}

int NativeHost::Trash(const char *_path,
                      [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path == nullptr )
        return VFSError::FromErrno(EINVAL);
    
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(0,
                                                           (const UInt8*)_path,
                                                           strlen(_path),
                                                           false);
    if( !url )
        return VFSError::FromErrno(EINVAL);
    
    NSError *error;
    const auto result = [NSFileManager.defaultManager trashItemAtURL:(__bridge NSURL*)url
                                                    resultingItemURL:nil
                                                               error:&error];
    CFRelease(url);
    
    if( result )
        return VFSError::Ok;
    else
        return VFSError::FromNSError(error);
}

int NativeHost::SetPermissions(const char *_path,
                               uint16_t _mode,
                               [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path == nullptr )
        return VFSError::FromErrno(EINVAL);
    
    auto &io = RoutedIO::Default;
    const auto ret = io.chmod(_path, _mode);
    if( ret == 0 )
        return VFSError::Ok;
    return VFSError::FromErrno();
}

int NativeHost::SetFlags(const char *_path,
                         uint32_t _flags,
                         [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path == nullptr )
        return VFSError::FromErrno(EINVAL);
    
    auto &io = RoutedIO::Default;
    const auto ret = io.chflags(_path, _flags);
    if( ret == 0 )
        return VFSError::Ok;
    return VFSError::FromErrno();
}

int NativeHost::SetOwnership(const char *_path,
                             unsigned _uid,
                             unsigned _gid,
                             [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path == nullptr )
        return VFSError::FromErrno(EINVAL);

    auto &io = RoutedIO::Default;
    const auto ret = io.chown(_path, _uid, _gid);
    if( ret == 0 )
        return VFSError::Ok;
    return VFSError::FromErrno();
}

int NativeHost::FetchUsers(std::vector<VFSUser> &_target,
                           [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    _target.clear();

    NSError *error;
    const auto node_name = @"/Local/Default";
    const auto node = [ODNode nodeWithSession:ODSession.defaultSession
                                         name:node_name
                                        error:&error];
    if( !node )
        return VFSError::FromNSError(error);

    const auto attributes = @[kODAttributeTypeUniqueID, kODAttributeTypeFullName];
    const auto query = [ODQuery queryWithNode:node
                               forRecordTypes:kODRecordTypeUsers
                                    attribute:nil
                                    matchType:0
                                  queryValues:nil
                             returnAttributes:attributes
                               maximumResults:0
                                        error:&error];
    if( !query )
        return VFSError::FromNSError(error);

    const auto records = [query resultsAllowingPartial:false
                                                 error:&error];
    if( !records )
        return VFSError::FromNSError(error);
    
    for( ODRecord *record in records ) {
        const auto uid_values = [record valuesForAttribute:kODAttributeTypeUniqueID error:nil];
        if( uid_values == nil || uid_values.count == 0 )
            continue;
        const auto uid = (uint32_t)objc_cast<NSString>(uid_values.firstObject).integerValue;

        const auto gecos_values = [record valuesForAttribute:kODAttributeTypeFullName error:nil];
        const auto gecos = (gecos_values && gecos_values.count > 0) ?
            objc_cast<NSString>(gecos_values.firstObject).UTF8String : "";
        
        VFSUser user;
        user.uid = uid;
        user.name = record.recordName.UTF8String;
        user.gecos = gecos;
        _target.emplace_back( std::move(user) );
    }
    
    sort(begin(_target),
         end(_target),
         [](const auto &_1, const auto &_2){ return (signed)_1.uid < (signed)_2.uid; });
    _target.erase(unique(begin(_target),
                          end(_target),
                          [](const auto &_1, const auto &_2){ return _1.uid == _2.uid; }),
                  end(_target));
    
    return VFSError::Ok;
}

int NativeHost::FetchGroups(std::vector<VFSGroup> &_target,
                            [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    _target.clear();

    NSError *error;
    const auto node_name = @"/Local/Default";
    const auto node = [ODNode nodeWithSession:ODSession.defaultSession
                                         name:node_name
                                        error:&error];
    if( !node )
        return VFSError::FromNSError(error);

    const auto attributes = @[kODAttributeTypePrimaryGroupID, kODAttributeTypeFullName];
    const auto query = [ODQuery queryWithNode:node
                               forRecordTypes:kODRecordTypeGroups
                                    attribute:nil
                                    matchType:0
                                  queryValues:nil
                             returnAttributes:attributes
                               maximumResults:0
                                        error:&error];
    if( !query )
        return VFSError::FromNSError(error);
    
    
    const auto records = [query resultsAllowingPartial:false
                                                 error:&error];
    if( !records )
        return VFSError::FromNSError(error);
    
    for( ODRecord *record in records ) {
        const auto gid_values =[record valuesForAttribute:kODAttributeTypePrimaryGroupID error:nil];
        if( gid_values == nil || gid_values.count == 0 )
            continue;
        const auto gid = (uint32_t)objc_cast<NSString>(gid_values.firstObject).integerValue;

        const auto gecos_values = [record valuesForAttribute:kODAttributeTypeFullName error:nil];
        const auto gecos = (gecos_values && gecos_values.count > 0) ?
            objc_cast<NSString>(gecos_values.firstObject).UTF8String : "";
        
        VFSGroup group;
        group.gid = gid;
        group.name = record.recordName.UTF8String;
        group.gecos = gecos;
        _target.emplace_back( std::move(group) );
    }
    
    sort(begin(_target),
         end(_target),
         [](const auto &_1, const auto &_2){ return (signed)_1.gid < (signed)_2.gid; });
    _target.erase(unique(begin(_target),
                          end(_target),
                          [](const auto &_1, const auto &_2){ return _1.gid == _2.gid; }),
                  end(_target));
    
    return VFSError::Ok;
}

bool NativeHost::IsCaseSensitiveAtPath(const char *_dir) const
{
    if( !_dir || _dir[0] != '/' )
        return true;
    if( const auto fs_info = utility::NativeFSManager::Instance().VolumeFromMountPoint( _dir ) )
        return fs_info->format.case_sensitive;
    return true;
}
    
static uint32_t MergeUnixFlags( uint32_t _symlink_flags, uint32_t _target_flags ) noexcept
{
    const uint32_t hidden_flag = _symlink_flags & UF_HIDDEN;
    return _target_flags | hidden_flag;
}
    
}

