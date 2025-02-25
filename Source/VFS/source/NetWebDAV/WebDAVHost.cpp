// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WebDAVHost.h"
#include "Internal.h"
#include <Utility/PathManip.h>
#include "../ListingInput.h"
#include "ConnectionsPool.h"
#include "Cache.h"
#include "File.h"
#include "PathRoutines.h"
#include "Requests.h"
#include <sys/dirent.h>
#include <fmt/core.h>

#include <algorithm>
#include <memory>

namespace nc::vfs {

using namespace webdav;

const char *WebDAVHost::UniqueTag = "net_webdav";

struct WebDAVHost::State {
    State(const HostConfiguration &_config) : m_Pool{_config} {}

    class ConnectionsPool m_Pool;
    class Cache m_Cache;
};

static VFSConfiguration ComposeConfiguration(const std::string &_serv_url,
                                             const std::string &_user,
                                             const std::string &_passwd,
                                             const std::string &_path,
                                             bool _https,
                                             int _port);
static bool IsValidInputPath(std::string_view _path);

WebDAVHost::WebDAVHost(const std::string &_serv_url,
                       const std::string &_user,
                       const std::string &_passwd,
                       const std::string &_path,
                       bool _https,
                       int _port)
    : VFSHost(_serv_url, nullptr, UniqueTag),
      m_Configuration(ComposeConfiguration(_serv_url, _user, _passwd, _path, _https, _port))
{
    Init();
}

WebDAVHost::WebDAVHost(const VFSConfiguration &_config)
    : VFSHost(_config.Get<HostConfiguration>().server_url, nullptr, UniqueTag), m_Configuration(_config)
{
    Init();
}

WebDAVHost::~WebDAVHost() = default;

void WebDAVHost::Init()
{
    I = std::make_unique<State>(Config());

    auto ar = I->m_Pool.Get();
    const auto [rc, requests] = RequestServerOptions(Config(), *ar.connection);
    if( rc != VFSError::Ok )
        throw ErrorException(VFSError::ToError(rc));

    // it's besically good to check available requests before commiting to work
    // with the server, BUT my local QNAP NAS is pretty strange and reports a
    // gibberish like "Allow: GET,HEAD,POST,OPTIONS,HEAD,HEAD", which doesn't help
    // at all.
    //    if( (requests & HTTPRequests::MinimalRequiredSet) !=
    //    HTTPRequests::MinimalRequiredSet ) {
    //        HTTPRequests::Print(requests);
    //        throw ErrorException( VFSError::ToError(VFSError::FromErrno(EPROTONOSUPPORT)) );
    //    }

    AddFeatures(HostFeatures::NonEmptyRmDir);
}

VFSConfiguration WebDAVHost::Configuration() const
{
    return m_Configuration;
}

const HostConfiguration &WebDAVHost::Config() const noexcept
{
    return m_Configuration.GetUnchecked<webdav::HostConfiguration>();
}

bool WebDAVHost::IsWritable() const
{
    return true;
}

std::expected<VFSListingPtr, Error>
WebDAVHost::FetchDirectoryListing(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const auto path = EnsureTrailingSlash(std::string(_path));

    if( _flags & VFSFlags::F_ForceRefresh )
        I->m_Cache.DiscardListing(path);

    std::vector<PropFindResponse> items;
    if( auto cached = I->m_Cache.Listing(path) ) {
        items = std::move(*cached);
    }
    else {
        const auto refresh_rc = RefreshListingAtPath(path, _cancel_checker);
        if( refresh_rc != VFSError::Ok )
            return std::unexpected(VFSError::ToError(refresh_rc));

        if( auto cached2 = I->m_Cache.Listing(path) )
            items = std::move(*cached2);
        else
            return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});
    }

    if( (_flags & VFSFlags::F_NoDotDot) || path == "/" )
        std::erase_if(items, [](const auto &_item) { return _item.filename == ".."; });
    else
        std::ranges::partition(items, [](const auto &_i) { return _i.filename == ".."; });

    using nc::base::variable_container;
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = path;
    listing_source.sizes.reset(variable_container<>::type::dense);
    listing_source.btimes.reset(variable_container<>::type::sparse);
    listing_source.ctimes.reset(variable_container<>::type::sparse);
    listing_source.mtimes.reset(variable_container<>::type::sparse);

    int index = 0;
    for( auto &e : items ) {
        listing_source.filenames.emplace_back(e.filename);
        listing_source.unix_modes.emplace_back(e.is_directory ? DirectoryAccessMode : RegularFileAccessMode);
        listing_source.unix_types.emplace_back(e.is_directory ? DT_DIR : DT_REG);
        if( e.size >= 0 )
            listing_source.sizes.insert(index, e.size);
        if( e.creation_date >= 0 )
            listing_source.btimes.insert(index, e.creation_date);
        if( e.modification_date >= 0 ) {
            listing_source.ctimes.insert(index, e.modification_date);
            listing_source.mtimes.insert(index, e.modification_date);
        }
        index++;
    }

    return VFSListing::Build(std::move(listing_source));
}

std::expected<void, Error>
WebDAVHost::IterateDirectoryListing(std::string_view _path,
                                    const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    if( !IsValidInputPath(_path) )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const auto path = EnsureTrailingSlash(std::string(_path));

    std::vector<PropFindResponse> items;
    if( auto cached = I->m_Cache.Listing(path) ) {
        items = std::move(*cached);
    }
    else {
        const auto refresh_rc = RefreshListingAtPath(path, nullptr);
        if( refresh_rc != VFSError::Ok )
            return std::unexpected(VFSError::ToError(refresh_rc));

        if( auto cached2 = I->m_Cache.Listing(path) )
            items = std::move(*cached2);
        else
            return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});
    }

    std::erase_if(items, [](const auto &_item) { return _item.filename == ".."; });

    for( const auto &i : items ) {
        VFSDirEnt e;
        strcpy(e.name, i.filename.c_str());
        e.name_len = uint16_t(i.filename.length());
        e.type = i.is_directory ? DT_DIR : DT_REG;
        if( !_handler(e) )
            return std::unexpected(nc::Error{nc::Error::POSIX, ECANCELED});
    }

    return {};
}

std::expected<VFSStat, Error>
WebDAVHost::Stat(std::string_view _path, [[maybe_unused]] unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    PropFindResponse item;
    auto [cached_1st, cached_1st_res] = I->m_Cache.Item(_path);
    if( cached_1st ) {
        item = std::move(*cached_1st);
    }
    else {
        if( cached_1st_res == Cache::E::NonExist )
            return std::unexpected(nc::Error{nc::Error::POSIX, ENOENT});

        const auto [directory, filename] = DeconstructPath(_path);
        if( directory.empty() )
            return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});
        const auto rc = RefreshListingAtPath(directory, _cancel_checker);
        if( rc != VFSError::Ok )
            return std::unexpected(VFSError::ToError(rc));

        auto [cached_2nd, cached_2nd_res] = I->m_Cache.Item(_path);
        if( cached_2nd )
            item = std::move(*cached_2nd);
        else
            return std::unexpected(nc::Error{nc::Error::POSIX, ENOENT});
    }

    VFSStat st;
    st.mode = item.is_directory ? DirectoryAccessMode : RegularFileAccessMode;
    if( item.size >= 0 ) {
        st.size = item.size;
        st.meaning.size = 1;
    }
    if( item.creation_date >= 0 ) {
        st.btime.tv_sec = item.creation_date;
        st.meaning.btime = true;
    }
    if( item.modification_date >= 0 ) {
        st.mtime.tv_sec = st.ctime.tv_sec = item.modification_date;
        st.meaning.mtime = st.meaning.ctime = true;
    }

    return st;
}

int WebDAVHost::RefreshListingAtPath(const std::string &_path, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( _path.back() != '/' )
        throw std::invalid_argument("RefreshListingAtPath requires a path with a trailing slash");

    auto ar = I->m_Pool.Get();
    auto [rc, items] = RequestDAVListing(Config(), *ar.connection, _path);
    if( rc != VFSError::Ok )
        return rc;

    I->m_Cache.CommitListing(_path, std::move(items));

    return VFSError::Ok;
}

std::expected<VFSStatFS, Error> WebDAVHost::StatFS([[maybe_unused]] std::string_view _path,
                                                   [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    const auto ar = I->m_Pool.Get();
    const auto [rc, free, used] = RequestSpaceQuota(Config(), *ar.connection);
    if( rc != VFSError::Ok )
        return std::unexpected(VFSError::ToError(rc));

    VFSStatFS stat;

    if( free >= 0 ) {
        stat.free_bytes = free;
        stat.avail_bytes = free;
    }
    if( free >= 0 && used >= 0 ) {
        stat.total_bytes = free + used;
    }

    stat.volume_name = Config().full_url;

    return stat;
}

std::expected<void, Error> WebDAVHost::CreateDirectory(std::string_view _path,
                                                       [[maybe_unused]] int _mode,
                                                       [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const auto path = EnsureTrailingSlash(std::string(_path));
    const auto ar = I->m_Pool.Get();
    const auto rc = RequestMKCOL(Config(), *ar.connection, path);
    if( rc != VFSError::Ok )
        return std::unexpected(VFSError::ToError(rc));

    I->m_Cache.CommitMkDir(path);

    return {};
}

std::expected<void, Error> WebDAVHost::RemoveDirectory(std::string_view _path,
                                                       [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const auto path = EnsureTrailingSlash(std::string(_path));
    const auto ar = I->m_Pool.Get();
    const auto rc = RequestDelete(Config(), *ar.connection, path);
    if( rc != VFSError::Ok )
        return std::unexpected(VFSError::ToError(rc));

    I->m_Cache.CommitRmDir(path);

    return {};
}

std::expected<void, Error> WebDAVHost::Unlink(std::string_view _path,
                                              [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const auto ar = I->m_Pool.Get();
    const auto rc = RequestDelete(Config(), *ar.connection, _path);
    if( rc != VFSError::Ok )
        return std::unexpected(VFSError::ToError(rc));

    I->m_Cache.CommitUnlink(_path);

    return {};
}

std::expected<std::shared_ptr<VFSFile>, Error>
WebDAVHost::CreateFile(std::string_view _path, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    return std::make_shared<File>(_path, std::dynamic_pointer_cast<WebDAVHost>(shared_from_this()));
}

webdav::ConnectionsPool &WebDAVHost::ConnectionsPool()
{
    return I->m_Pool;
}

webdav::Cache &WebDAVHost::Cache()
{
    return I->m_Cache;
}

std::expected<void, Error> WebDAVHost::Rename(std::string_view _old_path,
                                              std::string_view _new_path,
                                              [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_old_path) || !IsValidInputPath(_new_path) )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::expected<VFSStat, Error> st = Stat(_old_path, 0, _cancel_checker);
    if( !st )
        return std::unexpected(st.error());

    std::string old_path = std::string(_old_path);
    std::string new_path = std::string(_new_path);
    if( st->mode_bits.dir ) {
        // WebDAV RFC mandates that directories (collections) should be denoted with a trailing slash
        old_path = EnsureTrailingSlash(old_path);
        new_path = EnsureTrailingSlash(new_path);
    }

    const auto ar = I->m_Pool.Get();
    const auto move_rc = RequestMove(Config(), *ar.connection, old_path, new_path);
    if( move_rc != VFSError::Ok )
        return std::unexpected(VFSError::ToError(move_rc));

    I->m_Cache.CommitMove(_old_path, _new_path);

    return {};
}

bool WebDAVHost::IsDirectoryChangeObservationAvailable([[maybe_unused]] std::string_view _path)
{
    return true;
}

HostDirObservationTicket WebDAVHost::ObserveDirectoryChanges(std::string_view _path, std::function<void()> _handler)
{
    if( !IsValidInputPath(_path) )
        return {};
    const auto ticket = I->m_Cache.Observe(std::string(_path), std::move(_handler));
    return HostDirObservationTicket{ticket, shared_from_this()};
}

void WebDAVHost::StopDirChangeObserving(unsigned long _ticket)
{
    I->m_Cache.StopObserving(_ticket);
}

VFSMeta WebDAVHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = []([[maybe_unused]] const VFSHostPtr &_parent,
                           const VFSConfiguration &_config,
                           [[maybe_unused]] VFSCancelChecker _cancel_checker) {
        return std::make_shared<WebDAVHost>(_config);
    };
    return m;
}

const std::string &WebDAVHost::Host() const noexcept
{
    return Config().server_url;
}

const std::string &WebDAVHost::Path() const noexcept
{
    return Config().path;
}

const std::string WebDAVHost::Username() const noexcept
{
    return Config().user;
}

int WebDAVHost::Port() const noexcept
{
    return Config().port;
}

static VFSConfiguration ComposeConfiguration(const std::string &_serv_url,
                                             const std::string &_user,
                                             const std::string &_passwd,
                                             const std::string &_path,
                                             bool _https,
                                             int _port)
{
    if( _port <= 0 )
        _port = _https ? 443 : 80;

    const bool default_port = _https ? (_port == 443) : (_port == 80);

    HostConfiguration config;
    config.server_url = _serv_url;
    config.user = _user;
    config.passwd = _passwd;
    config.path = _path;
    config.https = _https;
    config.port = _port;
    config.verbose = fmt::format("{}{}{}{}{}{}{}",
                                 _https ? "https://" : "http://",
                                 (config.user.empty() ? "" : config.user),
                                 (config.user.empty() ? "" : "@"),
                                 _serv_url,
                                 (default_port ? "" : ":"),
                                 (default_port ? "" : std::to_string(_port)),
                                 (_path.empty() ? "" : "/" + _path));
    config.full_url = fmt::format("{}{}{}{}/{}",
                                  _https ? "https://" : "http://",
                                  _serv_url,
                                  (default_port ? "" : ":"),
                                  (default_port ? "" : std::to_string(_port)),
                                  (_path.empty() ? "" : _path + "/"));

    return {std::move(config)};
}

static bool IsValidInputPath(std::string_view _path)
{
    return !_path.empty() && _path[0] == '/';
}

} // namespace nc::vfs
