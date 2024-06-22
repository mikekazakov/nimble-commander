// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/PathManip.h>
#include "ListingInput.h"
#include "../include/VFS/Host.h"
#include <sys/param.h>
#include <queue>
#include <algorithm>
#include <numeric>
#include <filesystem>
#include <sys/dirent.h>
#include <sys/stat.h>

namespace nc::vfs {

HostDirObservationTicket::HostDirObservationTicket() noexcept : m_Ticket(0), m_Host()
{
}

HostDirObservationTicket::HostDirObservationTicket(unsigned long _ticket, std::weak_ptr<VFSHost> _host) noexcept
    : m_Ticket(_ticket), m_Host(_host)
{
    assert((_ticket == 0 && _host.expired()) || (_ticket != 0 && !_host.expired()));
}

HostDirObservationTicket::HostDirObservationTicket(HostDirObservationTicket &&_rhs) noexcept
    : m_Ticket(_rhs.m_Ticket), m_Host(std::move(_rhs.m_Host))
{
    _rhs.m_Ticket = 0;
}

HostDirObservationTicket::~HostDirObservationTicket()
{
    reset();
}

HostDirObservationTicket &HostDirObservationTicket::operator=(HostDirObservationTicket &&_rhs) noexcept
{
    reset();
    m_Ticket = _rhs.m_Ticket;
    m_Host = std::move(_rhs.m_Host);
    _rhs.m_Ticket = 0;
    return *this;
}

bool HostDirObservationTicket::valid() const noexcept
{
    return m_Ticket != 0;
}

HostDirObservationTicket::operator bool() const noexcept
{
    return valid();
}

void HostDirObservationTicket::reset()
{
    if( valid() ) {
        if( auto h = m_Host.lock() )
            h->StopDirChangeObserving(m_Ticket);
        m_Ticket = 0;
        m_Host.reset();
    }
}

FileObservationToken::FileObservationToken(unsigned long _token, std::weak_ptr<Host> _host) noexcept
    : m_Token(_token), m_Host{_host}
{
}

FileObservationToken::FileObservationToken(FileObservationToken &&_rhs) noexcept
    : m_Token{_rhs.m_Token}, m_Host{std::move(_rhs.m_Host)}
{
    _rhs.m_Token = 0;
    _rhs.m_Host.reset();
}

FileObservationToken::~FileObservationToken()
{
    reset();
}

FileObservationToken &FileObservationToken::operator=(FileObservationToken &&_rhs) noexcept
{
    reset();
    m_Token = _rhs.m_Token;
    m_Host = _rhs.m_Host;
    _rhs.m_Token = 0;
    _rhs.m_Host.reset();
    return *this;
}

FileObservationToken::operator bool() const noexcept
{
    return m_Token != 0 && m_Host.expired() == false;
}

void FileObservationToken::reset() noexcept
{
    if( *this ) {
        if( auto host = m_Host.lock() )
            host->StopObservingFileChanges(m_Token);
        m_Token = 0;
        m_Host.reset();
    }
}

const char *Host::UniqueTag = "nullfs";

class VFSHostConfiguration
{
public:
    const char *Tag() const { return Host::UniqueTag; }

    const char *Junction() const { return ""; }

    bool operator==(const VFSHostConfiguration &) const { return true; }
};

Host::Host(const char *_junction_path, const std::shared_ptr<Host> &_parent, const char *_fs_tag)
    : m_JunctionPath(_junction_path ? _junction_path : ""), m_Parent(_parent), m_Tag(_fs_tag), m_Features(0)
{
}

Host::~Host()
{
    if( m_OnDesctruct )
        m_OnDesctruct(this);
}

std::shared_ptr<VFSHost> Host::SharedPtr()
{
    return shared_from_this();
}

std::shared_ptr<const VFSHost> Host::SharedPtr() const
{
    return shared_from_this();
}

const char *Host::Tag() const noexcept
{
    return m_Tag;
}

const VFSHostPtr &Host::Parent() const noexcept
{
    return m_Parent;
}

const char *Host::JunctionPath() const noexcept
{
    return m_JunctionPath.c_str();
}

bool Host::IsWritable() const
{
    return false;
}

bool Host::IsWritableAtPath([[maybe_unused]] const char *_dir) const
{
    return IsWritable();
}

int Host::CreateFile([[maybe_unused]] const char *_path,
                     [[maybe_unused]] std::shared_ptr<VFSFile> &_target,
                     [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

bool Host::IsDirectory(const char *_path, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    VFSStat st;
    if( Stat(_path, st, _flags, _cancel_checker) < 0 )
        return false;

    return (st.mode & S_IFMT) == S_IFDIR;
}

bool Host::IsSymlink(const char *_path, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    VFSStat st;
    if( Stat(_path, st, _flags, _cancel_checker) < 0 )
        return false;

    return (st.mode & S_IFMT) == S_IFLNK;
}

bool Host::FindLastValidItem(const char *_orig_path,
                             char *_valid_path,
                             unsigned long _flags,
                             const VFSCancelChecker &_cancel_checker)
{
    // TODO: maybe it's better to go left-to-right than right-to-left
    if( _orig_path[0] != '/' )
        return false;

    char tmp[MAXPATHLEN * 8];
    strcpy(tmp, _orig_path);
    if( IsPathWithTrailingSlash(tmp) && strcmp(tmp, "/") != 0 )
        tmp[strlen(tmp) - 1] = 0; // cut trailing slash if any

    VFSStat st;
    while( true ) {
        if( _cancel_checker && _cancel_checker() )
            return false;

        int ret = Stat(tmp, st, _flags, _cancel_checker);
        if( ret == 0 ) {
            strcpy(_valid_path, tmp);
            return true;
        }

        char *sl = strrchr(tmp, '/');
        assert(sl != nullptr);
        if( sl == tmp )
            return false;
        *sl = 0;
    }

    return false;
}

ssize_t Host::CalculateDirectorySize(const char *_path, const VFSCancelChecker &_cancel_checker)
{
    if( _path == nullptr || _path[0] != '/' )
        return VFSError::InvalidCall;

    std::queue<std::filesystem::path> look_paths;
    int64_t total_size = 0;

    look_paths.emplace(_path);
    while( !look_paths.empty() ) {
        if( _cancel_checker && _cancel_checker() ) // check if we need to quit
            return VFSError::Cancelled;

        IterateDirectoryListing(look_paths.front().c_str(), [&](const VFSDirEnt &_dirent) {
            std::filesystem::path full_path = look_paths.front() / _dirent.name;
            if( _dirent.type == VFSDirEnt::Dir )
                look_paths.emplace(std::move(full_path));
            else {
                VFSStat stat;
                if( Stat(full_path.c_str(), stat, VFSFlags::F_NoFollow, nullptr) == 0 )
                    total_size += stat.size;
            }
            return true;
        });
        look_paths.pop();
    }

    return total_size;
}

bool Host::IsDirChangeObservingAvailable([[maybe_unused]] const char *_path)
{
    return false;
}

HostDirObservationTicket Host::DirChangeObserve([[maybe_unused]] const char *_path,
                                                [[maybe_unused]] std::function<void()> _handler)
{
    return {};
}

void Host::StopDirChangeObserving([[maybe_unused]] unsigned long _ticket)
{
}

FileObservationToken Host::ObserveFileChanges([[maybe_unused]] const char *_path,
                                              [[maybe_unused]] std::function<void()> _handler)
{
    return {};
}

void Host::StopObservingFileChanges([[maybe_unused]] unsigned long _token)
{
}

int Host::Stat([[maybe_unused]] const char *_path,
               [[maybe_unused]] VFSStat &_st,
               [[maybe_unused]] unsigned long _flags,
               [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::IterateDirectoryListing([[maybe_unused]] const char *_path,
                                  [[maybe_unused]] const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    // TODO: write a default implementation using listing fetching.
    // it will be less efficient, but for some FS like PS it will be ok
    return VFSError::NotSupported;
}

int Host::StatFS([[maybe_unused]] const char *_path,
                 [[maybe_unused]] VFSStatFS &_stat,
                 [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::Unlink([[maybe_unused]] const char *_path, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::Trash([[maybe_unused]] const char *_path, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::CreateDirectory([[maybe_unused]] const char *_path,
                          [[maybe_unused]] int _mode,
                          [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::ReadSymlink([[maybe_unused]] const char *_path,
                      [[maybe_unused]] char *_buffer,
                      [[maybe_unused]] size_t _buffer_size,
                      [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::CreateSymlink([[maybe_unused]] const char *_symlink_path,
                        [[maybe_unused]] const char *_symlink_value,
                        [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::SetTimes([[maybe_unused]] const char *_path,
                   [[maybe_unused]] std::optional<time_t> _birth_time,
                   [[maybe_unused]] std::optional<time_t> _mod_time,
                   [[maybe_unused]] std::optional<time_t> _chg_time,
                   [[maybe_unused]] std::optional<time_t> _acc_time,
                   [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

bool Host::ShouldProduceThumbnails() const
{
    return false;
}

int Host::RemoveDirectory([[maybe_unused]] const char *_path, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::Rename([[maybe_unused]] const char *_old_path,
                 [[maybe_unused]] const char *_new_path,
                 [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::SetPermissions([[maybe_unused]] const char *_path,
                         [[maybe_unused]] uint16_t _mode,
                         [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::GetXAttrs([[maybe_unused]] const char *_path,
                    [[maybe_unused]] std::vector<std::pair<std::string, std::vector<uint8_t>>> &_xattrs)
{
    return VFSError::NotSupported;
}

const std::shared_ptr<Host> &Host::DummyHost()
{
    [[clang::no_destroy]] static auto host = std::make_shared<Host>("", nullptr, Host::UniqueTag);
    return host;
}

VFSConfiguration Host::Configuration() const
{
    [[clang::no_destroy]] static auto config = VFSConfiguration(VFSHostConfiguration());
    return config;
}

bool Host::Exists(const char *_path, const VFSCancelChecker &_cancel_checker)
{
    VFSStat st;
    return Stat(_path, st, 0, _cancel_checker) == VFSError::Ok;
}

bool Host::IsImmutableFS() const noexcept
{
    return false;
}

bool Host::IsNativeFS() const noexcept
{
    return false;
}

bool Host::ValidateFilename(const char *_filename) const
{
    if( !_filename )
        return false;

    const auto max_filename_len = 256;
    const auto i = _filename, e = _filename + strlen(_filename);
    if( i == e || e - i > max_filename_len )
        return false;

    static const char invalid_chars[] = ":\\/\r\t\n";
    return std::find_first_of(i, e, std::begin(invalid_chars), std::end(invalid_chars)) == e;
}

int Host::FetchDirectoryListing([[maybe_unused]] const char *_path,
                                [[maybe_unused]] VFSListingPtr &_target,
                                [[maybe_unused]] unsigned long _flags,
                                [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::FetchSingleItemListing(const char *_path,
                                 VFSListingPtr &_target,
                                 [[maybe_unused]] unsigned long _flags,
                                 const VFSCancelChecker &_cancel_checker)
{
    // as we came here - there's no special implementation in derived class,
    // so need to try to emulate it with available methods.

    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;

    if( _cancel_checker && _cancel_checker() )
        return VFSError::Cancelled;

    char path[MAXPATHLEN], directory[MAXPATHLEN], filename[MAXPATHLEN];
    strcpy(path, _path);

    if( !EliminateTrailingSlashInPath(path) || !GetDirectoryContainingItemFromPath(path, directory) ||
        !GetFilenameFromPath(path, filename) )
        return VFSError::InvalidCall;

    VFSStat lstat;

    int ret = Stat(_path, lstat, VFSFlags::F_NoFollow);
    if( ret != 0 )
        return ret;

    using nc::base::variable_container;
    nc::vfs::ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = directory;
    listing_source.inodes.reset(variable_container<>::type::common);
    listing_source.atimes.reset(variable_container<>::type::common);
    listing_source.mtimes.reset(variable_container<>::type::common);
    listing_source.ctimes.reset(variable_container<>::type::common);
    listing_source.btimes.reset(variable_container<>::type::common);
    listing_source.add_times.reset(variable_container<>::type::common);
    listing_source.unix_flags.reset(variable_container<>::type::common);
    listing_source.uids.reset(variable_container<>::type::common);
    listing_source.gids.reset(variable_container<>::type::common);
    listing_source.sizes.reset(variable_container<>::type::common);
    listing_source.symlinks.reset(variable_container<>::type::sparse);
    listing_source.display_filenames.reset(variable_container<>::type::sparse);

    listing_source.unix_modes.resize(1);
    listing_source.unix_types.resize(1);
    listing_source.filenames.emplace_back(filename);

    listing_source.inodes[0] = lstat.inode;
    listing_source.unix_types[0] = IFTODT(lstat.mode);
    listing_source.atimes[0] = lstat.atime.tv_sec;
    listing_source.mtimes[0] = lstat.mtime.tv_sec;
    listing_source.ctimes[0] = lstat.ctime.tv_sec;
    listing_source.btimes[0] = lstat.btime.tv_sec;
    listing_source.unix_modes[0] = lstat.mode;
    listing_source.unix_flags[0] = lstat.flags;
    listing_source.uids[0] = lstat.uid;
    listing_source.gids[0] = lstat.gid;
    listing_source.sizes[0] = lstat.size;

    if( listing_source.unix_types[0] == DT_LNK ) {
        // read an actual link path
        char linkpath[MAXPATHLEN];
        if( ReadSymlink(path, linkpath, MAXPATHLEN) == 0 )
            listing_source.symlinks.insert(0, linkpath);

        // stat the target file
        VFSStat stat;
        if( Stat(_path, stat, 0) == 0 ) {
            listing_source.unix_modes[0] = stat.mode;
            listing_source.unix_flags[0] = stat.flags;
            listing_source.uids[0] = stat.uid;
            ;
            listing_source.gids[0] = stat.gid;
            listing_source.sizes[0] = stat.size;
        }
    }

    _target = VFSListing::Build(std::move(listing_source));

    return 0;
}

int Host::FetchFlexibleListingItems(const std::string &_directory_path,
                                    const std::vector<std::string> &_filenames,
                                    unsigned long _flags,
                                    std::vector<VFSListingItem> &_result,
                                    const VFSCancelChecker &_cancel_checker)
{
    VFSListingPtr listing;
    int ret = FetchDirectoryListing(_directory_path.c_str(), listing, _flags, _cancel_checker);
    if( ret != 0 )
        return ret;

    _result.clear();
    _result.reserve(_filenames.size());

    // O(n) implementation, can write as O(logn) with indirection indeces map
    for( unsigned i = 0, e = listing->Count(); i != e; ++i )
        for( auto &filename : _filenames )
            if( listing->Filename(i) == filename )
                _result.emplace_back(listing->Item(i));

    return 0;
}

void Host::SetDesctructCallback(std::function<void(const VFSHost *)> _callback)
{
    m_OnDesctruct = _callback;
}

int Host::SetOwnership([[maybe_unused]] const char *_path,
                       [[maybe_unused]] unsigned _uid,
                       [[maybe_unused]] unsigned _gid,
                       [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::FetchUsers([[maybe_unused]] std::vector<VFSUser> &_target,
                     [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::FetchGroups([[maybe_unused]] std::vector<VFSGroup> &_target,
                      [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::SetFlags([[maybe_unused]] const char *_path,
                   [[maybe_unused]] uint32_t _flags,
                   [[maybe_unused]] uint64_t _vfs_options,
                   [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

void Host::SetFeatures(uint64_t _features_bitset)
{
    m_Features = _features_bitset;
}

void Host::AddFeatures(uint64_t _features_bitset)
{
    SetFeatures(Features() | _features_bitset);
}

uint64_t Host::Features() const noexcept
{
    return m_Features;
}

uint64_t Host::FullHashForPath(const char *_path) const noexcept
{
    if( !_path )
        return 0;

    const auto max_hosts = 8;
    std::array<const VFSHost *, max_hosts> hosts;
    int hosts_n = 0;

    auto cur = this;
    while( cur && hosts_n < max_hosts ) {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }

    const auto buf_sz = 4096;
    char buf[buf_sz];
    char *p = &buf[0];

    while( hosts_n > 0 ) {
        const auto host = hosts[--hosts_n];
        p = stpcpy(p, host->Tag());
        p = stpcpy(p, "|");
        p = stpcpy(p, host->JunctionPath());
        p = stpcpy(p, "|");
    }
    p = stpcpy(p, _path);

    return std::hash<std::string_view>()(std::string_view(&buf[0], p - &buf[0]));
}

std::string Host::MakePathVerbose(std::string_view _path) const
{
    constexpr size_t max_depth = 64;
    std::array<std::string_view, max_depth> strings;
    size_t strings_n = 0;
    strings[strings_n++] = _path;

    auto current_host = this;
    while( current_host ) {
        const auto cfg = current_host->Configuration();
        const auto junction = std::string_view(cfg.VerboseJunction());
        if( strings_n == max_depth )
            return {}; // abuse?
        strings[strings_n++] = junction;
        current_host = current_host->Parent().get();
    }

    // make one and only one memory allocation
    const size_t total_len = std::accumulate(
        &strings[0], &strings[0] + strings_n, size_t(0), [](auto sum, auto string) { return sum + string.length(); });
    std::string verbose_path;
    verbose_path.reserve(total_len);
    for( size_t index = strings_n - 1; index < strings_n; --index )
        verbose_path += strings[index];

    return verbose_path;
}

bool Host::IsCaseSensitiveAtPath([[maybe_unused]] const char *_dir) const
{
    return true;
}

} // namespace nc::vfs
