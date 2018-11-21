// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Requests.h"
#include "WebDAVHost.h"
#include <boost/algorithm/string/split.hpp>
#include <Habanero/algo.h>
#include <pugixml/pugixml.hpp>
#include "DateTimeParser.h"
#include "ConnectionsPool.h"
#include "PathRoutines.h"
#include <CFNetwork/CFNetworkErrors.h>

namespace nc::vfs::webdav {
    
using namespace std::literals;
    
struct CURLInputStringContext
{
    CURLInputStringContext(){};
    CURLInputStringContext(const std::string &_str):data(_str){};
    CURLInputStringContext(const char   *_str):data(_str){};

    std::string_view data;
    ssize_t offset = 0;
    
    static size_t Read(void *_buf, size_t _size, size_t _nmemb, void *_userp)
    {
        auto &context = *(CURLInputStringContext*)_userp;
        const auto to_read = std::min( context.data.size() - context.offset, _size * _nmemb );
        memcpy( _buf, context.data.data() + context.offset, to_read );
        context.offset += to_read;
        return to_read;
    }
    
    static int Seek(void *_userp, curl_off_t _offset, int _origin)
    {
        auto &context = *(CURLInputStringContext*)_userp;
        if( _origin == SEEK_SET ) {
            if( _offset >= 0 && _offset <= (ssize_t)context.data.size() ) {
                context.offset = _offset;
                return CURL_SEEKFUNC_OK;
            }
        }
        if( _origin == SEEK_CUR ) {
            const auto pos = context.offset + _offset;
            if( pos >= 0 && pos <= (ssize_t)context.data.size() ) {
                context.offset = pos;
                return CURL_SEEKFUNC_OK;
            }
        }
        if( _origin == SEEK_END ) {
            const auto pos = (ssize_t)context.data.size() + _offset;
            if( pos >= 0 && pos <= (ssize_t)context.data.size() ) {
                context.offset = pos;
                return CURL_SEEKFUNC_OK;
            }
        }
        return CURL_SEEKFUNC_CANTSEEK;
    }
};

static bool IsOkHTTPRC( const int _rc )
{
    return _rc >= 200 & _rc < 300;
}

static size_t CURLWriteDataIntoString(void *buffer, size_t size, size_t nmemb, void *userp)
{
    const auto sz = size * nmemb;
    auto &str = *(std::string*)userp;
    str.insert( str.size(), (const char *)buffer, sz );
    return sz;
}

static HTTPRequests::Mask ParseSupportedRequests( const std::string &_options_response_header )
{
    std::vector<std::string> lines;
    boost::split(lines, _options_response_header,
                 [](char _c){ return _c == '\r' || _c == '\n'; }, boost::token_compress_on);

    HTTPRequests::Mask mask = HTTPRequests::None;
    
    static const auto allowed_prefix = "Allow: "s;
    const auto allowed = find_if(begin(lines), end(lines), [](const auto &_line){
        return has_prefix(_line, allowed_prefix);
    });
    if( allowed != end(lines) ) {
        const auto requests_set = allowed->substr( allowed_prefix.size() );
        std::vector<std::string> requests;
        boost::split(requests, requests_set,
                     [](char _c){ return _c == ',' || _c == ' '; },
                     boost::token_compress_on);
        for( const auto &request: requests ) {
            if( request == "GET" )          mask |= HTTPRequests::Get;
            if( request == "HEAD" )         mask |= HTTPRequests::Head;
            if( request == "POST" )         mask |= HTTPRequests::Post;
            if( request == "PUT" )          mask |= HTTPRequests::Put;
            if( request == "DELETE" )       mask |= HTTPRequests::Delete;
            if( request == "CONNECT" )      mask |= HTTPRequests::Connect;
            if( request == "OPTIONS" )      mask |= HTTPRequests::Options;
            if( request == "TRACE" )        mask |= HTTPRequests::Trace;
            if( request == "COPY" )         mask |= HTTPRequests::Copy;
            if( request == "LOCK" )         mask |= HTTPRequests::Lock;
            if( request == "MKCOL" )        mask |= HTTPRequests::Mkcol;
            if( request == "MOVE" )         mask |= HTTPRequests::Move;
            if( request == "PROPFIND" )     mask |= HTTPRequests::PropFind;
            if( request == "PROPPATCH" )    mask |= HTTPRequests::PropPatch;
            if( request == "UNLOCK" )       mask |= HTTPRequests::Unlock;
        }
    }

    return mask;
}

std::pair<int, HTTPRequests::Mask> RequestServerOptions(const HostConfiguration& _options,
                                                        Connection &_connection )
{
    const auto curl = _connection.EasyHandle();
    
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "OPTIONS");
    curl_easy_setopt(curl, CURLOPT_URL, _options.full_url.c_str());
    std::string response;
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, CURLWriteDataIntoString);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    std::string headers;
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, CURLWriteDataIntoString);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, &headers);

    const auto curl_rc = curl_easy_perform(curl);
    const auto http_rc = curl_easy_get_response_code(curl);
    if( curl_rc == CURLE_OK && IsOkHTTPRC(http_rc) ) {
        const auto requests = ParseSupportedRequests(headers);
        return {VFSError::Ok, requests};
    }
    else {
        return {ToVFSError(curl_rc, http_rc), HTTPRequests::None};
    }
}

static time_t ParseModDate( const char *_date_time )
{
    if( const auto t = DateTimeFromRFC1123(_date_time); t >= 0 )
        return t;
    if( const auto t = DateTimeFromRFC850(_date_time); t >= 0 )
        return t;
    return DateTimeFromASCTime(_date_time);
}

static std::optional<PropFindResponse> ParseResponseNode( pugi::xml_node _node )
{
    using namespace pugi;
    static const auto href_query    = xpath_query{ "./*[local-name()='href']" };
    static const auto len_query     = xpath_query{ "./*/*/*[local-name()='getcontentlength']" };
    static const auto restype_query = xpath_query{ "./*/*/*[local-name()='resourcetype']" };    
    static const auto credate_query = xpath_query{ "./*/*/*[local-name()='creationdate']" };
    static const auto moddate_query = xpath_query{ "./*/*/*[local-name()='getlastmodified']" };
    
    PropFindResponse response;
    
    if( const auto href = _node.select_node(href_query) )
        if( const auto c = href.node().first_child() )
            if( const auto v = c.value() )
                response.filename = URIUnescape(v);
    if( response.filename.empty() )
        return std::nullopt;

    if( const auto len = _node.select_node(len_query) )
        if( const auto c = len.node().first_child() )
            if( const auto v = c.value() )
                response.size = atol(v);
    
    if( const auto res = _node.select_node(restype_query) )
        if( const auto c = res.node().first_child() )
            if( strstr(c.name(), "collection") )
                response.is_directory = true;
    
    if( const auto credate = _node.select_node(credate_query) )
        if( const auto c = credate.node().first_child() )
            if( const auto v = c.value() )
                if( const auto t = DateTimeFromRFC3339(v);  t >= 0 )
                    response.creation_date = t;
    
    if( const auto modddate = _node.select_node(moddate_query) )
        if( const auto c = modddate.node().first_child() )
            if( const auto v = c.value() )
                if(const auto t = ParseModDate(v);  t >= 0 )
                    response.modification_date = t;

    return std::optional<PropFindResponse>{ std::move(response) };
}

static std::vector<PropFindResponse> ParseDAVListing( const std::string &_xml_listing )
{
    using namespace pugi;

    xml_document doc;
    xml_parse_result result = doc.load_string( _xml_listing.c_str() );
    if( !result )
        return {};

    std::vector<PropFindResponse> items;
    const auto response_nodes = doc.select_nodes("/*/*[local-name()='response']");
    for( const auto &response: response_nodes )
        if( auto item = ParseResponseNode(response.node()) )
            items.emplace_back( std::move(*item) );
    
    return items;
}

static std::vector<PropFindResponse> PruneFilepaths(std::vector<PropFindResponse> _items,
                                                    const std::string &_base_path)
{
    if( _base_path.front() != '/' || _base_path.back() != '/' )
        throw std::invalid_argument("PruneFilepaths need a path with heading and trailing slashes");
    
    const auto base_path_len = _base_path.length();
    _items.erase(remove_if(begin(_items), end(_items), [&](auto &_item){
            if( !has_prefix(_item.filename, _base_path ) )
                return true;

            _item.filename.erase(0, base_path_len);
        
            if( _item.filename.empty() ) {
                _item.filename = "..";
            }
            else if( _item.filename.back() == '/' ) {
                if( !_item.is_directory )
                    return true;
                _item.filename.pop_back();
            }
        
            _item.filename = _item.filename;
     
            return false;
    }), end(_items));
    return _items;
}

[[maybe_unused]]
// macOS server doesn't prefix filepaths with "webdav" prefix, but I didn't manage to get it
// to work properly anyway. Maybe later.
static bool FilepathsHavePathPrefix(const std::vector<PropFindResponse> &_items,
                                    const std::string &_path)
{
    if( _path.empty() )
        return false;
    
    const auto base_path = "/" + _path;
    const auto server_uses_prefixes = all_of(begin(_items), end(_items), [&](const auto &_item){
        return has_prefix(_item.filename, base_path);
    });
    return server_uses_prefixes;
}

std::pair<int, std::vector<PropFindResponse>> RequestDAVListing(const HostConfiguration& _options,
                                                                Connection &_connection,
                                                                const std::string &_path )
{
    if( _path.back() != '/' )
        throw std::invalid_argument("FetchDAVListing: path must contain a trailing slash");

    const auto curl = _connection.EasyHandle();
    
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PROPFIND");
    
    static const auto headers = []{
        struct curl_slist *chunk = nullptr;
        chunk = curl_slist_append(chunk, "Depth: 1");
        chunk = curl_slist_append(chunk, "translate: f");
        chunk = curl_slist_append(chunk, "Content-Type: application/xml; charset=\"utf-8\"");
        return chunk;
    }();
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

    const auto url = URIForPath(_options, _path);
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());

    const auto g_PropfindMessage =
        "<?xml version=\"1.0\"?>"
        "<a:propfind xmlns:a=\"DAV:\">"
            "<a:prop>"
                "<a:resourcetype/>"
                "<a:getcontentlength/>"
                "<a:getlastmodified/>"
                "<a:creationdate/>"
            "</a:prop>"
        "</a:propfind>";
    CURLInputStringContext context{g_PropfindMessage};
    curl_easy_setopt(curl, CURLOPT_UPLOAD, 1L);
    curl_easy_setopt(curl, CURLOPT_READFUNCTION, CURLInputStringContext::Read);
    curl_easy_setopt(curl, CURLOPT_READDATA, &context);
    curl_easy_setopt(curl, CURLOPT_SEEKFUNCTION, CURLInputStringContext::Seek);
    curl_easy_setopt(curl, CURLOPT_SEEKDATA, &context);
    curl_easy_setopt(curl, CURLOPT_INFILESIZE_LARGE, context.data.size());
    
    std::string response;
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, CURLWriteDataIntoString);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);
    
    
    
//    string headers;
//    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, CURLWriteDataIntoString);
//    curl_easy_setopt(curl, CURLOPT_HEADERDATA, &headers);
    
    const auto curl_rc = curl_easy_perform(curl);
    const auto http_rc = curl_easy_get_response_code(curl);
    if( curl_rc == CURLE_OK && IsOkHTTPRC(http_rc) ) {
//        cout << headers << endl;
//        cout << response << endl;    
    
        auto items = ParseDAVListing(response);
        const auto use_prefix = true /* FilepathsHavePathPrefix(items, _options.path) */;
        const auto base_path = use_prefix ?
            ((_options.path.empty() ? "" :  "/" + _options.path) + _path) :
            _path;
        items = PruneFilepaths(move(items), base_path);
        return {VFSError::Ok, move(items)};
    }
    return {ToVFSError(curl_rc, http_rc), {}};
}

// free space, used space
static std::pair<long, long> ParseSpaceQouta( const std::string &_xml )
{
    using namespace pugi;

    xml_document doc;
    xml_parse_result result = doc.load_string( _xml.c_str() );
    if( !result )
        return {-1, -1};

    long free = -1;
    static const auto free_query = xpath_query{"./*/*/*/*/*[local-name()='quota-available-bytes']"};
    if( const auto href = doc.select_node(free_query) )
        if( const auto c = href.node().first_child() )
            if( const auto v = c.value() )
                free = atol(v);

    long used = -1;
    static const auto used_query = xpath_query{"./*/*/*/*/*[local-name()='quota-used-bytes']"};
    if( const auto href = doc.select_node(used_query) )
        if( const auto c = href.node().first_child() )
            if( const auto v = c.value() )
                used = atol(v);
    
    return {free, used};
}

std::tuple<int, long, long> RequestSpaceQuota(const HostConfiguration& _options,
                                              Connection &_connection )
{
    const auto g_QuotaMessage =
        "<?xml version=\"1.0\"?>"
        "<a:propfind xmlns:a=\"DAV:\">"
            "<a:prop>"
                "<a:quota-available-bytes/>"
                "<a:quota-used-bytes/>"
            "</a:prop>"
        "</a:propfind>";
    
    const auto curl = _connection.EasyHandle();
    
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PROPFIND");
    
    struct curl_slist *chunk = nullptr;
    chunk = curl_slist_append(chunk, "Depth: 0");
    chunk = curl_slist_append(chunk, "Content-Type: application/xml; charset=\"utf-8\"");
    const auto clear_chunk = at_scope_end([=]{ curl_slist_free_all(chunk); });
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, chunk);

    auto url = _options.full_url;
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());

    CURLInputStringContext context{g_QuotaMessage};
    curl_easy_setopt(curl, CURLOPT_UPLOAD, 1L);
    curl_easy_setopt(curl, CURLOPT_READFUNCTION, CURLInputStringContext::Read);
    curl_easy_setopt(curl, CURLOPT_READDATA, &context);
    curl_easy_setopt(curl, CURLOPT_SEEKFUNCTION, CURLInputStringContext::Seek);
    curl_easy_setopt(curl, CURLOPT_SEEKDATA, &context);
    curl_easy_setopt(curl, CURLOPT_INFILESIZE_LARGE, context.data.size());
    
    std::string response;
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, CURLWriteDataIntoString);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);

    const auto curl_rc = curl_easy_perform(curl);
    const auto http_rc = curl_easy_get_response_code(curl);
    if( curl_rc == CURLE_OK && IsOkHTTPRC(http_rc) ) {
        const auto [free, used] = ParseSpaceQouta(response);
        return {VFSError::Ok, free, used};
    }
    else
        return {ToVFSError(curl_rc, http_rc), -1, -1};
}

int RequestMKCOL(const HostConfiguration& _options,
                 Connection &_connection,
                 const std::string &_path )
{
    if( _path.back() != '/' )
        throw std::invalid_argument("RequestMKCOL: path must contain a trailing slash");

    const auto curl = _connection.EasyHandle();
    
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "MKCOL");
    
    struct curl_slist *chunk = nullptr;
    chunk = curl_slist_append(chunk, ("Host: "s + _options.server_url).c_str());
    const auto clear_chunk = at_scope_end([=]{ curl_slist_free_all(chunk); });
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, chunk);

    const auto url = URIForPath(_options, _path);
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    
    std::string response;
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, CURLWriteDataIntoString);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);

    const auto curl_rc = curl_easy_perform(curl);
    const auto http_rc = curl_easy_get_response_code(curl);
    if( curl_rc == CURLE_OK && IsOkHTTPRC(http_rc) )
        return VFSError::Ok;
    else
        return ToVFSError(curl_rc, http_rc);
}

int RequestDelete(const HostConfiguration& _options,
                  Connection &_connection,
                  const std::string &_path )
{
    if( _path == "/" )
        return VFSError::FromErrno(EPERM);
    
    const auto curl = _connection.EasyHandle();
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "DELETE");
    
    struct curl_slist *chunk = nullptr;
    chunk = curl_slist_append(chunk, ("Host: "s + _options.server_url).c_str());
    const auto clear_chunk = at_scope_end([=]{ curl_slist_free_all(chunk); });
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, chunk);

    const auto url = URIForPath(_options, _path);
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
    
    std::string response;
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, CURLWriteDataIntoString);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);

    const auto curl_rc = curl_easy_perform(curl);
    const auto http_rc = curl_easy_get_response_code(curl);
    if( curl_rc == CURLE_OK && IsOkHTTPRC(http_rc) )
        return VFSError::Ok;
    else
        return ToVFSError(curl_rc, http_rc);
}

int RequestMove(const HostConfiguration& _options,
                Connection &_connection,
                const std::string &_src,
                const std::string &_dst )
{
    if( _src == "/" )
        return VFSError::FromErrno(EPERM);

    const auto curl = _connection.EasyHandle();
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "MOVE");
    
    struct curl_slist *chunk = nullptr;
    chunk = curl_slist_append(chunk, ("Host: " + _options.server_url).c_str());
    chunk = curl_slist_append(chunk, ("Destination: " + URIForPath(_options, _dst)).c_str());
    const auto clear_chunk = at_scope_end([=]{ curl_slist_free_all(chunk); });
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, chunk);

    const auto url = URIForPath(_options, _src);
    curl_easy_setopt(curl, CURLOPT_URL, url.c_str());

    std::string response;
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, CURLWriteDataIntoString);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response);

    const auto curl_rc = curl_easy_perform(curl);
    const auto http_rc = curl_easy_get_response_code(curl);
    if( curl_rc == CURLE_OK && IsOkHTTPRC(http_rc) )
        return VFSError::Ok;
    else
        return ToVFSError(curl_rc, http_rc);
}

}
