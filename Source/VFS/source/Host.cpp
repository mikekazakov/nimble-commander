// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/PathManip.h>
#include <Base/StackAllocator.h>
#include "ListingInput.h"
#include "../include/VFS/Host.h"
#include <sys/param.h>
#include <queue>
#include <algorithm>
#include <numeric>
#include <filesystem>
#include <sys/dirent.h>
#include <sys/stat.h>
#include <fmt/format.h>

namespace nc::vfs {

HostDirObservationTicket::HostDirObservationTicket() noexcept : m_Ticket(0)
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
    return m_Token != 0 && !m_Host.expired();
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
    [[nodiscard]] static const char *Tag() { return Host::UniqueTag; }

    [[nodiscard]] static const char *Junction() { return ""; }

    bool operator==(const VFSHostConfiguration & /*unused*/) const { return true; }
};

Host::Host(const std::string_view _junction_path, const std::shared_ptr<Host> &_parent, const char *_fs_tag)
    : m_JunctionPath(_junction_path), m_Parent(_parent), m_Tag(_fs_tag), m_Features(0)
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

std::string_view Host::JunctionPath() const noexcept
{
    return m_JunctionPath;
}

bool Host::IsWritable() const
{
    return false;
}

bool Host::IsWritableAtPath([[maybe_unused]] std::string_view _dir) const
{
    return IsWritable();
}

std::expected<std::shared_ptr<VFSFile>, Error>
Host::CreateFile([[maybe_unused]] std::string_view _path, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

bool Host::IsDirectory(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    const std::expected<VFSStat, Error> st = Stat(_path, _flags, _cancel_checker);
    return st && (st->mode & S_IFMT) == S_IFDIR;
}

bool Host::IsSymlink(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    const std::expected<VFSStat, Error> st = Stat(_path, _flags, _cancel_checker);
    return st && (st->mode & S_IFMT) == S_IFLNK;
}

std::expected<uint64_t, Error> Host::CalculateDirectorySize(std::string_view _path,
                                                            const VFSCancelChecker &_cancel_checker)
{
    if( !_path.starts_with("/") )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    std::queue<std::filesystem::path> look_paths;
    uint64_t total_size = 0;

    look_paths.emplace(_path);
    while( !look_paths.empty() ) {
        if( _cancel_checker && _cancel_checker() ) // check if we need to quit
            return std::unexpected(nc::Error{nc::Error::POSIX, ECANCELED});

        // Deliberately ignoring the potential errors
        std::ignore = IterateDirectoryListing(look_paths.front().native(), [&](const VFSDirEnt &_dirent) {
            std::filesystem::path full_path = look_paths.front() / _dirent.name;
            if( _dirent.type == VFSDirEnt::Dir )
                look_paths.emplace(std::move(full_path));
            else {
                if( const std::expected<VFSStat, Error> stat = Stat(full_path.native(), VFSFlags::F_NoFollow) )
                    total_size += stat->size;
            }
            return true;
        });
        look_paths.pop();
    }

    return total_size;
}

bool Host::IsDirectoryChangeObservationAvailable([[maybe_unused]] std::string_view _path)
{
    return false;
}

HostDirObservationTicket Host::ObserveDirectoryChanges([[maybe_unused]] std::string_view _path,
                                                       [[maybe_unused]] std::function<void()> _handler)
{
    return {};
}

void Host::StopDirChangeObserving([[maybe_unused]] unsigned long _ticket)
{
}

FileObservationToken Host::ObserveFileChanges([[maybe_unused]] std::string_view _path,
                                              [[maybe_unused]] std::function<void()> _handler)
{
    return {};
}

void Host::StopObservingFileChanges([[maybe_unused]] unsigned long _token)
{
}

std::expected<VFSStat, Error> Host::Stat([[maybe_unused]] std::string_view _path,
                                         [[maybe_unused]] unsigned long _flags,
                                         [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<void, Error>
Host::IterateDirectoryListing([[maybe_unused]] std::string_view _path,
                              [[maybe_unused]] const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    // TODO: write a default implementation using listing fetching.
    // it will be less efficient, but for some FS like PS it will be ok
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<VFSStatFS, Error> Host::StatFS([[maybe_unused]] std::string_view _path,
                                             [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<void, Error> Host::Unlink([[maybe_unused]] std::string_view _path,
                                        [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<void, nc::Error> Host::Trash([[maybe_unused]] std::string_view _path,
                                           [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<void, Error> Host::CreateDirectory([[maybe_unused]] std::string_view _path,
                                                 [[maybe_unused]] int _mode,
                                                 [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<std::string, Error> Host::ReadSymlink([[maybe_unused]] std::string_view _path,
                                                    [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<void, Error> Host::CreateSymlink([[maybe_unused]] std::string_view _symlink_path,
                                               [[maybe_unused]] std::string_view _symlink_value,
                                               [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<void, Error> Host::SetTimes([[maybe_unused]] std::string_view _path,
                                          [[maybe_unused]] std::optional<time_t> _birth_time,
                                          [[maybe_unused]] std::optional<time_t> _mod_time,
                                          [[maybe_unused]] std::optional<time_t> _chg_time,
                                          [[maybe_unused]] std::optional<time_t> _acc_time,
                                          [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

bool Host::ShouldProduceThumbnails() const
{
    return false;
}

std::expected<void, Error> Host::RemoveDirectory([[maybe_unused]] std::string_view _path,
                                                 [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<void, Error> Host::Rename([[maybe_unused]] std::string_view _old_path,
                                        [[maybe_unused]] std::string_view _new_path,
                                        [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<void, Error> Host::SetPermissions([[maybe_unused]] std::string_view _path,
                                                [[maybe_unused]] uint16_t _mode,
                                                [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
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

bool Host::Exists(std::string_view _path, const VFSCancelChecker &_cancel_checker)
{
    return Stat(_path, 0, _cancel_checker).has_value();
}

bool Host::IsImmutableFS() const noexcept
{
    return false;
}

bool Host::IsNativeFS() const noexcept
{
    return false;
}

bool Host::ValidateFilename(std::string_view _filename) const
{
    constexpr size_t max_filename_len = 256;
    if( _filename.empty() || _filename.length() > max_filename_len )
        return false;

    constexpr std::string_view invalid_chars = ":\\/\r\t\n";
    return _filename.find_first_of(invalid_chars) == std::string_view::npos;
}

std::expected<VFSListingPtr, Error>
Host::FetchDirectoryListing([[maybe_unused]] std::string_view _path,
                            [[maybe_unused]] unsigned long _flags,
                            [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<VFSListingPtr, Error> Host::FetchSingleItemListing(std::string_view _path,
                                                                 [[maybe_unused]] unsigned long _flags,
                                                                 const VFSCancelChecker &_cancel_checker)
{
    // as we came here - there's no special implementation in derived class,
    // so need to try to emulate it with available methods.

    if( !_path.starts_with("/") )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::string_view directory = utility::PathManip::Parent(_path);
    if( directory.empty() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::string_view filename = utility::PathManip::Filename(_path);
    if( filename.empty() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::string_view path_wo_trailing_slash = utility::PathManip::WithoutTrailingSlashes(_path);
    if( path_wo_trailing_slash.empty() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    if( _cancel_checker && _cancel_checker() )
        return std::unexpected(nc::Error{nc::Error::POSIX, ECANCELED});

    const std::expected<VFSStat, Error> lstat = Stat(path_wo_trailing_slash, VFSFlags::F_NoFollow, _cancel_checker);
    if( !lstat )
        return std::unexpected(lstat.error());

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

    listing_source.inodes[0] = lstat->inode;
    listing_source.unix_types[0] = IFTODT(lstat->mode);
    listing_source.atimes[0] = lstat->atime.tv_sec;
    listing_source.mtimes[0] = lstat->mtime.tv_sec;
    listing_source.ctimes[0] = lstat->ctime.tv_sec;
    listing_source.btimes[0] = lstat->btime.tv_sec;
    listing_source.unix_modes[0] = lstat->mode;
    listing_source.unix_flags[0] = lstat->flags;
    listing_source.uids[0] = lstat->uid;
    listing_source.gids[0] = lstat->gid;
    listing_source.sizes[0] = lstat->size;

    if( listing_source.unix_types[0] == DT_LNK ) {
        // read an actual link path
        if( std::expected<std::string, Error> linkpath = ReadSymlink(path_wo_trailing_slash); linkpath )
            listing_source.symlinks.insert(0, std::move(*linkpath));

        // stat the target file
        if( const std::expected<VFSStat, Error> stat = Stat(path_wo_trailing_slash, 0) ) {
            listing_source.unix_modes[0] = stat->mode;
            listing_source.unix_flags[0] = stat->flags;
            listing_source.uids[0] = stat->uid;
            listing_source.gids[0] = stat->gid;
            listing_source.sizes[0] = stat->size;
        }
    }

    return VFSListing::Build(std::move(listing_source));
}

std::expected<std::vector<VFSListingItem>, Error>
Host::FetchFlexibleListingItems(const std::string &_directory_path,
                                const std::vector<std::string> &_filenames,
                                unsigned long _flags,
                                const VFSCancelChecker &_cancel_checker)
{
    const std::expected<VFSListingPtr, Error> exp_listing =
        FetchDirectoryListing(_directory_path, _flags, _cancel_checker);
    if( !exp_listing )
        return std::unexpected(exp_listing.error());

    const VFSListing &listing = *exp_listing.value();

    std::vector<VFSListingItem> items;
    items.reserve(_filenames.size());

    // O(n) implementation, can write as O(logn) with indirection indices map
    for( unsigned i = 0, e = listing.Count(); i != e; ++i )
        for( auto &filename : _filenames )
            if( listing.Filename(i) == filename )
                items.emplace_back(listing.Item(i));

    return items;
}

void Host::SetDesctructCallback(std::function<void(const VFSHost *)> _callback)
{
    m_OnDesctruct = _callback;
}

std::expected<void, Error> Host::SetOwnership([[maybe_unused]] std::string_view _path,
                                              [[maybe_unused]] unsigned _uid,
                                              [[maybe_unused]] unsigned _gid,
                                              [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<std::vector<VFSUser>, Error> Host::FetchUsers([[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<std::vector<VFSGroup>, Error> Host::FetchGroups([[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
}

std::expected<void, Error> Host::SetFlags([[maybe_unused]] std::string_view _path,
                                          [[maybe_unused]] uint32_t _flags,
                                          [[maybe_unused]] uint64_t _vfs_options,
                                          [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
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

uint64_t Host::FullHashForPath(std::string_view _path) const noexcept
{
    const auto max_hosts = 8;
    std::array<const VFSHost *, max_hosts> hosts;
    int hosts_n = 0;

    auto cur = this;
    while( cur && hosts_n < max_hosts ) {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }

    StackAllocator alloc;
    std::pmr::string buf(&alloc);

    while( hosts_n > 0 ) {
        const auto host = hosts[--hosts_n];
        fmt::format_to(std::back_inserter(buf), "{}|{}|", host->Tag(), host->JunctionPath());
    }
    buf += _path;

    return std::hash<std::string_view>()(buf);
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
    const size_t total_len =
        std::accumulate(strings.data(), strings.data() + strings_n, size_t(0), [](auto sum, auto string) {
            return sum + string.length();
        });
    std::string verbose_path;
    verbose_path.reserve(total_len);
    for( size_t index = strings_n - 1; index < strings_n; --index )
        verbose_path += strings[index];

    return verbose_path;
}

bool Host::IsCaseSensitiveAtPath([[maybe_unused]] std::string_view _dir) const
{
    return true;
}

} // namespace nc::vfs
