// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Internal.h"
#include "WebDAVHost.h"
#include <CFNetwork/CFNetworkErrors.h>

namespace nc::vfs::webdav {
    
const char *HostConfiguration::Tag() const
{
    return WebDAVHost::UniqueTag;
}
    
const char *HostConfiguration::Junction() const
{
    return server_url.c_str();
}
    
const char *HostConfiguration::VerboseJunction() const
{
    return verbose.c_str();
}
    
bool HostConfiguration::operator==(const HostConfiguration&_rhs) const
{
    return server_url == _rhs.server_url &&
            user       == _rhs.user &&
            passwd     == _rhs.passwd &&
            path       == _rhs.path &&
            port       == _rhs.port;
}

void HTTPRequests::Print( const Mask _mask )
{
    if( _mask == 0 )
        return;

    if( _mask & HTTPRequests::Get )         cout << "GET ";
    if( _mask & HTTPRequests::Head )        cout << "HEAD ";
    if( _mask & HTTPRequests::Post )        cout << "POST ";
    if( _mask & HTTPRequests::Put )         cout << "PUT ";
    if( _mask & HTTPRequests::Delete )      cout << "DELETE ";
    if( _mask & HTTPRequests::Connect )     cout << "CONNECT ";
    if( _mask & HTTPRequests::Options )     cout << "OPTIONS ";
    if( _mask & HTTPRequests::Trace )       cout << "TRACE " ;
    if( _mask & HTTPRequests::Copy )        cout << "COPY ";
    if( _mask & HTTPRequests::Lock )        cout << "LOCK ";
    if( _mask & HTTPRequests::Mkcol )       cout << "MKCOL ";
    if( _mask & HTTPRequests::Move )        cout << "MOVE ";
    if( _mask & HTTPRequests::PropFind )    cout << "PROPFIND ";
    if( _mask & HTTPRequests::PropPatch )   cout << "PROPPATCH ";
    if( _mask & HTTPRequests::Unlock )      cout << "UNLOCK ";
    cout << endl;
}

static bool IsOkHTTPRC( const int _rc )
{
    return _rc >= 200 & _rc < 300;
}

int ToVFSError( const int _curl_rc, const int _http_rc ) noexcept
{
    if( _curl_rc == CURLE_OK ) {
        if( IsOkHTTPRC(_http_rc) )
            return VFSError::Ok;
            
        switch( _http_rc ) {
            // TODO:: 3xx
            case 400:   return VFSError::FromErrno(EINVAL);
            case 401:   return VFSError::FromErrno(EAUTH);
            case 402:   return VFSError::FromErrno(EAUTH);
            case 403:   return VFSError::FromErrno(EACCES);
            case 404:   return VFSError::FromErrno(ENOENT);
            case 405:   return VFSError::FromErrno(ENODEV);
            case 406:   return VFSError::FromErrno(EINVAL);
            case 407:   return VFSError::FromErrno(ECONNREFUSED);
            case 408:   return VFSError::FromErrno(ETIMEDOUT);
            case 409:   return VFSError::FromErrno(EINVAL);
            case 410:   return VFSError::FromErrno(ENOENT);
            case 411:   return VFSError::FromErrno(EINVAL);
            case 412:   return VFSError::FromErrno(EINVAL);
            case 413:   return VFSError::FromErrno(EOVERFLOW);
            case 414:   return VFSError::FromErrno(ENAMETOOLONG);
            case 415:   return VFSError::FromErrno(EINVAL);
            case 416:   return VFSError::FromErrno(EINVAL);
            case 417:   return VFSError::FromErrno(EINVAL);
            case 421:   return VFSError::FromErrno(ECONNABORTED);
            case 422:   return VFSError::FromErrno(EINVAL);
            case 423:   return VFSError::FromErrno(EPERM);
            case 424:   return VFSError::FromErrno(EINVAL);
            case 428:   return VFSError::FromErrno(EINVAL);
            case 429:   return VFSError::FromErrno(EMFILE);
            case 431:   return VFSError::FromErrno(EOVERFLOW);
            case 507:   return VFSError::FromErrno(EDQUOT);
            case 508:   return VFSError::FromErrno(ELOOP);
            default:    return VFSError::FromErrno(EIO);
        }
    }
    else
        switch( _curl_rc ) {
            case CURLE_UNSUPPORTED_PROTOCOL:    return VFSError::FromErrno(EPROTO);
            case CURLE_FAILED_INIT:             return VFSError::FromErrno(ENODEV);
            case CURLE_URL_MALFORMAT:           return VFSError::FromErrno(EINVAL);
            case CURLE_NOT_BUILT_IN:            return VFSError::FromErrno(EPROTONOSUPPORT);
            case CURLE_COULDNT_RESOLVE_HOST:    return VFSError::FromErrno(EHOSTUNREACH);
            case CURLE_COULDNT_CONNECT:         return VFSError::FromErrno(EADDRNOTAVAIL);
            case CURLE_REMOTE_ACCESS_DENIED:    return VFSError::FromErrno(EACCES);
            case CURLE_OPERATION_TIMEDOUT:      return VFSError::FromErrno(ETIMEDOUT);
            case CURLE_ABORTED_BY_CALLBACK:     return VFSError::FromErrno(ECANCELED);
            case CURLE_BAD_FUNCTION_ARGUMENT:   return VFSError::FromErrno(EINVAL);
            case CURLE_INTERFACE_FAILED:        return VFSError::FromErrno(ENETDOWN);
            case CURLE_LOGIN_DENIED:            return VFSError::FromErrno(EAUTH);
            case CURLE_REMOTE_FILE_EXISTS:      return VFSError::FromErrno(EEXIST);
            case CURLE_SSL_CACERT:              return VFSError::FromCFNetwork(kCFURLErrorSecureConnectionFailed);
            default:                            return VFSError::FromErrno(EIO);
        }
}

int curl_easy_get_response_code(CURL *_handle)
{
    assert( _handle != nullptr );
    long code = 0;
    curl_easy_getinfo(_handle, CURLINFO_RESPONSE_CODE, &code);
    return (int)code;
}

}
