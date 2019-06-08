// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/PathManip.h>
#include "../ListingInput.h"
#include "Aux.h"
#include "Host.h"
#include "File.h"
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
    
    const char *Tag() const
    {
        return DropboxHost::UniqueTag;
    }
    
    const char *Junction() const
    {
        return account.c_str();
    }
    
    bool operator==(const VFSNetDropboxHostConfiguration&_rhs) const
    {
        return account == _rhs.token && token == _rhs.token;
    }
    
    const char *VerboseJunction() const
    {
        return verbose.c_str();
    }
};

static VFSNetDropboxHostConfiguration Compose(const std::string &_account,
                                              const std::string &_token)
{
    VFSNetDropboxHostConfiguration config;
    config.account = _account;
    config.token = _token;
    config.verbose = "dropbox://"s + _account;
    return config;
}

struct DropboxHost::State
{
    std::string     m_Account;
    std::string     m_Token;
    NSString       *m_AuthString;
    NSURLSession   *m_GenericSession;
    AccountInfo     m_AccountInfo;
};

DropboxHost::DropboxHost( const std::string &_account, const std::string &_access_token ):
    Host("", nullptr, DropboxHost::UniqueTag),
    I(std::make_unique<State>()),
    m_Config{Compose(_account, _access_token)}
{
    Init();
}

DropboxHost::DropboxHost( const VFSConfiguration &_config ):
    Host("", nullptr, DropboxHost::UniqueTag),
    I(std::make_unique<State>()),
    m_Config(_config)
{
    Init();
}

void DropboxHost::Init()
{
    Construct(Config().account, Config().token);
    InitialAccountLookup();
    AddFeatures( HostFeatures::NonEmptyRmDir );
}

void DropboxHost::Construct(const std::string &_account, const std::string &_access_token)
{
    I->m_Account = _account;
    I->m_Token = _access_token;
    if( I->m_Token.empty() )
        throw VFSErrorException{VFSError::FromErrno(EINVAL)};
    
    I->m_GenericSession = [NSURLSession sessionWithConfiguration:
                           NSURLSessionConfiguration.defaultSessionConfiguration];
    I->m_AuthString = [NSString stringWithFormat:@"Bearer %s", I->m_Token.c_str()];
}

DropboxHost::~DropboxHost()
{
}

const VFSNetDropboxHostConfiguration &DropboxHost::Config() const
{
    return m_Config.Get<VFSNetDropboxHostConfiguration>();
}

void DropboxHost::InitialAccountLookup()
{
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::GetCurrentAccount];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req);
    if( rc == VFSError::Ok  ) {
        auto json = ParseJSON(data);
        if( !json )
            throw VFSErrorException( VFSError::FromErrno(EBADMSG) );
        I->m_AccountInfo = ParseAccountInfo(*json);
    }
    else
        throw VFSErrorException( rc );
}

std::pair<int, std::string> DropboxHost::
    CheckTokenAndRetrieveAccountEmail( const std::string &_token )
{
    const auto config = NSURLSessionConfiguration.defaultSessionConfiguration;
    const auto session = [NSURLSession sessionWithConfiguration:config];
    const auto auth_string = [NSString stringWithFormat:@"Bearer %s", _token.c_str()];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:api::GetCurrentAccount];
    request.HTTPMethod = @"POST";
    [request setValue:auth_string forHTTPHeaderField:@"Authorization"];
    auto [rc, data] = SendSynchronousRequest(session, request);
    if( rc == VFSError::Ok  ) {
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
                           const VFSConfiguration& _config,
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

NSURLSessionConfiguration *DropboxHost::GenericConfiguration() const
{
    return NSURLSessionConfiguration.defaultSessionConfiguration;
}

void DropboxHost::FillAuth( NSMutableURLRequest *_request ) const
{
    [_request setValue:I->m_AuthString forHTTPHeaderField:@"Authorization"];
}

int DropboxHost::StatFS([[maybe_unused]] const char *_path,
                        VFSStatFS &_stat,
                        const VFSCancelChecker &_cancel_checker)
{
    WarnAboutUsingInMainThread();
    
    _stat = VFSStatFS{};

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::GetSpaceUsage];
    req.HTTPMethod = @"POST";
    FillAuth(req);

    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    if( rc == VFSError::Ok ) {
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return VFSError::GenericError;
        auto &json = *json_opt;
        
        auto used = json["used"].GetInt64();
        auto allocated = json["allocation"]["allocated"].GetInt64();
        
        _stat.total_bytes = allocated;
        _stat.free_bytes = allocated - used;
        _stat.avail_bytes = _stat.free_bytes;
        _stat.volume_name = I->m_AccountInfo.email;
    }

    return rc;
}

int DropboxHost::Stat(const char *_path,
                      VFSStat &_st,
                      [[maybe_unused]] unsigned long _flags,
                      const VFSCancelChecker &_cancel_checker)
{
    WarnAboutUsingInMainThread();

    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
        memset( &_st, 0, sizeof(_st) );
    
    if( strcmp( _path, "/") == 0 ) {
        // special treatment for root dir
        _st.mode = DirectoryAccessMode;
        _st.meaning.mode = true;
        return 0;
    }
    
    std::string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::GetMetadata];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    if( rc == VFSError::Ok ) {
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return VFSError::GenericError;
        auto &json = *json_opt;

        
        auto md = ParseMetadata(json);
        if( md.name.empty() )
            return VFSError::GenericError;
        
        _st.mode = md.is_directory ? DirectoryAccessMode : RegularFileAccessMode;
        _st.meaning.mode = true;

        if( md.size >= 0 ) {
            _st.size = md.size;
            _st.meaning.size = true;
        }
        
        if( md.chg_time >= 0 ) {
            _st.ctime.tv_sec = md.chg_time;
            _st.btime = _st.mtime = _st.ctime;
            _st.meaning.ctime = _st.meaning.btime = _st.meaning.mtime = true;
        }
    }
    return rc;
}

int DropboxHost::IterateDirectoryListing(const char *_path,
                                         const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{ // TODO: process ListFolderResult.has_more
    WarnAboutUsingInMainThread();

  if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    std::string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::ListFolder];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req);
    
    if( rc == VFSError::Ok ) {
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return VFSError::GenericError;
        auto &json = *json_opt;
        
        auto entries = json.FindMember("entries");
        if( entries != json.MemberEnd() ) {
            for( int i = 0, e = entries->value.Size(); i != e; ++i ) {
                auto &entry = entries->value[i];

                auto metadata = ParseMetadata(entry);
                if( !metadata.name.empty() ) {
                    VFSDirEnt dirent;
                    dirent.type = metadata.is_directory ? VFSDirEnt::Dir : VFSDirEnt::Reg;
                    strcpy( dirent.name, metadata.name.c_str() );
                    dirent.name_len = uint16_t(metadata.name.length());
                    bool goon = _handler(dirent);
                    if( !goon )
                        return VFSError::Cancelled;
                }
            }
        }
    }
    
    return rc;
}

int DropboxHost::FetchDirectoryListing(const char *_path,
                                       std::shared_ptr<VFSListing> &_target,
                                       unsigned long _flags,
                                       const VFSCancelChecker &_cancel_checker)
{ // TODO: process ListFolderResult.has_more
    WarnAboutUsingInMainThread();

    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    std::string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::ListFolder];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    if( rc == VFSError::Ok  ) {
        auto json_opt = ParseJSON(data);
        if( !json_opt )
            return VFSError::GenericError;
        auto &json = *json_opt;
        
        auto entries = ExtractMetadataEntries(json);
        
        using nc::base::variable_container;
        ListingInput listing_source;
        listing_source.hosts[0] = shared_from_this();
        listing_source.directories[0] =  EnsureTrailingSlash(_path);
        listing_source.sizes.reset( variable_container<>::type::sparse );
        listing_source.atimes.reset( variable_container<>::type::sparse );
        listing_source.btimes.reset( variable_container<>::type::sparse );
        listing_source.ctimes.reset( variable_container<>::type::sparse );
        listing_source.mtimes.reset( variable_container<>::type::sparse );
    
        int index = 0;
        if( !(_flags & VFSFlags::F_NoDotDot) && path != "" ) {
            listing_source.filenames.emplace_back( ".." );
            listing_source.unix_modes.emplace_back( DirectoryAccessMode );
            listing_source.unix_types.emplace_back( DT_DIR );
            index++;
        }
    
        for( auto &e: entries ) {
            listing_source.filenames.emplace_back( e.name );
            listing_source.unix_modes.emplace_back( e.is_directory ?
                DirectoryAccessMode :
                RegularFileAccessMode );
            listing_source.unix_types.emplace_back( e.is_directory ? DT_DIR : DT_REG );
            if( e.size >= 0  )
                listing_source.sizes.insert( index, e.size );
            if( e.chg_time >= 0 ) {
                listing_source.btimes.insert( index, e.chg_time );
                listing_source.ctimes.insert( index, e.chg_time );
                listing_source.mtimes.insert( index, e.chg_time );
            }
            index++;
        }
    
        _target = VFSListing::Build(std::move(listing_source));
    }
    return rc;
}

int DropboxHost::CreateFile(const char* _path,
                            std::shared_ptr<VFSFile> &_target,
                            const VFSCancelChecker &_cancel_checker)
{
    auto file = std::make_shared<File>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

const std::string &DropboxHost::Token() const
{
    return I->m_Token;
}

int DropboxHost::Unlink(const char *_path, const VFSCancelChecker &_cancel_checker )
{
   WarnAboutUsingInMainThread();

    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::Delete];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, _path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    return rc;
}

int DropboxHost::RemoveDirectory(const char *_path, const VFSCancelChecker &_cancel_checker )
{
    WarnAboutUsingInMainThread();

    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    std::string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::Delete];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    return rc;
}

int DropboxHost::CreateDirectory(const char* _path,
                                 [[maybe_unused]] int _mode,
                                 const VFSCancelChecker &_cancel_checker )
{
    WarnAboutUsingInMainThread();
    
    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    std::string path = _path;
    if( path.back() == '/' ) // dropbox doesn't like trailing slashes
        path.pop_back();
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::CreateFolder];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    InsetHTTPBodyPathspec(req, path);
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    return rc;
}

bool DropboxHost::IsWritable() const
{
    return true;
}

int DropboxHost::Rename(const char *_old_path,
                              const char *_new_path,
                              const VFSCancelChecker &_cancel_checker)
{
    WarnAboutUsingInMainThread();

    if( !_old_path || _old_path[0] != '/' || !_new_path || _new_path[0] != '/' )
        return VFSError::InvalidCall;
    
    const std::string old_path = EnsureNoTrailingSlash(_old_path);
    const std::string new_path = EnsureNoTrailingSlash(_new_path);

    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:api::Move];
    req.HTTPMethod = @"POST";
    FillAuth(req);
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    const std::string path_spec = "{ "s +
        "\"from_path\": \"" + EscapeString(old_path) + "\", " +
        "\"to_path\": \"" + EscapeString(new_path) + "\"" +
         " }";
    [req setHTTPBody:[NSData dataWithBytes:data(path_spec) length:size(path_spec)]];
    
    auto [rc, data] = SendSynchronousRequest(GenericSession(), req, _cancel_checker);
    return rc;
}

const std::string &DropboxHost::Account() const
{
    return I->m_Account;
}
    
bool DropboxHost::IsCaseSensitiveAtPath([[maybe_unused]] const char *_dir) const
{
    return false;
}

}
