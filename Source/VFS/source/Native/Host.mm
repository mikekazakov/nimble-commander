// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Host.h"
#include <OpenDirectory/OpenDirectory.h>
#include <sys/attr.h>
#include <sys/errno.h>
#include <sys/vnode.h>
#include <sys/stat.h>
#include <Base/algo.h>
#include <Utility/PathManip.h>
#include <Utility/FSEventsDirUpdate.h>
#include <Utility/FSEventsFileUpdate.h>
#include <Utility/NativeFSManager.h>
#include <RoutedIO/RoutedIO.h>
#include "DisplayNamesCache.h"
#include "File.h"
#include <VFS/VFSError.h>
#include <VFS/Log.h>
#include "../ListingInput.h"
#include "Fetching.h"
#include <Base/DispatchGroup.h>
#include <Base/StackAllocator.h>
#include <Utility/ObjCpp.h>
#include <Utility/Tags.h>
#include <sys/mount.h>

#include <fmt/ranges.h>
#include <algorithm>

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent *_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

namespace nc::vfs {

static uint32_t MergeUnixFlags(uint32_t _symlink_flags, uint32_t _target_flags) noexcept;

using namespace native;

const char *NativeHost::UniqueTag = "native";

class VFSNativeHostConfiguration
{
public:
    [[nodiscard]] static const char *Tag() { return VFSNativeHost::UniqueTag; }

    [[nodiscard]] static const char *Junction() { return ""; }

    bool operator==(const VFSNativeHostConfiguration & /*unused*/) const { return true; }
};

VFSMeta NativeHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = []([[maybe_unused]] const VFSHostPtr &_parent,
                           [[maybe_unused]] const VFSConfiguration &_config,
                           [[maybe_unused]] VFSCancelChecker _cancel_checker) {
        assert(0); // unimplementable without external knoweledge
        return nullptr;
    };
    return m;
}

NativeHost::NativeHost(nc::utility::NativeFSManager &_native_fs_man,
                       nc::utility::FSEventsFileUpdate &_fsevents_file_update)
    : Host("", nullptr, UniqueTag), m_NativeFSManager(_native_fs_man), m_FSEventsFileUpdate(_fsevents_file_update)
{
    AddFeatures(HostFeatures::FetchUsers | HostFeatures::FetchGroups | HostFeatures::SetOwnership |
                HostFeatures::SetFlags | HostFeatures::SetPermissions | HostFeatures::SetTimes);
}

bool NativeHost::ShouldProduceThumbnails() const
{
    return true;
}

std::expected<VFSListingPtr, Error> NativeHost::FetchDirectoryListing(std::string_view _path,
                                                                      const unsigned long _flags,
                                                                      const VFSCancelChecker &_cancel_checker)
{
    if( !_path.starts_with("/") )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);

    const auto need_to_add_dot_dot = !(_flags & VFSFlags::F_NoDotDot) && _path != "/";
    auto &io = routedio::RoutedIO::InterfaceForAccess(path.c_str(), R_OK);
    const bool is_native_io = !io.isrouted();
    const int fd = io.open(path.c_str(), O_RDONLY | O_NONBLOCK | O_DIRECTORY | O_CLOEXEC);
    if( fd < 0 )
        return std::unexpected(Error{Error::POSIX, errno});
    auto close_fd = at_scope_end([fd] { close(fd); });

    using nc::base::variable_container;
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(std::string(_path));
    listing_source.inodes.reset(variable_container<>::type::dense);
    listing_source.atimes.reset(variable_container<>::type::dense);
    listing_source.mtimes.reset(variable_container<>::type::dense);
    listing_source.ctimes.reset(variable_container<>::type::dense);
    listing_source.btimes.reset(variable_container<>::type::dense);
    listing_source.add_times.reset(variable_container<>::type::sparse);
    listing_source.unix_flags.reset(variable_container<>::type::dense);
    listing_source.uids.reset(variable_container<>::type::dense);
    listing_source.gids.reset(variable_container<>::type::dense);
    listing_source.sizes.reset(variable_container<>::type::dense);
    listing_source.symlinks.reset(variable_container<>::type::sparse);
    listing_source.display_filenames.reset(variable_container<>::type::sparse);

    std::vector<uint64_t> ext_flags; // store EF_xxx here
    constexpr size_t initial_prealloc_size = 64;
    size_t allocated_size = 0;
    auto resize_dense = [&](size_t _sz) {
        listing_source.filenames.resize(_sz);
        listing_source.inodes.resize(_sz);
        listing_source.unix_types.resize(_sz);
        listing_source.atimes.resize(_sz);
        listing_source.mtimes.resize(_sz);
        listing_source.ctimes.resize(_sz);
        listing_source.btimes.resize(_sz);
        listing_source.unix_modes.resize(_sz);
        listing_source.unix_flags.resize(_sz);
        listing_source.uids.resize(_sz);
        listing_source.gids.resize(_sz);
        listing_source.sizes.resize(_sz);
        ext_flags.resize(_sz);
        allocated_size = _sz;
    };

    // allocate space for up to 64 items upfront
    resize_dense(initial_prealloc_size);

    auto fill = [&](size_t _n, const Fetching::CallbackParams &_params) {
        assert(_n < listing_source.filenames.size());
        listing_source.filenames[_n] = _params.filename;
        listing_source.inodes[_n] = _params.inode;
        listing_source.unix_types[_n] = IFTODT(_params.mode);
        listing_source.atimes[_n] = _params.acc_time;
        listing_source.mtimes[_n] = _params.mod_time;
        listing_source.ctimes[_n] = _params.chg_time;
        listing_source.btimes[_n] = _params.crt_time;
        listing_source.unix_modes[_n] = _params.mode;
        listing_source.unix_flags[_n] = _params.flags;
        listing_source.uids[_n] = _params.uid;
        listing_source.gids[_n] = _params.gid;
        listing_source.sizes[_n] = _params.size;
        if( _params.add_time >= 0 )
            listing_source.add_times.insert(_n, _params.add_time);

        if( _flags & VFSFlags::F_LoadDisplayNames )
            if( S_ISDIR(listing_source.unix_modes[_n]) && !listing_source.filenames[_n].empty() &&
                listing_source.filenames[_n] != ".." ) {
                static auto &dnc = DisplayNamesCache::Instance();
                if( auto display_name = dnc.DisplayName(
                        _params.inode, _params.dev, listing_source.directories[0] + listing_source.filenames[_n]) )
                    listing_source.display_filenames.insert(_n, std::string(*display_name));
            }

        ext_flags[_n] = _params.ext_flags;
    };

    size_t next_entry_index = 0;
    auto cb_param = [&](const Fetching::CallbackParams &_params) { fill(next_entry_index++, _params); };

    if( need_to_add_dot_dot ) {
        Fetching::ReadSingleEntryAttributesByPath(io, path, cb_param);
        listing_source.filenames[0] = "..";
    }

    auto cb_fetch = [&](size_t _fetched_now) {
        // check if final entries count is more than previous approximate
        if( next_entry_index + _fetched_now > allocated_size )
            resize_dense(next_entry_index + _fetched_now);
    };

    // when Admin Mode is on - we use different fetch route
    const int ret =
        is_native_io ? Fetching::ReadDirAttributesBulk(fd, cb_fetch, cb_param)
                     : Fetching::ReadDirAttributesStat(fd, listing_source.directories[0].c_str(), cb_fetch, cb_param);
    if( ret != 0 )
        return std::unexpected(Error{Error::POSIX, ret});

    if( _cancel_checker && _cancel_checker() )
        return std::unexpected(Error{Error::POSIX, ECANCELED});

    // check if final entries count is less than approximate
    if( next_entry_index < allocated_size )
        resize_dense(next_entry_index);

    // a little more work with symlinks, if there are any
    for( size_t n = 0; n < next_entry_index; ++n )
        if( listing_source.unix_types[n] == DT_LNK ) {
            // read an actual link path
            char linkpath[MAXPATHLEN];
            const ssize_t sz = is_native_io
                                   ? readlinkat(fd, listing_source.filenames[n].c_str(), linkpath, MAXPATHLEN)
                                   : io.readlink((listing_source.directories[0] + listing_source.filenames[n]).c_str(),
                                                 linkpath,
                                                 MAXPATHLEN);
            if( sz != -1 ) {
                linkpath[sz] = 0;
                listing_source.symlinks.insert(n, linkpath);
            }

            // stat the target file
            struct ::stat stat_buffer;
            const auto stat_ret =
                is_native_io
                    ? fstatat(fd, listing_source.filenames[n].c_str(), &stat_buffer, 0)
                    : io.stat((listing_source.directories[0] + listing_source.filenames[n]).c_str(), &stat_buffer);
            if( stat_ret == 0 ) {
                listing_source.unix_modes[n] = stat_buffer.st_mode;
                listing_source.unix_flags[n] = MergeUnixFlags(listing_source.unix_flags[n], stat_buffer.st_flags);
                listing_source.uids[n] = stat_buffer.st_uid;
                listing_source.gids[n] = stat_buffer.st_gid;
                listing_source.sizes[n] = S_ISDIR(stat_buffer.st_mode) ? -1 : stat_buffer.st_size;
            }
        }

    // Fetch FinderTags if they were requested AND if an entry doesn't have an EF_NO_XATTRS flag (to do less unnecessary
    // syscalls).
    if( _flags & Flags::F_LoadTags ) {
        for( size_t n = 0; n < next_entry_index; ++n ) {
            if( ext_flags[n] & EF_NO_XATTRS )
                continue; // tags are stored in xattrs and if we no in advance that there are no xattrs in this entry -
                          // there's no point trying

            // TODO: is it worth routing the I/O here? guess not atm
            const std::string &filename = listing_source.filenames[n];
            const int entry_fd = openat(fd, filename.c_str(), O_RDONLY | O_NONBLOCK);
            if( entry_fd < 0 )
                continue; // guess silenty skipping the errors is ok here...
            auto close_entry_fd = at_scope_end([entry_fd] { close(entry_fd); });

            if( auto tags = utility::Tags::ReadTags(entry_fd); !tags.empty() ) {
                Log::Debug("Extracted the tags of the file '{}': {}", filename, fmt::join(tags, ", "));
                listing_source.tags.emplace(n, std::move(tags));
            }
        }
    }

    return VFSListing::Build(std::move(listing_source));
}

std::expected<VFSListingPtr, Error> NativeHost::FetchSingleItemListing(std::string_view _path,
                                                                       unsigned long _flags,
                                                                       const VFSCancelChecker &_cancel_checker)
{
    if( !_path.starts_with("/") )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    std::array<char, 512> mem_buffer;
    std::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());
    const std::pmr::string path(utility::PathManip::WithoutTrailingSlashes(_path), &mem_resource);
    if( path.empty() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::string_view directory = utility::PathManip::Parent(path);
    if( directory.empty() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::string_view filename = utility::PathManip::Filename(path);
    if( filename.empty() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    if( _cancel_checker && _cancel_checker() )
        return std::unexpected(nc::Error{nc::Error::POSIX, ECANCELED});

    auto &io = routedio::RoutedIO::InterfaceForAccess(path.c_str(), R_OK);

    using nc::base::variable_container;
    uint64_t ext_flags = 0;
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = directory;
    listing_source.inodes.reset(variable_container<>::type::common);
    listing_source.atimes.reset(variable_container<>::type::common);
    listing_source.mtimes.reset(variable_container<>::type::common);
    listing_source.ctimes.reset(variable_container<>::type::common);
    listing_source.btimes.reset(variable_container<>::type::common);
    listing_source.add_times.reset(variable_container<>::type::sparse);
    listing_source.unix_flags.reset(variable_container<>::type::common);
    listing_source.uids.reset(variable_container<>::type::common);
    listing_source.gids.reset(variable_container<>::type::common);
    listing_source.sizes.reset(variable_container<>::type::common);
    listing_source.symlinks.reset(variable_container<>::type::sparse);
    listing_source.display_filenames.reset(variable_container<>::type::sparse);

    listing_source.unix_modes.resize(1);
    listing_source.unix_types.resize(1);
    listing_source.filenames.emplace_back(filename);

    auto cb_param = [&](const Fetching::CallbackParams &_params) {
        listing_source.inodes[0] = _params.inode;
        listing_source.unix_types[0] = IFTODT(_params.mode);
        listing_source.atimes[0] = _params.acc_time;
        listing_source.mtimes[0] = _params.mod_time;
        listing_source.ctimes[0] = _params.chg_time;
        listing_source.btimes[0] = _params.crt_time;
        listing_source.unix_modes[0] = _params.mode;
        listing_source.unix_flags[0] = _params.flags;
        listing_source.uids[0] = _params.uid;
        listing_source.gids[0] = _params.gid;
        listing_source.sizes[0] = _params.size;
        if( _params.add_time >= 0 )
            listing_source.add_times.insert(0, _params.add_time);

        if( _flags & VFSFlags::F_LoadDisplayNames )
            if( S_ISDIR(listing_source.unix_modes[0]) && !listing_source.filenames[0].empty() &&
                listing_source.filenames[0] != ".." ) {
                static auto &dnc = DisplayNamesCache::Instance();
                if( std::optional<std::string_view> display_name = dnc.DisplayName(_params.inode, _params.dev, path) )
                    listing_source.display_filenames.insert(0, std::string(*display_name));
            }

        ext_flags = _params.ext_flags;
    };

    const int ret = Fetching::ReadSingleEntryAttributesByPath(io, _path, cb_param);
    if( ret != 0 )
        return std::unexpected(Error{Error::POSIX, ret});

    // a little more work with symlink, if any
    if( listing_source.unix_types[0] == DT_LNK ) {
        // read an actual link path
        char linkpath[MAXPATHLEN];
        const ssize_t sz = io.readlink(path.c_str(), linkpath, MAXPATHLEN);
        if( sz != -1 ) {
            linkpath[sz] = 0;
            listing_source.symlinks.insert(0, linkpath);
        }

        // stat the target file
        struct stat stat_buffer;
        const auto stat_ret = io.stat(path.c_str(), &stat_buffer);
        if( stat_ret == 0 ) {
            listing_source.unix_modes[0] = stat_buffer.st_mode;
            listing_source.unix_flags[0] = MergeUnixFlags(listing_source.unix_flags[0], stat_buffer.st_flags);
            listing_source.uids[0] = stat_buffer.st_uid;
            listing_source.gids[0] = stat_buffer.st_gid;
            listing_source.sizes[0] = stat_buffer.st_size;
        }
    }

    // Fetch FinderTags if they were requested AND if an entry doesn't have an EF_NO_XATTRS flag (to do less unnecessary
    // syscalls).
    if( (_flags & Flags::F_LoadTags) && !(ext_flags & EF_NO_XATTRS) ) {
        // TODO: is it worth routing the I/O here? guess not atm
        const int entry_fd = open(path.c_str(), O_RDONLY | O_NONBLOCK);
        if( entry_fd >= 0 ) {
            auto close_entry_fd = at_scope_end([entry_fd] { close(entry_fd); });
            if( auto tags = utility::Tags::ReadTags(entry_fd); !tags.empty() )
                listing_source.tags.emplace(0, std::move(tags));
        }
    }

    return VFSListing::Build(std::move(listing_source));
}

std::expected<std::shared_ptr<VFSFile>, Error> NativeHost::CreateFile(std::string_view _path,
                                                                      const VFSCancelChecker &_cancel_checker)
{
    auto file = std::make_shared<File>(_path, SharedPtr());
    if( _cancel_checker && _cancel_checker() )
        return std::unexpected(Error{Error::POSIX, ECANCELED});
    return file;
}

static std::expected<void, Error> CalculateDirectoriesSizesHelper(char *_path,
                                                                  size_t _path_len,
                                                                  std::atomic_bool &_iscancelling,
                                                                  const VFSCancelChecker &_checker,
                                                                  dispatch_queue &_stat_queue,
                                                                  std::atomic_uint64_t &_size_stock)
{
    if( _checker && _checker() ) {
        _iscancelling = true;
        return std::unexpected(nc::Error{nc::Error::POSIX, ECANCELED});
    }

    auto &io = routedio::RoutedIO::InterfaceForAccess(_path, R_OK); // <-- sync IO operation

    const auto dirp = io.opendir(_path); // <-- sync IO operation
    if( dirp == nullptr )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});

    _path[_path_len] = '/';
    _path[_path_len + 1] = 0;
    char *var = _path + _path_len + 1;

    dirent *entp = nullptr;
    while( (entp = io.readdir(dirp)) != nullptr ) { // <-- sync IO operation
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

        memcpy(var, entp->d_name, entp->d_namlen + 1);
        if( entp->d_type == DT_DIR ) {
            std::ignore = CalculateDirectoriesSizesHelper(
                _path, _path_len + entp->d_namlen + 1, _iscancelling, _checker, _stat_queue, _size_stock);
            if( _iscancelling )
                goto cleanup;
        }
        else if( entp->d_type == DT_REG || entp->d_type == DT_LNK ) {
            std::string full_path = _path;
            _stat_queue.async([&, full_path = std::move(full_path)] {
                if( _iscancelling )
                    return;

                struct stat st;
                if( io.lstat(full_path.c_str(), &st) == 0 ) // <-- sync IO operation
                    _size_stock += st.st_size;
            });
        }
        else if( entp->d_type == DT_UNKNOWN ) {
            // some filesystems (e.g. ftp) might provide DT_UNKNOWN via readdir, so
            // need to check them via lstat() before doing further processing
            struct stat st;
            if( io.lstat(_path, &st) == 0 ) { // <-- sync IO operation
                if( S_ISDIR(st.st_mode) ) {
                    std::ignore = CalculateDirectoriesSizesHelper(
                        _path, _path_len + entp->d_namlen + 1, _iscancelling, _checker, _stat_queue, _size_stock);
                    if( _iscancelling )
                        goto cleanup;
                }
                else if( S_ISREG(st.st_mode) || S_ISLNK(st.st_mode) ) {
                    _size_stock += st.st_size;
                }
            }
        }
    }

cleanup:
    io.closedir(dirp); // <-- sync IO operation
    _path[_path_len] = 0;
    return {};
}

std::expected<uint64_t, Error> NativeHost::CalculateDirectorySize(std::string_view _path,
                                                                  const VFSCancelChecker &_cancel_checker)
{
    if( _cancel_checker && _cancel_checker() )
        return std::unexpected(nc::Error{nc::Error::POSIX, ECANCELED});

    if( !_path.starts_with("/") )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    std::atomic_bool iscancelling{false};

    // TODO: rewrite without using C-style shenanigans
    char path[MAXPATHLEN];
    memcpy(path, _path.data(), _path.length());
    path[_path.length()] = 0;

    dispatch_queue stat_queue("VFSNativeHost.CalculateDirectoriesSizes");

    std::atomic_uint64_t size{0};
    const std::expected<void, Error> result =
        CalculateDirectoriesSizesHelper(path, strlen(path), iscancelling, _cancel_checker, stat_queue, size);
    stat_queue.sync([] {});
    if( !result )
        return std::unexpected(result.error());

    return size.load();
}

bool NativeHost::IsDirectoryChangeObservationAvailable(std::string_view _path)
{
    if( _path.empty() )
        return false;

    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);
    return access(path.c_str(), R_OK) == 0; // should use _not_ routed I/O here!
}

HostDirObservationTicket NativeHost::ObserveDirectoryChanges(std::string_view _path, std::function<void()> _handler)
{
    auto &inst = nc::utility::FSEventsDirUpdate::Instance();
    const uint64_t t = inst.AddWatchPath(_path, std::move(_handler));
    return t ? HostDirObservationTicket(t, shared_from_this()) : HostDirObservationTicket();
}

void NativeHost::StopDirChangeObserving(unsigned long _ticket)
{
    auto &inst = nc::utility::FSEventsDirUpdate::Instance();
    inst.RemoveWatchPathWithTicket(_ticket);
}

FileObservationToken NativeHost::ObserveFileChanges(const std::string_view _path, std::function<void()> _handler)
{
    const auto token = m_FSEventsFileUpdate.AddWatchPath(_path, std::move(_handler));
    return {token, SharedPtr()};
}

void NativeHost::StopObservingFileChanges(unsigned long _token)
{
    assert(_token != utility::FSEventsFileUpdate::empty_token);
    m_FSEventsFileUpdate.RemoveWatchPathWithToken(_token);
}

std::expected<VFSStat, Error>
NativeHost::Stat(std::string_view _path, unsigned long _flags, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);

    auto &io = routedio::RoutedIO::InterfaceForAccess(path.c_str(), R_OK);

    struct stat st;
    const int ret = (_flags & VFSFlags::F_NoFollow) ? io.lstat(path.c_str(), &st) : io.stat(path.c_str(), &st);
    if( ret != 0 ) {
        return std::unexpected(Error{Error::POSIX, errno});
    }

    VFSStat vfs_stat;
    VFSStat::FromSysStat(st, vfs_stat);
    return vfs_stat;
}

std::expected<void, Error>
NativeHost::IterateDirectoryListing(std::string_view _path,
                                    const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);

    auto &io = routedio::RoutedIO::InterfaceForAccess(path.c_str(), R_OK);

    DIR *dirp = io.opendir(path.c_str());
    if( dirp == nullptr )
        return std::unexpected(Error{Error::POSIX, errno});
    const auto close_dirp = at_scope_end([&] { io.closedir(dirp); });

    dirent *entp;
    VFSDirEnt vfs_dirent;
    while( (entp = io.readdir(dirp)) != nullptr ) {
        if( (entp->d_namlen == 1 && entp->d_name[0] == '.') ||
            (entp->d_namlen == 2 && entp->d_name[0] == '.' && entp->d_name[1] == '.') )
            continue;

        vfs_dirent.type = entp->d_type;
        vfs_dirent.name_len = entp->d_namlen;
        memcpy(vfs_dirent.name, entp->d_name, entp->d_namlen + 1);

        if( !_handler(vfs_dirent) )
            break;
    }

    return {};
}

std::expected<VFSStatFS, Error> NativeHost::StatFS(std::string_view _path,
                                                   [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);

    struct statfs info;
    if( statfs(path.c_str(), &info) < 0 )
        return std::unexpected(Error{Error::POSIX, errno});

    auto volume = m_NativeFSManager.VolumeFromMountPoint(info.f_mntonname);
    if( !volume )
        return std::unexpected(Error{Error::POSIX, ENOENT});

    m_NativeFSManager.UpdateSpaceInformation(volume);

    VFSStatFS stat;
    stat.volume_name = volume->verbose.name.UTF8String;
    stat.total_bytes = volume->basic.total_bytes;
    stat.free_bytes = volume->basic.free_bytes;
    stat.avail_bytes = volume->basic.available_bytes;
    return stat;
}

std::expected<void, Error> NativeHost::Unlink(std::string_view _path,
                                              [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);
    auto &io = routedio::RoutedIO::Default;

    if( io.unlink(path.c_str()) != 0 )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});

    return {};
}

bool NativeHost::IsWritable() const
{
    return true; // dummy now
}

std::expected<void, Error>
NativeHost::CreateDirectory(std::string_view _path, int _mode, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);
    auto &io = routedio::RoutedIO::Default;
    const int ret = io.mkdir(path.c_str(), mode_t(_mode));
    if( ret == 0 )
        return {};

    return std::unexpected(nc::Error{nc::Error::POSIX, errno});
}

std::expected<void, Error> NativeHost::RemoveDirectory(std::string_view _path,
                                                       [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);
    auto &io = routedio::RoutedIO::Default;
    const int ret = io.rmdir(path.c_str());
    if( ret == 0 )
        return {};

    return std::unexpected(nc::Error{nc::Error::POSIX, errno});
}

std::expected<std::string, Error> NativeHost::ReadSymlink(std::string_view _path,
                                                          [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);

    auto &io = routedio::RoutedIO::Default;
    char buffer[8192];
    const ssize_t sz = io.readlink(path.c_str(), buffer, sizeof(buffer));
    if( sz < 0 )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});

    if( sz >= static_cast<long>(sizeof(buffer)) )
        return std::unexpected(nc::Error{nc::Error::POSIX, ENOMEM});

    return std::string(buffer, sz);
}

std::expected<void, Error> NativeHost::CreateSymlink(std::string_view _symlink_path,
                                                     std::string_view _symlink_value,
                                                     [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    StackAllocator alloc;
    const std::pmr::string symlink_path(_symlink_path, &alloc);
    const std::pmr::string symlink_value(_symlink_value, &alloc);

    auto &io = routedio::RoutedIO::Default;
    const int result = io.symlink(symlink_value.c_str(), symlink_path.c_str());
    if( result != 0 )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});

    return {};
}

std::expected<void, Error> NativeHost::SetTimes(const std::string_view _path,
                                                const std::optional<time_t> _birth_time,
                                                const std::optional<time_t> _mod_time,
                                                const std::optional<time_t> _chg_time,
                                                const std::optional<time_t> _acc_time,
                                                [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path.empty() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    if( !_birth_time && !_mod_time && !_chg_time && !_acc_time )
        return {};

    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);

    auto &io = routedio::RoutedIO::Default;
    if( _birth_time && io.chbtime(path.c_str(), *_birth_time) != 0 )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});
    if( _mod_time && io.chmtime(path.c_str(), *_mod_time) != 0 )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});
    if( _chg_time && io.chctime(path.c_str(), *_chg_time) != 0 )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});
    if( _acc_time && io.chatime(path.c_str(), *_acc_time) != 0 )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});

    return {};
}

std::expected<void, Error> NativeHost::Rename(std::string_view _old_path,
                                              std::string_view _new_path,
                                              [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    StackAllocator alloc;
    const std::pmr::string old_path(_old_path, &alloc);
    const std::pmr::string new_path(_new_path, &alloc);

    auto &io = routedio::RoutedIO::Default;
    const int ret = io.rename(old_path.c_str(), new_path.c_str());
    if( ret == 0 )
        return {};

    return std::unexpected(nc::Error{nc::Error::POSIX, errno});
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

std::expected<void, nc::Error> NativeHost::Trash(std::string_view _path,
                                                 [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path.empty() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);

    auto &io = routedio::RoutedIO::Default;
    const auto ret = io.trash(path.c_str());
    if( ret != 0 )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});

    return {};
}

std::expected<void, Error> NativeHost::SetPermissions(std::string_view _path,
                                                      uint16_t _mode,
                                                      [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path.empty() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);

    auto &io = routedio::RoutedIO::Default;
    const auto ret = io.chmod(path.c_str(), _mode);
    if( ret != 0 )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});

    return {};
}

std::expected<void, Error> NativeHost::SetFlags(std::string_view _path,
                                                uint32_t _flags,
                                                uint64_t _vfs_options,
                                                [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path.empty() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);

    auto &io = routedio::RoutedIO::Default;
    const bool no_follow = _vfs_options & Flags::F_NoFollow;
    const auto ret = no_follow ? io.lchflags(path.c_str(), _flags) : io.chflags(path.c_str(), _flags);
    if( ret != 0 )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});

    return {};
}

std::expected<void, Error> NativeHost::SetOwnership(std::string_view _path,
                                                    unsigned _uid,
                                                    unsigned _gid,
                                                    [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path.empty() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    StackAllocator alloc;
    const std::pmr::string path(_path, &alloc);

    auto &io = routedio::RoutedIO::Default;
    const auto ret = io.chown(path.c_str(), _uid, _gid);
    if( ret != 0 )
        return std::unexpected(nc::Error{nc::Error::POSIX, errno});

    return {};
}

std::expected<std::vector<VFSUser>, Error>
NativeHost::FetchUsers([[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    NSError *error;
    const auto node_name = @"/Local/Default";
    const auto node = [ODNode nodeWithSession:ODSession.defaultSession name:node_name error:&error];
    if( !node )
        return std::unexpected(Error{error});

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
        return std::unexpected(Error{error});

    const auto records = [query resultsAllowingPartial:false error:&error];
    if( !records )
        return std::unexpected(Error{error});

    std::vector<VFSUser> users;
    for( ODRecord *record in records ) {
        const auto uid_values = [record valuesForAttribute:kODAttributeTypeUniqueID error:nil];
        if( uid_values == nil || uid_values.count == 0 )
            continue;
        const auto uid = static_cast<uint32_t>(objc_cast<NSString>(uid_values.firstObject).integerValue);

        const auto gecos_values = [record valuesForAttribute:kODAttributeTypeFullName error:nil];
        const auto gecos =
            (gecos_values && gecos_values.count > 0) ? objc_cast<NSString>(gecos_values.firstObject).UTF8String : "";

        VFSUser user;
        user.uid = uid;
        user.name = record.recordName.UTF8String;
        user.gecos = gecos;
        users.emplace_back(std::move(user));
    }

    std::ranges::sort(users, [](const auto &_1, const auto &_2) {
        return static_cast<signed>(_1.uid) < static_cast<signed>(_2.uid);
    });
    users.erase(std::ranges::unique(users, [](const auto &_1, const auto &_2) { return _1.uid == _2.uid; }).begin(),
                users.end());

    return std::move(users);
}

std::expected<std::vector<VFSGroup>, Error>
NativeHost::FetchGroups([[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    NSError *error;
    const auto node_name = @"/Local/Default";
    const auto node = [ODNode nodeWithSession:ODSession.defaultSession name:node_name error:&error];
    if( !node )
        return std::unexpected(Error{error});

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
        return std::unexpected(Error{error});

    const auto records = [query resultsAllowingPartial:false error:&error];
    if( !records )
        return std::unexpected(Error{error});

    std::vector<VFSGroup> groups;
    for( ODRecord *record in records ) {
        const auto gid_values = [record valuesForAttribute:kODAttributeTypePrimaryGroupID error:nil];
        if( gid_values == nil || gid_values.count == 0 )
            continue;
        const auto gid = static_cast<uint32_t>(objc_cast<NSString>(gid_values.firstObject).integerValue);

        const auto gecos_values = [record valuesForAttribute:kODAttributeTypeFullName error:nil];
        const auto gecos =
            (gecos_values && gecos_values.count > 0) ? objc_cast<NSString>(gecos_values.firstObject).UTF8String : "";

        VFSGroup group;
        group.gid = gid;
        group.name = record.recordName.UTF8String;
        group.gecos = gecos;
        groups.emplace_back(std::move(group));
    }

    std::ranges::sort(groups, [](const auto &_1, const auto &_2) {
        return static_cast<signed>(_1.gid) < static_cast<signed>(_2.gid);
    });
    groups.erase(std::ranges::unique(groups, [](const auto &_1, const auto &_2) { return _1.gid == _2.gid; }).begin(),
                 groups.end());

    return std::move(groups);
}

bool NativeHost::IsCaseSensitiveAtPath(std::string_view _dir) const
{
    if( _dir.empty() || _dir[0] != '/' )
        return true;
    if( const auto fs_info = m_NativeFSManager.VolumeFromPath(_dir) )
        return fs_info->format.case_sensitive;
    return true;
}

nc::utility::NativeFSManager &NativeHost::NativeFSManager() const noexcept
{
    return m_NativeFSManager;
}

static uint32_t MergeUnixFlags(uint32_t _symlink_flags, uint32_t _target_flags) noexcept
{
    const uint32_t hidden_flag = _symlink_flags & UF_HIDDEN;
    return _target_flags | hidden_flag;
}

} // namespace nc::vfs
