// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/PathManip.h>
#include <VFS/Log.h>
#include "../ListingInput.h"
#include "Aux.h"
#include "Host.h"
#include "File.h"
#include "Authenticator.h"
#include <sys/dirent.h>

namespace nc::vfs {

using namespace dropbox;
using namespace std::literals;

const char *DropboxHost::UniqueTag = "net_dropbox";

class VFSNetDropboxHostConfiguration
{
public:
    std::string account;
    std::string token;
    std::string verbose;
    std::string client_id;
    std::string client_secret;

    [[nodiscard]] static const char *Tag() { return DropboxHost::UniqueTag; }

    [[nodiscard]] const char *Junction() const { return account.c_str(); }

    bool operator==(const VFSNetDropboxHostConfiguration &_rhs) const
    {
        return account == _rhs.token && token == _rhs.token;
    }

    [[nodiscard]] const char *VerboseJunction() const { return verbose.c_str(); }
};

static VFSNetDropboxHostConfiguration Compose(const std::string &_account,
                                              const std::string &_token,
                                              const std::string &_client_id,
                                              const std::string &_client_secret)
{
    VFSNetDropboxHostConfiguration config;
    config.account = _account;
    config.token = _token;
    config.verbose = "dropbox://"s + _account;
    config.client_id = _client_id;
    config.client_secret = _client_secret;
    return config;
}

struct DropboxHost::State {
    std::string m_Account;
    std::string m_Token;
    std::string m_RefreshToken;
    dropbox::URLSessionCreator *m_SessionCreator = nullptr;
    NSString *m_AuthString;
    NSURLSession *m_GenericSession;
    AccountInfo m_AccountInfo;
};

DropboxHost::DropboxHost(const Params &_params)
    : Host("", nullptr, DropboxHost::UniqueTag), I(std::make_unique<State>()),
      m_Config{Compose(_params.account, _params.access_token, _params.client_id, _params.client_secret)}
{
    I->m_SessionCreator =
        _params.session_creator ? _params.session_creator : &dropbox::URLSessionFactory::DefaultFactory();

    Init();
}

DropboxHost::DropboxHost(const VFSConfiguration &_config)
    : Host("", nullptr, DropboxHost::UniqueTag), I(std::make_unique<State>()), m_Config(_config)
{
    I->m_SessionCreator = &dropbox::URLSessionFactory::DefaultFactory();
    Init();
}

void DropboxHost::Init()
{
    Construct(Config().account, Config().token);
    InitialAccountLookup();
    AddFeatures(HostFeatures::NonEmptyRmDir);
}

void DropboxHost::Construct(const std::string &_account, const std::string &_access_token)
{
    assert(I->m_SessionCreator != nil);
    I->m_GenericSession = I->m_SessionCreator->CreateSession(NSURLSessionConfiguration.defaultSessionConfiguration);

    I->m_Account = _account;
    if( TokenMangler::IsMangledRefreshToken(_access_token) ) {
        I->m_RefreshToken = TokenMangler::FromMangledRefreshToken(_access_token);
        auto [vfs_err, access_token] = RetreiveAccessTokenFromRefreshToken(I->m_RefreshToken);
        if( vfs_err != VFSError::Ok )
            throw ErrorException(VFSError::ToError(vfs_err));
        SetAccessToken(access_token);
    }
    else {
        SetAccessToken(_access_token);
        if( I->m_Token.empty() )
            throw ErrorException{VFSError::ToError(VFSError::FromErrno(EINVAL))};
    }
}

DropboxHost::~DropboxHost() = default;

const VFSNetDropboxHostConfiguration &DropboxHost::Config() const
{
    return m_Config.Get<VFSNetDropboxHostConfiguration>();
}

void DropboxHost::SetAccessToken(const std::string &_access_token)
{
    I->m_Token = _access_token;
    I->m_AuthString = [NSString stringWithFormat:@"Bearer %s", I->m_Token.c_str()];
}

std::pair<int, std::string> DropboxHost::RetreiveAccessTokenFromRefreshToken(const std::string &_refresh_token)
{
    NSMutableURLRequest *const req = [[NSMutableURLRequest alloc] initWithURL:api::OAuth2Token];
    req.HTTPMethod = @"POST";
    // YOLO: let's assume all these string don't need percent escaping...
    auto post_string =
        [NSString stringWithFormat:@"grant_type=refresh_token&refresh_token=%s&client_id=%s&client_secret=%s",
                                   _refresh_token.c_str(),
                                   Config().client_id.c_str(),
                                   Config().client_secret.c_str()];
    [req setHTTPBody:[post_string dataUsingEncoding:NSUTF8StringEncoding]];

    const auto [rc, data] = SendSynchronousRequest(GenericSession(), req);
    if( rc == VFSError::Ok ) {
        const auto json = ParseJSON(data);
        if( !json )
            return {VFSError::FromErrno(EBADMSG), ""};
        const auto access_token = ParseRefreshTokenReponse(*json);
        if( access_token )
            return {VFSError::Ok, *access_token};
        else
            return {VFSError::FromErrno(EBADMSG), ""};
    }
    else
        return {rc, ""};
}

void DropboxHost::InitialAccountLookup()
{
    NSMutableURLRequest *const req = [[NSMutableURLRequest alloc] initWithURL:api::GetCurrentAccount];
    auto [rc, data] = SendSynchronousPostRequest(req);
    if( rc == VFSError::Ok ) {
        auto json = ParseJSON(data);
        if( !json )
            throw ErrorException(VFSError::ToError(VFSError::FromErrno(EBADMSG)));
        I->m_AccountInfo = ParseAccountInfo(*json);
    }
    else
        throw ErrorException(VFSError::ToError(rc));
}

std::pair<int, std::string> DropboxHost::CheckTokenAndRetrieveAccountEmail(const std::string &_token)
{
    const auto config = NSURLSessionConfiguration.defaultSessionConfiguration;
    const auto session = [NSURLSession sessionWithConfiguration:config];
    const auto auth_string = [NSString stringWithFormat:@"Bearer %s", _token.c_str()];
    NSMutableURLRequest *const request = [[NSMutableURLRequest alloc] initWithURL:api::GetCurrentAccount];
    request.HTTPMethod = @"POST";
    [request setValue:auth_string forHTTPHeaderField:@"Authorization"];
    auto [rc, data] = SendSynchronousRequest(session, request);
    if( rc == VFSError::Ok ) {
        const auto json = ParseJSON(data);
        if( !json )
            return {VFSError::FromErrno(EBADMSG), ""};
        const auto account_info = ParseAccountInfo(*json);
        return {VFSError::Ok, account_info.email};
    }
    else
        return {rc, ""};
}

VFSMeta DropboxHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = []([[maybe_unused]] const VFSHostPtr &_parent,
                           const VFSConfiguration &_config,
                           [[maybe_unused]] VFSCancelChecker _cancel_checker) {
        return std::make_shared<DropboxHost>(_config);
    };
    return m;
}

VFSConfiguration DropboxHost::Configuration() const
{
    return m_Config;
}

NSURLSession *DropboxHost::GenericSession() const
{
    return I->m_GenericSession;
}

NSURLSessionConfiguration *DropboxHost::GenericConfiguration()
{
    return NSURLSessionConfiguration.defaultSessionConfiguration;
}

void DropboxHost::FillAuth(NSMutableURLRequest *_request) const
{
    [_request setValue:I->m_AuthString forHTTPHeaderField:@"Authorization"];
}

std::expected<VFSStatFS, Error> DropboxHost::StatFS([[maybe_unused]] std::string_view _path,
                                                    const VFSCancelChecker &_cancel_checker)
{
    NSMutableURLRequest *const req = [[NSMutableURLRequest alloc] initWithURL:api::GetSpaceUsage];
    auto [rc, data] = SendSynchronousPostRequest(req, _cancel_checker);
    if( rc == VFSError::Ok ) {
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return std::unexpected(VFSError::ToError(VFSError::GenericError));
        auto &json = *json_opt;

        // TODO: wrap with checks
        auto used = json["used"].GetInt64();
        auto allocated = json["allocation"]["allocated"].GetInt64();

        VFSStatFS stat;
        stat.total_bytes = allocated;
        stat.free_bytes = allocated - used;
        stat.avail_bytes = stat.free_bytes;
        stat.volume_name = I->m_AccountInfo.email;
        return stat;
    }

    return std::unexpected(VFSError::ToError(rc));
}

std::expected<VFSStat, Error> DropboxHost::Stat(std::string_view _path,
                                                [[maybe_unused]] unsigned long _flags,
                                                const VFSCancelChecker &_cancel_checker)
{
    if( _path.empty() || _path[0] != '/' )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    VFSStat st;

    if( _path == "/" ) {
        // special treatment for root dir
        st.mode = DirectoryAccessMode;
        st.meaning.mode = true;
        return st;
    }

    std::string path = std::string(_path);
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    NSMutableURLRequest *const req = [[NSMutableURLRequest alloc] initWithURL:api::GetMetadata];
    InsertHTTPBodyPathspec(req, path);

    auto [rc, data] = SendSynchronousPostRequest(req, _cancel_checker);
    if( rc == VFSError::Ok ) {
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return std::unexpected(Error{Error::POSIX, EINVAL});
        auto &json = *json_opt;

        auto md = ParseMetadata(json);
        if( md.name.empty() )
            return std::unexpected(Error{Error::POSIX, EINVAL});

        st.mode = md.is_directory ? DirectoryAccessMode : RegularFileAccessMode;
        st.meaning.mode = true;

        if( md.size >= 0 ) {
            st.size = md.size;
            st.meaning.size = true;
        }

        if( md.chg_time >= 0 ) {
            st.ctime.tv_sec = md.chg_time;
            st.btime = st.mtime = st.ctime;
            st.meaning.ctime = st.meaning.btime = st.meaning.mtime = true;
        }

        return st;
    }
    return std::unexpected(VFSError::ToError(rc));
}

std::expected<void, Error>
DropboxHost::IterateDirectoryListing(std::string_view _path,
                                     const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    if( !_path.starts_with("/") )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    std::string path = std::string(_path);
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    std::string cursor_token;
    do {
        NSMutableURLRequest *const req =
            [[NSMutableURLRequest alloc] initWithURL:cursor_token.empty() ? api::ListFolder : api::ListFolderContinue];
        if( cursor_token.empty() )
            InsertHTTPBodyPathspec(req, path);
        else
            InsertHTTPBodyCursor(req, cursor_token);

        auto [rc, data] = SendSynchronousPostRequest(req);
        if( rc != VFSError::Ok )
            return std::unexpected(VFSError::ToError(rc));

        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return std::unexpected(Error{Error::POSIX, EINVAL});
        auto &json = *json_opt;

        auto entries = json.FindMember("entries");
        if( entries != json.MemberEnd() ) {
            for( int i = 0, e = entries->value.Size(); i != e; ++i ) {
                auto &entry = entries->value[i];

                auto metadata = ParseMetadata(entry);
                if( !metadata.name.empty() ) {
                    VFSDirEnt dirent;
                    dirent.type = metadata.is_directory ? VFSDirEnt::Dir : VFSDirEnt::Reg;
                    strcpy(dirent.name, metadata.name.c_str());
                    dirent.name_len = uint16_t(metadata.name.length());
                    const bool goon = _handler(dirent);
                    if( !goon )
                        return std::unexpected(Error{Error::POSIX, ECANCELED});
                }
            }
        }

        cursor_token.clear();
        const auto has_more = json.FindMember("has_more");
        if( has_more != json.MemberEnd() && has_more->value.IsBool() && has_more->value.GetBool() ) {
            const auto cursor = json.FindMember("cursor");
            if( cursor != json.MemberEnd() && cursor->value.IsString() ) {
                cursor_token = cursor->value.GetString();
            }
        }
    } while( not cursor_token.empty() );

    return {};
}

std::expected<VFSListingPtr, Error> DropboxHost::FetchDirectoryListing(std::string_view _path,
                                                                       unsigned long _flags,
                                                                       const VFSCancelChecker &_cancel_checker)
{
    if( !_path.starts_with("/") )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    std::string path = std::string(_path);
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    std::string cursor_token;
    using nc::base::variable_container;

    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(std::string(_path));
    listing_source.sizes.reset(variable_container<>::type::sparse);
    listing_source.atimes.reset(variable_container<>::type::sparse);
    listing_source.btimes.reset(variable_container<>::type::sparse);
    listing_source.ctimes.reset(variable_container<>::type::sparse);
    listing_source.mtimes.reset(variable_container<>::type::sparse);
    int listing_index = 0;
    if( !(_flags & VFSFlags::F_NoDotDot) && !path.empty() ) {
        listing_source.filenames.emplace_back("..");
        listing_source.unix_modes.emplace_back(DirectoryAccessMode);
        listing_source.unix_types.emplace_back(DT_DIR);
        listing_index++;
    }

    do {

        NSMutableURLRequest *const req =
            [[NSMutableURLRequest alloc] initWithURL:cursor_token.empty() ? api::ListFolder : api::ListFolderContinue];
        if( cursor_token.empty() )
            InsertHTTPBodyPathspec(req, path);
        else
            InsertHTTPBodyCursor(req, cursor_token);

        auto [rc, data] = SendSynchronousPostRequest(req, _cancel_checker);
        if( rc != VFSError::Ok )
            return std::unexpected(VFSError::ToError(rc));

        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return std::unexpected(Error{Error::POSIX, EINVAL});
        auto &json = *json_opt;

        auto entries = ExtractMetadataEntries(json);
        for( auto &e : entries ) {
            listing_source.filenames.emplace_back(e.name);
            listing_source.unix_modes.emplace_back(e.is_directory ? DirectoryAccessMode : RegularFileAccessMode);
            listing_source.unix_types.emplace_back(e.is_directory ? DT_DIR : DT_REG);
            if( e.size >= 0 )
                listing_source.sizes.insert(listing_index, e.size);
            if( e.chg_time >= 0 ) {
                listing_source.btimes.insert(listing_index, e.chg_time);
                listing_source.ctimes.insert(listing_index, e.chg_time);
                listing_source.mtimes.insert(listing_index, e.chg_time);
            }
            listing_index++;
        }

        cursor_token.clear();
        const auto has_more = json.FindMember("has_more");
        if( has_more != json.MemberEnd() && has_more->value.IsBool() && has_more->value.GetBool() ) {
            const auto cursor = json.FindMember("cursor");
            if( cursor != json.MemberEnd() && cursor->value.IsString() ) {
                cursor_token = cursor->value.GetString();
            }
        }
    } while( not cursor_token.empty() );

    return VFSListing::Build(std::move(listing_source));
}

std::expected<std::shared_ptr<VFSFile>, Error> DropboxHost::CreateFile(std::string_view _path,
                                                                       const VFSCancelChecker &_cancel_checker)
{
    auto file = std::make_shared<File>(_path, SharedPtr());
    if( _cancel_checker && _cancel_checker() )
        return std::unexpected(Error{Error::POSIX, ECANCELED});
    return file;
}

const std::string &DropboxHost::Token() const
{
    return I->m_Token;
}

std::expected<void, Error> DropboxHost::Unlink(std::string_view _path, const VFSCancelChecker &_cancel_checker)
{
    if( !_path.starts_with("/") )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    NSMutableURLRequest *const req = [[NSMutableURLRequest alloc] initWithURL:api::Delete];
    InsertHTTPBodyPathspec(req, _path);

    auto [rc, data] = SendSynchronousPostRequest(req, _cancel_checker);
    if( rc == VFSError::Ok )
        return {};

    return std::unexpected(VFSError::ToError(rc));
}

std::expected<void, Error> DropboxHost::RemoveDirectory(std::string_view _path, const VFSCancelChecker &_cancel_checker)
{
    if( !_path.starts_with("/") )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    std::string path = std::string(_path);
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    NSMutableURLRequest *const req = [[NSMutableURLRequest alloc] initWithURL:api::Delete];
    InsertHTTPBodyPathspec(req, path);

    auto [rc, data] = SendSynchronousPostRequest(req, _cancel_checker);
    if( rc == VFSError::Ok )
        return {};

    return std::unexpected(VFSError::ToError(rc));
}

std::expected<void, Error> DropboxHost::CreateDirectory(std::string_view _path,
                                                        [[maybe_unused]] int _mode,
                                                        const VFSCancelChecker &_cancel_checker)
{
    if( !_path.starts_with("/") )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    std::string path = std::string(_path);
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    NSMutableURLRequest *const req = [[NSMutableURLRequest alloc] initWithURL:api::CreateFolder];
    InsertHTTPBodyPathspec(req, path);

    auto [rc, data] = SendSynchronousPostRequest(req, _cancel_checker);
    if( rc == VFSError::Ok )
        return {};

    return std::unexpected(VFSError::ToError(rc));
}

bool DropboxHost::IsWritable() const
{
    return true;
}

std::expected<void, Error>
DropboxHost::Rename(std::string_view _old_path, std::string_view _new_path, const VFSCancelChecker &_cancel_checker)
{
    if( !_old_path.starts_with("/") || !_new_path.starts_with("/") )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    const std::string old_path = EnsureNoTrailingSlash(std::string(_old_path));
    const std::string new_path = EnsureNoTrailingSlash(std::string(_new_path));

    NSMutableURLRequest *const req = [[NSMutableURLRequest alloc] initWithURL:api::Move];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    const std::string path_spec = "{ "s + R"("from_path": ")" + EscapeString(old_path) + "\", " + R"("to_path": ")" +
                                  EscapeString(new_path) + "\"" + " }";
    [req setHTTPBody:[NSData dataWithBytes:data(path_spec) length:size(path_spec)]];

    auto [rc, data] = SendSynchronousPostRequest(req, _cancel_checker);
    if( rc == VFSError::Ok )
        return {};

    return std::unexpected(VFSError::ToError(rc));
}

const std::string &DropboxHost::Account() const
{
    return I->m_Account;
}

bool DropboxHost::IsCaseSensitiveAtPath([[maybe_unused]] std::string_view _dir) const
{
    return false;
}

std::pair<int, NSData *> DropboxHost::SendSynchronousPostRequest(NSMutableURLRequest *_request,
                                                                 const VFSCancelChecker &_cancel_checker)
{
    _request.HTTPMethod = @"POST";
    [_request setValue:I->m_AuthString forHTTPHeaderField:@"Authorization"];

    const auto [_1st_errc, _1st_data] = SendSynchronousRequest(GenericSession(), _request, _cancel_checker);
    if( _1st_errc == VFSError::Ok )
        return {_1st_errc, _1st_data};

    if( _1st_errc == VFSError::FromErrno(EAUTH) && !I->m_RefreshToken.empty() ) {
        Log::Info("Got 401 - trying to refresh an access token");
        // Handle HTTP 401 - try to regen our short-lived access token if possible
        const auto [refresh_errc, access_token] = RetreiveAccessTokenFromRefreshToken(I->m_RefreshToken);
        if( refresh_errc != VFSError::Ok ) {
            Log::Warn("Failed to refresn an access token");
            // failed to refresh - give up
            return {_1st_errc, _1st_data};
        }
        Log::Info("Successfully refreshed an access token");
        SetAccessToken(access_token);
    }
    else {
        // something else is wrong or our refresh token was revoked - give up
        return {_1st_errc, _1st_data};
    }

    // try again, but with a renewed access token
    [_request setValue:I->m_AuthString forHTTPHeaderField:@"Authorization"];
    return SendSynchronousRequest(GenericSession(), _request, _cancel_checker);
}

std::shared_ptr<const DropboxHost> DropboxHost::SharedPtr() const noexcept
{
    return std::static_pointer_cast<const DropboxHost>(Host::SharedPtr());
}

std::shared_ptr<DropboxHost> DropboxHost::SharedPtr() noexcept
{
    return std::static_pointer_cast<DropboxHost>(Host::SharedPtr());
}

} // namespace nc::vfs
