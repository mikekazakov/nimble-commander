// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
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

#include <memory>
#include <algorithm>

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
static bool IsValidInputPath(const char *_path);

WebDAVHost::WebDAVHost(const std::string &_serv_url,
                       const std::string &_user,
                       const std::string &_passwd,
                       const std::string &_path,
                       bool _https,
                       int _port)
    : VFSHost(_serv_url.c_str(), nullptr, UniqueTag),
      m_Configuration(ComposeConfiguration(_serv_url, _user, _passwd, _path, _https, _port))
{
    Init();
}

WebDAVHost::WebDAVHost(const VFSConfiguration &_config)
    : VFSHost(_config.Get<HostConfiguration>().server_url.c_str(), nullptr, UniqueTag), m_Configuration(_config)
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
        throw VFSErrorException(rc);

    // it's besically good to check available requests before commiting to work
    // with the server, BUT my local QNAP NAS is pretty strange and reports a
    // gibberish like "Allow: GET,HEAD,POST,OPTIONS,HEAD,HEAD", which doesn't help
    // at all.
    //    if( (requests & HTTPRequests::MinimalRequiredSet) !=
    //    HTTPRequests::MinimalRequiredSet ) {
    //        HTTPRequests::Print(requests);
    //        throw VFSErrorException( VFSError::FromErrno(EPROTONOSUPPORT) );
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

int WebDAVHost::FetchDirectoryListing(const char *_path,
                                      VFSListingPtr &_target,
                                      unsigned long _flags,
                                      const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return VFSError::InvalidCall;

    const auto path = EnsureTrailingSlash(_path);

    if( _flags & VFSFlags::F_ForceRefresh )
        I->m_Cache.DiscardListing(path);

    std::vector<PropFindResponse> items;
    if( auto cached = I->m_Cache.Listing(path) ) {
        items = std::move(*cached);
    }
    else {
        const auto refresh_rc = RefreshListingAtPath(path, _cancel_checker);
        if( refresh_rc != VFSError::Ok )
            return refresh_rc;

        if( auto cached2 = I->m_Cache.Listing(path) )
            items = std::move(*cached2);
        else
            return VFSError::GenericError;
    }

    if( (_flags & VFSFlags::F_NoDotDot) || path == "/" )
        items.erase(std::remove_if(
                        std::begin(items), std::end(items), [](const auto &_item) { return _item.filename == ".."; }),
                    std::end(items));
    else
        std::partition(std::begin(items), std::end(items), [](const auto &_i) { return _i.filename == ".."; });

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

    _target = VFSListing::Build(std::move(listing_source));
    return VFSError::Ok;
}

int WebDAVHost::IterateDirectoryListing(const char *_path,
                                        const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    if( !IsValidInputPath(_path) )
        return VFSError::InvalidCall;

    const auto path = EnsureTrailingSlash(_path);

    std::vector<PropFindResponse> items;
    if( auto cached = I->m_Cache.Listing(path) ) {
        items = std::move(*cached);
    }
    else {
        const auto refresh_rc = RefreshListingAtPath(path, nullptr);
        if( refresh_rc != VFSError::Ok )
            return refresh_rc;

        if( auto cached2 = I->m_Cache.Listing(path) )
            items = std::move(*cached2);
        else
            return VFSError::GenericError;
    }

    items.erase(remove_if(begin(items), end(items), [](const auto &_item) { return _item.filename == ".."; }),
                end(items));

    for( const auto &i : items ) {
        VFSDirEnt e;
        strcpy(e.name, i.filename.c_str());
        e.name_len = uint16_t(i.filename.length());
        e.type = i.is_directory ? DT_DIR : DT_REG;
        if( !_handler(e) )
            return VFSError::Cancelled;
    }

    return VFSError::Ok;
}

int WebDAVHost::Stat(const char *_path,
                     VFSStat &_st,
                     [[maybe_unused]] unsigned long _flags,
                     const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return VFSError::InvalidCall;

    PropFindResponse item;
    auto [cached_1st, cached_1st_res] = I->m_Cache.Item(_path);
    if( cached_1st ) {
        item = std::move(*cached_1st);
    }
    else {
        if( cached_1st_res == Cache::E::NonExist )
            return VFSError::FromErrno(ENOENT);

        const auto [directory, filename] = DeconstructPath(_path);
        if( directory.empty() )
            return VFSError::InvalidCall;
        const auto rc = RefreshListingAtPath(directory, _cancel_checker);
        if( rc != VFSError::Ok )
            return rc;

        auto [cached_2nd, cached_2nd_res] = I->m_Cache.Item(_path);
        if( cached_2nd )
            item = std::move(*cached_2nd);
        else
            return VFSError::FromErrno(ENOENT);
    }

    memset(&_st, 0, sizeof(_st));
    _st.mode = item.is_directory ? DirectoryAccessMode : RegularFileAccessMode;
    if( item.size >= 0 ) {
        _st.size = item.size;
        _st.meaning.size = 1;
    }
    if( item.creation_date >= 0 ) {
        _st.btime.tv_sec = item.creation_date;
        _st.meaning.btime = true;
    }
    if( item.modification_date >= 0 ) {
        _st.mtime.tv_sec = _st.ctime.tv_sec = item.modification_date;
        _st.meaning.mtime = _st.meaning.ctime = true;
    }

    return VFSError::Ok;
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

int WebDAVHost::StatFS([[maybe_unused]] const char *_path,
                       VFSStatFS &_stat,
                       [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    const auto ar = I->m_Pool.Get();
    const auto [rc, free, used] = RequestSpaceQuota(Config(), *ar.connection);
    if( rc != VFSError::Ok )
        return rc;

    _stat = nc::vfs::StatFS{};

    if( free >= 0 ) {
        _stat.free_bytes = free;
        _stat.avail_bytes = free;
    }
    if( free >= 0 && used >= 0 ) {
        _stat.total_bytes = free + used;
    }

    _stat.volume_name = Config().full_url;

    return VFSError::Ok;
}

int WebDAVHost::CreateDirectory(const char *_path,
                                [[maybe_unused]] int _mode,
                                [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return VFSError::InvalidCall;

    const auto path = EnsureTrailingSlash(_path);
    const auto ar = I->m_Pool.Get();
    const auto rc = RequestMKCOL(Config(), *ar.connection, path);
    if( rc != VFSError::Ok )
        return rc;

    I->m_Cache.CommitMkDir(path);

    return VFSError::Ok;
}

int WebDAVHost::RemoveDirectory(const char *_path, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return VFSError::InvalidCall;

    const auto path = EnsureTrailingSlash(_path);
    const auto ar = I->m_Pool.Get();
    const auto rc = RequestDelete(Config(), *ar.connection, path);
    if( rc != VFSError::Ok )
        return rc;

    I->m_Cache.CommitRmDir(path);

    return VFSError::Ok;
}

int WebDAVHost::Unlink(const char *_path, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return VFSError::InvalidCall;

    const auto ar = I->m_Pool.Get();
    const auto rc = RequestDelete(Config(), *ar.connection, _path);
    if( rc != VFSError::Ok )
        return rc;

    I->m_Cache.CommitUnlink(_path);

    return VFSError::Ok;
}

int WebDAVHost::CreateFile(const char *_path,
                           std::shared_ptr<VFSFile> &_target,
                           [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_path) )
        return VFSError::InvalidCall;

    _target = std::make_shared<File>(_path, std::dynamic_pointer_cast<WebDAVHost>(shared_from_this()));

    return VFSError::Ok;
}

webdav::ConnectionsPool &WebDAVHost::ConnectionsPool()
{
    return I->m_Pool;
}

webdav::Cache &WebDAVHost::Cache()
{
    return I->m_Cache;
}

int WebDAVHost::Rename(const char *_old_path,
                       const char *_new_path,
                       [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( !IsValidInputPath(_old_path) || !IsValidInputPath(_new_path) )
        return VFSError::InvalidCall;

    VFSStat st;
    const int stat_rc = Stat(_old_path, st, 0, _cancel_checker);
    if( stat_rc != VFSError::Ok )
        return stat_rc;

    std::string old_path = _old_path;
    std::string new_path = _new_path;
    if( st.mode_bits.dir ) {
        // WebDAV RFC mandates that directories (collections) should be denoted with a trailing slash
        old_path = EnsureTrailingSlash(old_path);
        new_path = EnsureTrailingSlash(new_path);
    }

    const auto ar = I->m_Pool.Get();
    const auto rc = RequestMove(Config(), *ar.connection, old_path, new_path);
    if( rc != VFSError::Ok )
        return rc;

    I->m_Cache.CommitMove(_old_path, _new_path);

    return VFSError::Ok;
}

bool WebDAVHost::IsDirChangeObservingAvailable([[maybe_unused]] const char *_path)
{
    return true;
}

HostDirObservationTicket WebDAVHost::DirChangeObserve(const char *_path, std::function<void()> _handler)
{
    if( !IsValidInputPath(_path) )
        return {};
    const auto ticket = I->m_Cache.Observe(_path, std::move(_handler));
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

static bool IsValidInputPath(const char *_path)
{
    return _path != nullptr && _path[0] == '/';
}

} // namespace nc::vfs
