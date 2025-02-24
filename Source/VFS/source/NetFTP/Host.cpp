// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Host.h"
#include <Utility/PathManip.h>
#include "../ListingInput.h"
#include "Internals.h"
#include "Cache.h"
#include "File.h"
#include <sys/dirent.h>
#include <sys/stat.h>
#include <fmt/format.h>
#include <VFS/Log.h>

#include <algorithm>

namespace nc::vfs {

using namespace ftp;
using namespace std::literals;

const char *FTPHost::UniqueTag = "net_ftp";

class VFSNetFTPHostConfiguration
{
public:
    std::string server_url;
    std::string user;
    std::string passwd;
    std::string start_dir;
    std::string verbose; // cached only. not counted in operator ==
    long port = 21;
    bool active = false;

    [[nodiscard]] static const char *Tag() { return FTPHost::UniqueTag; }

    [[nodiscard]] const char *Junction() const { return server_url.c_str(); }

    bool operator==(const VFSNetFTPHostConfiguration &_rhs) const
    {
        return server_url == _rhs.server_url && user == _rhs.user && passwd == _rhs.passwd &&
               start_dir == _rhs.start_dir && port == _rhs.port && active == _rhs.active;
    }

    [[nodiscard]] const char *VerboseJunction() const { return verbose.c_str(); }
};

FTPHost::~FTPHost() = default;

static VFSConfiguration ComposeConfiguration(const std::string &_serv_url,
                                             const std::string &_user,
                                             const std::string &_passwd,
                                             const std::string &_start_dir,
                                             long _port,
                                             bool _active)
{
    VFSNetFTPHostConfiguration config;
    config.server_url = _serv_url;
    config.user = _user;
    config.passwd = _passwd;
    config.start_dir = _start_dir;
    config.port = _port;
    config.active = _active;
    config.verbose = "ftp://"s + (config.user.empty() ? "" : config.user + "@") + config.server_url;
    return {std::move(config)};
}

FTPHost::FTPHost(const std::string &_serv_url,
                 const std::string &_user,
                 const std::string &_passwd,
                 const std::string &_start_dir,
                 long _port,
                 bool _active)
    : Host(_serv_url, nullptr, UniqueTag), m_Cache(std::make_unique<ftp::Cache>()),
      m_Configuration(ComposeConfiguration(_serv_url, _user, _passwd, _start_dir, _port, _active))
{
    const int rc = DoInit();
    if( rc < 0 )
        throw ErrorException(VFSError::ToError(rc));
}

FTPHost::FTPHost(const VFSConfiguration &_config)
    : Host(_config.Get<VFSNetFTPHostConfiguration>().server_url, nullptr, UniqueTag),
      m_Cache(std::make_unique<ftp::Cache>()), m_Configuration(_config)
{
    const int rc = DoInit();
    if( rc < 0 )
        throw ErrorException(VFSError::ToError(rc));
}

const class VFSNetFTPHostConfiguration &FTPHost::Config() const noexcept
{
    return m_Configuration.GetUnchecked<VFSNetFTPHostConfiguration>();
}

VFSMeta FTPHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = []([[maybe_unused]] const VFSHostPtr &_parent,
                           const VFSConfiguration &_config,
                           [[maybe_unused]] VFSCancelChecker _cancel_checker) {
        return std::make_shared<FTPHost>(_config);
    };
    return m;
}

VFSConfiguration FTPHost::Configuration() const
{
    return m_Configuration;
}

int FTPHost::DoInit()
{
    m_Cache->SetChangesCallback([this](const std::string &_at_dir) {
        InformDirectoryChanged(_at_dir.back() == '/' ? _at_dir : _at_dir + "/");
    });

    auto instance = SpawnCURL();

    const int result = DownloadAndCacheListing(instance.get(), Config().start_dir.c_str(), nullptr, nullptr);
    if( result == 0 ) {
        m_ListingInstance = std::move(instance);
        return 0;
    }

    return result;
}

int FTPHost::DownloadAndCacheListing(CURLInstance *_inst,
                                     const char *_path,
                                     std::shared_ptr<Directory> *_cached_dir,
                                     const VFSCancelChecker &_cancel_checker)
{
    Log::Trace("FTPHost::DownloadAndCacheListing({}, {}) called", static_cast<void *>(_inst), _path);
    if( _inst == nullptr || _path == nullptr )
        return VFSError::InvalidCall;

    std::string listing_data;
    const int result = DownloadListing(_inst, _path, listing_data, _cancel_checker);
    if( result != 0 )
        return result;

    auto dir = ParseListing(listing_data.c_str());
    m_Cache->InsertLISTDirectory(_path, dir);
    std::string path = _path;
    InformDirectoryChanged(path.back() == '/' ? path : path + "/");

    if( _cached_dir )
        *_cached_dir = dir;

    return 0;
}

int FTPHost::DownloadListing(CURLInstance *_inst,
                             const char *_path,
                             std::string &_buffer,
                             const VFSCancelChecker &_cancel_checker) const
{
    Log::Trace("FTPHost::DownloadListing({}, {}) called", static_cast<void *>(_inst), _path);
    if( _path == nullptr || _path[0] != '/' )
        return VFSError::InvalidCall;

    std::string path = _path;
    if( path.back() != '/' )
        path += '/';

    const std::string request = BuildFullURLString(path);
    Log::Trace("Request: {}", request);

    std::string response;
    _inst->call_lock.lock();
    _inst->EasySetOpt(CURLOPT_URL, request.c_str());
    _inst->EasySetOpt(CURLOPT_WRITEFUNCTION, CURLWriteDataIntoString);
    _inst->EasySetOpt(CURLOPT_WRITEDATA, &response);
    _inst->EasySetupProgFunc();
    _inst->prog_func = ^(curl_off_t, curl_off_t, curl_off_t, curl_off_t) {
      if( _cancel_checker == nil )
          return 0;
      return _cancel_checker() ? 1 : 0;
    };

    const CURLcode result = _inst->PerformEasy();
    _inst->EasyClearProgFunc();
    _inst->call_lock.unlock();

    Log::Trace("CURLcode = {}", std::to_underlying(result));

    if( result != 0 )
        return CURLErrorToVFSError(result);

    Log::Trace("response = {}", response);
    _buffer.swap(response);

    return 0;
}

// TODO: unit tests
std::string FTPHost::BuildFullURLString(std::string_view _path) const
{
    std::string result_path = fmt::format("ftp://{}", JunctionPath());
    for( const auto &part : std::filesystem::path(_path) ) {
        if( result_path.back() != '/' ) {
            result_path += '/';
        }
        if( !part.empty() && part.native() != "/" ) {
            char *escaped_curl =
                curl_easy_escape(nullptr, part.native().c_str(), static_cast<int>(part.native().length()));
            if( escaped_curl == nullptr ) {
                return {};
            }
            result_path.append(escaped_curl);
            curl_free(escaped_curl);
        }
    }
    return result_path;
}

std::unique_ptr<CURLInstance> FTPHost::SpawnCURL()
{
    auto inst = std::make_unique<CURLInstance>();
    inst->curl = curl_easy_init();
    BasicOptsSetup(inst.get());
    return inst;
}

std::expected<VFSStat, Error>
FTPHost::Stat(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    Log::Trace("FTPHost::Stat({}, {}) called", _path, _flags);
    if( _path.empty() || _path[0] != '/' ) {
        Log::Warn("Invalid call");
        return std::unexpected(VFSError::ToError(VFSError::InvalidCall));
    }

    const std::filesystem::path path = EnsureNoTrailingSlash(std::string(_path));
    if( path == "/" ) {
        // special case for root path
        VFSStat st;
        st.mode = S_IRUSR | S_IWUSR | S_IFDIR;
        st.atime.tv_sec = st.mtime.tv_sec = st.btime.tv_sec = st.ctime.tv_sec = time(nullptr);

        st.meaning.size = 1;
        st.meaning.mode = 1;
        st.meaning.mtime = st.meaning.ctime = st.meaning.btime = st.meaning.atime = 1;
        return st;
    }

    // 1st - extract directory and filename from _path
    const std::filesystem::path parent_dir = utility::PathManip::EnsureTrailingSlash(path.parent_path());
    const std::string filename = path.filename().native();

    // try to find dir from cache
    if( !(_flags & VFSFlags::F_ForceRefresh) ) {
        if( auto dir = m_Cache->FindDirectory(parent_dir.native()) ) {
            Log::Trace("found a cached directory '{}', outdated={}", parent_dir.native(), dir->IsOutdated());
            auto entry = dir->EntryByName(filename);
            if( entry ) {
                Log::Trace("found an entry for '{}', outdated={}", filename, entry->dirty);
                if( !entry->dirty ) { // if entry is here and it's not outdated - return it
                    VFSStat st;
                    entry->ToStat(st);
                    return st;
                }
                // if entry is here and it is outdated - we have to fetch a new listing
            }
            else {
                Log::Trace("didn't find an entry for '{}'", filename);
                if( !dir->IsOutdated() ) { // if we can't find entry and dir is not outdated - return NotFound.
                    return std::unexpected(VFSError::ToError(VFSError::NotFound));
                }
            }
        }
    }

    // assume that file is freshly created and thus we don't have it in current cache state
    // download new listing, sync I/O
    std::shared_ptr<Directory> dir;
    const int result = DownloadAndCacheListing(m_ListingInstance.get(), parent_dir.c_str(), &dir, _cancel_checker);
    if( result != 0 ) {
        return std::unexpected(VFSError::ToError(result));
    }

    assert(dir);
    if( auto entry = dir->EntryByName(filename) ) {
        VFSStat st;
        entry->ToStat(st);
        return st;
    }
    return std::unexpected(VFSError::ToError(VFSError::NotFound));
}

std::expected<VFSListingPtr, Error>
FTPHost::FetchDirectoryListing(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    if( _flags & VFSFlags::F_ForceRefresh )
        m_Cache->MarkDirectoryDirty(_path);

    std::shared_ptr<Directory> dir;
    const int result = GetListingForFetching(m_ListingInstance.get(), _path, dir, _cancel_checker);
    if( result != 0 )
        return std::unexpected(VFSError::ToError(result));

    // setup of listing structure
    using nc::base::variable_container;
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(std::string(_path));
    listing_source.sizes.reset(variable_container<>::type::dense);
    listing_source.atimes.reset(variable_container<>::type::dense);
    listing_source.mtimes.reset(variable_container<>::type::dense);
    listing_source.ctimes.reset(variable_container<>::type::dense);
    listing_source.btimes.reset(variable_container<>::type::dense);

    if( !(_flags & VFSFlags::F_NoDotDot) && listing_source.directories[0] != "/" ) {
        // synthesize dot-dot
        listing_source.filenames.emplace_back("..");
        listing_source.unix_types.emplace_back(DT_DIR);
        listing_source.unix_modes.emplace_back(S_IRUSR | S_IWUSR | S_IFDIR);
        auto curtime = time(nullptr);
        listing_source.sizes.insert(0, ListingInput::unknown_size);
        listing_source.atimes.insert(0, curtime);
        listing_source.btimes.insert(0, curtime);
        listing_source.ctimes.insert(0, curtime);
        listing_source.mtimes.insert(0, curtime);
    }

    for( const auto &entry : dir->entries ) {
        listing_source.filenames.emplace_back(entry.name);
        listing_source.unix_types.emplace_back((entry.mode & S_IFDIR) ? DT_DIR : DT_REG);
        listing_source.unix_modes.emplace_back(entry.mode);
        const int index = int(listing_source.filenames.size() - 1);

        listing_source.sizes.insert(index, S_ISDIR(entry.mode) ? ListingInput::unknown_size : entry.size);
        listing_source.atimes.insert(index, entry.time);
        listing_source.btimes.insert(index, entry.time);
        listing_source.ctimes.insert(index, entry.time);
        listing_source.mtimes.insert(index, entry.time);
    }

    return VFSListing::Build(std::move(listing_source));
}

int FTPHost::GetListingForFetching(CURLInstance *_inst,
                                   std::string_view _path,
                                   std::shared_ptr<Directory> &_cached_dir,
                                   const VFSCancelChecker &_cancel_checker)
{
    if( _path.empty() || _path[0] != '/' )
        return VFSError::InvalidCall;

    const auto path = utility::PathManip::EnsureTrailingSlash(_path);

    auto dir = m_Cache->FindDirectory(path.native());
    if( dir && !dir->IsOutdated() && !dir->has_dirty_items ) {
        _cached_dir = dir;
        return 0;
    }

    // download listing, sync I/O
    const int result = DownloadAndCacheListing(_inst, path.c_str(), &dir, _cancel_checker); // sync I/O here
    if( result != 0 )
        return result;

    assert(dir);

    _cached_dir = dir;
    return 0;
}

std::expected<std::shared_ptr<VFSFile>, Error> FTPHost::CreateFile(std::string_view _path,
                                                                   const VFSCancelChecker &_cancel_checker)
{
    auto file = std::make_shared<File>(_path, SharedPtr());
    if( _cancel_checker && _cancel_checker() )
        return std::unexpected(Error{Error::POSIX, ECANCELED});
    return file;
}

std::expected<void, Error> FTPHost::Unlink(std::string_view _path,
                                           [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    const std::filesystem::path path = _path;
    if( !path.is_absolute() || path.native().back() == '/' )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::filesystem::path parent_path = utility::PathManip::EnsureTrailingSlash(path.parent_path());
    const std::string cmd = "DELE " + path.filename().native();
    const std::string url = BuildFullURLString(parent_path.native());

    [[maybe_unused]] CURLMcode curlm_e;
    auto curl = InstanceForIOAtDir(parent_path);
    if( curl->IsAttached() ) {
        curlm_e = curl->Detach();
        assert(curlm_e == CURLM_OK);
    }

    struct curl_slist *header = nullptr;
    header = curl_slist_append(header, cmd.c_str());
    curl->EasySetOpt(CURLOPT_POSTQUOTE, header);
    curl->EasySetOpt(CURLOPT_URL, url.c_str());
    curl->EasySetOpt(CURLOPT_WRITEFUNCTION, 0);
    curl->EasySetOpt(CURLOPT_WRITEDATA, 0);
    curl->EasySetOpt(CURLOPT_NOBODY, 1);

    curlm_e = curl->Attach();
    assert(curlm_e == CURLM_OK);
    const CURLcode curl_res = curl->PerformMulti();

    curl_slist_free_all(header);

    if( curl_res == CURLE_OK )
        m_Cache->CommitUnlink(_path);

    CommitIOInstanceAtDir(parent_path, std::move(curl));

    if( curl_res == CURLE_OK )
        return {};

    return std::unexpected(VFSError::ToError(CURLErrorToVFSError(curl_res)));
}

// _mode is ignored, since we can't specify any access mode from ftp
std::expected<void, Error> FTPHost::CreateDirectory(std::string_view _path,
                                                    [[maybe_unused]] int _mode,
                                                    [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    const std::filesystem::path path = EnsureNoTrailingSlash(std::string(_path));
    if( !path.is_absolute() || path == "/" )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::filesystem::path parent_path = utility::PathManip::EnsureTrailingSlash(path.parent_path());
    const std::string cmd = "MKD " + path.filename().native();
    const std::string url = BuildFullURLString(parent_path.native());

    [[maybe_unused]] CURLMcode curlm_e;
    auto curl = InstanceForIOAtDir(parent_path);
    if( curl->IsAttached() ) {
        curlm_e = curl->Detach();
        assert(curlm_e == CURLM_OK);
    }

    struct curl_slist *header = nullptr;
    header = curl_slist_append(header, cmd.c_str());
    curl->EasySetOpt(CURLOPT_POSTQUOTE, header);
    curl->EasySetOpt(CURLOPT_URL, url.c_str());
    curl->EasySetOpt(CURLOPT_WRITEFUNCTION, 0);
    curl->EasySetOpt(CURLOPT_WRITEDATA, 0);
    curl->EasySetOpt(CURLOPT_NOBODY, 1);

    curlm_e = curl->Attach();
    assert(curlm_e == CURLM_OK);

    const CURLcode curl_e = curl->PerformMulti();

    curl_slist_free_all(header);

    if( curl_e == CURLE_OK )
        m_Cache->CommitMKD(path.native());

    CommitIOInstanceAtDir(parent_path, std::move(curl));

    if( curl_e == CURLE_OK )
        return {};

    return std::unexpected(VFSError::ToError(CURLErrorToVFSError(curl_e)));
}

std::expected<void, Error> FTPHost::RemoveDirectory(std::string_view _path,
                                                    [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    const std::filesystem::path path = EnsureNoTrailingSlash(std::string(_path));
    if( !path.is_absolute() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::filesystem::path parent_path = utility::PathManip::EnsureTrailingSlash(path.parent_path());
    const std::string cmd = "RMD " + path.filename().native(); // TODO: this needs to be escaped (?)
    const std::string url = BuildFullURLString(parent_path.native());

    [[maybe_unused]] CURLMcode curlm_e;
    auto curl = InstanceForIOAtDir(parent_path);
    if( curl->IsAttached() ) {
        curlm_e = curl->Detach();
        assert(curlm_e == CURLM_OK);
    }

    struct curl_slist *header = nullptr;
    header = curl_slist_append(header, cmd.c_str());
    curl->EasySetOpt(CURLOPT_POSTQUOTE, header);
    curl->EasySetOpt(CURLOPT_URL, url.c_str());
    curl->EasySetOpt(CURLOPT_WRITEFUNCTION, 0);
    curl->EasySetOpt(CURLOPT_WRITEDATA, 0);
    curl->EasySetOpt(CURLOPT_NOBODY, 1);

    curlm_e = curl->Attach();
    assert(curlm_e == CURLM_OK);
    const CURLcode curl_res = curl->PerformMulti();
    curl_slist_free_all(header);

    if( curl_res == CURLE_OK )
        m_Cache->CommitRMD(path.native());

    CommitIOInstanceAtDir(parent_path, std::move(curl));

    if( curl_res == CURLE_OK )
        return {};

    return std::unexpected(VFSError::ToError(CURLErrorToVFSError(curl_res)));
}

std::expected<void, Error> FTPHost::Rename(std::string_view _old_path,
                                           std::string_view _new_path,
                                           [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    const std::filesystem::path old_path = EnsureNoTrailingSlash(std::string(_old_path));
    const std::filesystem::path new_path = EnsureNoTrailingSlash(std::string(_new_path));
    if( !old_path.is_absolute() || !new_path.is_absolute() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::filesystem::path old_parent_path = utility::PathManip::EnsureTrailingSlash(old_path.parent_path());

    const std::string url = BuildFullURLString(old_parent_path.native());
    const std::string cmd1 = "RNFR "s + old_path.native(); // TODO: this needs to be escaped (?)
    const std::string cmd2 = "RNTO "s + new_path.native(); // TODO: this needs to be escaped (?)

    [[maybe_unused]] CURLMcode curlm_e;
    auto curl = InstanceForIOAtDir(old_parent_path);
    if( curl->IsAttached() ) {
        curlm_e = curl->Detach();
        assert(curlm_e == CURLM_OK);
    }

    struct curl_slist *header = nullptr;
    header = curl_slist_append(header, cmd1.c_str());
    header = curl_slist_append(header, cmd2.c_str());
    curl->EasySetOpt(CURLOPT_POSTQUOTE, header);
    curl->EasySetOpt(CURLOPT_URL, url.c_str());
    curl->EasySetOpt(CURLOPT_WRITEFUNCTION, 0);
    curl->EasySetOpt(CURLOPT_WRITEDATA, 0);
    curl->EasySetOpt(CURLOPT_NOBODY, 1);

    curlm_e = curl->Attach();
    assert(curlm_e == CURLM_OK);
    const CURLcode curl_res = curl->PerformMulti();

    curl_slist_free_all(header);

    if( curl_res == CURLE_OK )
        m_Cache->CommitRename(old_path.native(), new_path.native());

    CommitIOInstanceAtDir(old_parent_path, std::move(curl));

    if( curl_res == CURLE_OK )
        return {};

    return std::unexpected(VFSError::ToError(CURLErrorToVFSError(curl_res)));
}

void FTPHost::MakeDirectoryStructureDirty(const char *_path)
{
    if( auto dir = m_Cache->FindDirectory(_path) ) {
        InformDirectoryChanged(dir->path);
        dir->dirty_structure = true;
    }
}

bool FTPHost::IsDirectoryChangeObservationAvailable([[maybe_unused]] std::string_view _path)
{
    return true;
}

HostDirObservationTicket FTPHost::ObserveDirectoryChanges(std::string_view _path, std::function<void()> _handler)
{
    if( _path.empty() || _path[0] != '/' )
        return {};

    const std::lock_guard<std::mutex> lock(m_UpdateHandlersLock);

    m_UpdateHandlers.emplace_back();
    auto &h = m_UpdateHandlers.back();
    h.ticket = m_LastUpdateTicket++;
    h.path = _path;
    if( h.path.back() != '/' )
        h.path += '/';
    h.handler = std::move(_handler);

    return {h.ticket, shared_from_this()};
}

void FTPHost::StopDirChangeObserving(unsigned long _ticket)
{
    const std::lock_guard<std::mutex> lock(m_UpdateHandlersLock);
    std::erase_if(m_UpdateHandlers, [=](auto &_h) { return _h.ticket == _ticket; });
}

void FTPHost::InformDirectoryChanged(const std::string &_dir_wth_sl)
{
    assert(_dir_wth_sl.back() == '/');
    const std::lock_guard<std::mutex> lock(m_UpdateHandlersLock);
    for( auto &i : m_UpdateHandlers )
        if( i.path == _dir_wth_sl )
            i.handler();
}

bool FTPHost::IsWritable() const
{
    return true;
}

std::expected<void, Error>
FTPHost::IterateDirectoryListing(std::string_view _path, const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    std::shared_ptr<Directory> dir;
    const int result = GetListingForFetching(m_ListingInstance.get(), _path, dir, nullptr);
    if( result != 0 )
        return std::unexpected(VFSError::ToError(result));

    for( auto &i : dir->entries ) {
        VFSDirEnt e;
        strcpy(e.name, i.name.c_str());
        e.name_len = uint16_t(i.name.length());
        e.type = IFTODT(i.mode);

        if( !_handler(e) )
            break;
    }
    return {};
}

std::unique_ptr<CURLInstance> FTPHost::InstanceForIOAtDir(const std::filesystem::path &_dir)
{
    assert(!_dir.empty() && _dir.native().back() == '/');
    const std::lock_guard<std::mutex> lock(m_IOIntancesLock);

    // try to find cached inst in exact this directory
    auto i = m_IOIntances.find(_dir);
    if( i != end(m_IOIntances) ) {
        auto r = std::move(i->second);
        m_IOIntances.erase(i);
        return r;
    }

    // if can't find - return any cached
    if( !m_IOIntances.empty() ) {
        i = m_IOIntances.begin();
        auto r = std::move(i->second);
        m_IOIntances.erase(i);
        return r;
    }

    // if we're empty - just create and return new inst
    auto inst = SpawnCURL();
    inst->curlm = curl_multi_init();
    inst->Attach();

    return inst;
}

void FTPHost::CommitIOInstanceAtDir(const std::filesystem::path &_dir, std::unique_ptr<CURLInstance> _i)
{
    assert(!_dir.empty() && _dir.native().back() == '/');
    const std::lock_guard<std::mutex> lock(m_IOIntancesLock);

    _i->EasyReset();
    BasicOptsSetup(_i.get());
    m_IOIntances[_dir] = std::move(_i);
}

void FTPHost::BasicOptsSetup(CURLInstance *_inst)
{
    _inst->EasySetOpt(CURLOPT_VERBOSE, g_CURLVerbose);
    _inst->EasySetOpt(CURLOPT_FTP_FILEMETHOD, g_CURLFTPMethod);

    if( !Config().user.empty() )
        _inst->EasySetOpt(CURLOPT_USERNAME, Config().user.c_str());
    if( !Config().passwd.empty() )
        _inst->EasySetOpt(CURLOPT_PASSWORD, Config().passwd.c_str());
    if( Config().port > 0 )
        _inst->EasySetOpt(CURLOPT_PORT, Config().port);
    if( Config().active )
        _inst->EasySetOpt(CURLOPT_FTPPORT, "-");

    // TODO: SSL support
    // _inst->EasySetOpt(CURLOPT_USE_SSL, CURLUSESSL_TRY);
    // _inst->EasySetOpt(CURLOPT_SSL_VERIFYPEER, false);
    // _inst->EasySetOpt(CURLOPT_SSL_VERIFYHOST, false);
}

std::expected<VFSStatFS, Error> FTPHost::StatFS([[maybe_unused]] std::string_view _path,
                                                [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    VFSStatFS stat;
    stat.avail_bytes = stat.free_bytes = stat.total_bytes = 0;
    stat.volume_name = JunctionPath();
    return stat;
}

const std::string &FTPHost::ServerUrl() const noexcept
{
    return Config().server_url;
}

const std::string &FTPHost::User() const noexcept
{
    return Config().user;
}

long FTPHost::Port() const noexcept
{
    return Config().port;
}

bool FTPHost::Active() const noexcept
{
    return Config().active;
}

} // namespace nc::vfs
