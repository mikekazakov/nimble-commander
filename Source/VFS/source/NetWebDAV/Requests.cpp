// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Requests.h"
#include "Connection.h"
#include "DateTimeParser.h"
#include "PathRoutines.h"
#include "ReadBuffer.h"
#include "WebDAVHost.h"
#include <Base/algo.h>
#include <CFNetwork/CFNetworkErrors.h>
#include <algorithm>
#include <pugixml/pugixml.hpp>

namespace nc::vfs::webdav {

using namespace std::literals;

static bool IsOkHTTPRC(const int _rc)
{
    return _rc >= 200 & _rc < 300;
}

static HTTPRequests::Mask ParseSupportedRequests(std::string_view _options_response_header)
{
    const std::vector<std::string> lines = base::SplitByDelimiters(_options_response_header, "\r\n");
    HTTPRequests::Mask mask = HTTPRequests::None;

    const std::string_view allowed_prefix = "Allow: ";
    const auto allowed =
        std::ranges::find_if(lines, [allowed_prefix](const auto &_line) { return _line.starts_with(allowed_prefix); });
    if( allowed != end(lines) ) {
        const auto requests_set = allowed->substr(allowed_prefix.size());
        const std::vector<std::string> requests = base::SplitByDelimiters(requests_set, ", ");
        for( const auto &request : requests ) {
            if( request == "GET" )
                mask |= HTTPRequests::Get;
            if( request == "HEAD" )
                mask |= HTTPRequests::Head;
            if( request == "POST" )
                mask |= HTTPRequests::Post;
            if( request == "PUT" )
                mask |= HTTPRequests::Put;
            if( request == "DELETE" )
                mask |= HTTPRequests::Delete;
            if( request == "CONNECT" )
                mask |= HTTPRequests::Connect;
            if( request == "OPTIONS" )
                mask |= HTTPRequests::Options;
            if( request == "TRACE" )
                mask |= HTTPRequests::Trace;
            if( request == "COPY" )
                mask |= HTTPRequests::Copy;
            if( request == "LOCK" )
                mask |= HTTPRequests::Lock;
            if( request == "MKCOL" )
                mask |= HTTPRequests::Mkcol;
            if( request == "MOVE" )
                mask |= HTTPRequests::Move;
            if( request == "PROPFIND" )
                mask |= HTTPRequests::PropFind;
            if( request == "PROPPATCH" )
                mask |= HTTPRequests::PropPatch;
            if( request == "UNLOCK" )
                mask |= HTTPRequests::Unlock;
        }
    }

    return mask;
}

std::pair<int, HTTPRequests::Mask> RequestServerOptions(const HostConfiguration &_options, Connection &_connection)
{
    _connection.SetCustomRequest("OPTIONS");
    _connection.SetURL(_options.full_url);

    const auto result = _connection.PerformBlockingRequest();

    if( result.vfs_error != VFSError::Ok )
        return {result.vfs_error, HTTPRequests::None};

    if( IsOkHTTPRC(result.http_code) ) {
        const auto header = _connection.ResponseHeader();
        const auto requests = ParseSupportedRequests(header);
        return {VFSError::Ok, requests};
    }
    else {
        return {HTTPRCToVFSError(result.http_code), HTTPRequests::None};
    }
}

static time_t ParseModDate(const char *_date_time)
{
    if( const auto t = DateTimeFromRFC1123(_date_time); t >= 0 )
        return t;
    if( const auto t = DateTimeFromRFC850(_date_time); t >= 0 )
        return t;
    return DateTimeFromASCTime(_date_time);
}

static std::optional<PropFindResponse> ParseResponseNode(pugi::xml_node _node)
{
    using namespace pugi;
    [[clang::no_destroy]] static const auto href_query = xpath_query{"./*[local-name()='href']"};
    [[clang::no_destroy]] static const auto len_query = xpath_query{"./*/*/*[local-name()='getcontentlength']"};
    [[clang::no_destroy]] static const auto restype_query = xpath_query{"./*/*/*[local-name()='resourcetype']"};
    [[clang::no_destroy]] static const auto credate_query = xpath_query{"./*/*/*[local-name()='creationdate']"};
    [[clang::no_destroy]] static const auto moddate_query = xpath_query{"./*/*/*[local-name()='getlastmodified']"};

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
                if( const auto t = DateTimeFromRFC3339(v); t >= 0 )
                    response.creation_date = t;

    if( const auto modddate = _node.select_node(moddate_query) )
        if( const auto c = modddate.node().first_child() )
            if( const auto v = c.value() )
                if( const auto t = ParseModDate(v); t >= 0 )
                    response.modification_date = t;

    return std::optional<PropFindResponse>{std::move(response)};
}

static std::vector<PropFindResponse> ParseDAVListing(const std::string &_xml_listing)
{
    using namespace pugi;

    xml_document doc;
    const xml_parse_result result = doc.load_string(_xml_listing.c_str());
    if( !result )
        return {};

    std::vector<PropFindResponse> items;
    const auto response_nodes = doc.select_nodes("/*/*[local-name()='response']");
    for( const auto &response : response_nodes )
        if( auto item = ParseResponseNode(response.node()) )
            items.emplace_back(std::move(*item));

    return items;
}

static std::vector<PropFindResponse> PruneFilepaths(std::vector<PropFindResponse> _items, const std::string &_base_path)
{
    if( _base_path.front() != '/' || _base_path.back() != '/' )
        throw std::invalid_argument("PruneFilepaths need a path with heading and trailing slashes");

    const auto base_path_len = _base_path.length();
    auto pred = [&](auto &_item) {
        if( !_item.filename.starts_with(_base_path) )
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
    };
    std::erase_if(_items, pred);
    return _items;
}

[[maybe_unused]]
// macOS server doesn't prefix filepaths with "webdav" prefix, but I didn't manage to get it
// to work properly anyway. Maybe later.
static bool FilepathsHavePathPrefix(const std::vector<PropFindResponse> &_items, const std::string &_path)
{
    if( _path.empty() )
        return false;

    const auto base_path = "/" + _path;
    const auto server_uses_prefixes =
        std::ranges::all_of(_items, [&](const auto &_item) { return _item.filename.starts_with(base_path); });
    return server_uses_prefixes;
}

std::pair<int, std::vector<PropFindResponse>>
RequestDAVListing(const HostConfiguration &_options, Connection &_connection, const std::string &_path)
{
    if( _path.back() != '/' )
        throw std::invalid_argument("FetchDAVListing: path must contain a trailing slash");

    _connection.SetCustomRequest("PROPFIND");

    _connection.SetHeader(std::initializer_list<std::string_view>{
        "Depth: 1", "translate: f", "Content-Type: application/xml; charset=\"utf-8\""});

    const auto url = URIForPath(_options, _path);
    _connection.SetURL(url);

    const auto g_PropfindMessage = "<?xml version=\"1.0\"?>"
                                   "<a:propfind xmlns:a=\"DAV:\">"
                                   "<a:prop>"
                                   "<a:resourcetype/>"
                                   "<a:getcontentlength/>"
                                   "<a:getlastmodified/>"
                                   "<a:creationdate/>"
                                   "</a:prop>"
                                   "</a:propfind>";
    _connection.SetBody(
        {reinterpret_cast<const std::byte *>(g_PropfindMessage), std::string_view(g_PropfindMessage).length()});

    const auto result = _connection.PerformBlockingRequest();
    if( result.vfs_error != VFSError::Ok )
        return {result.vfs_error, {}};

    if( IsOkHTTPRC(result.http_code) ) {
        const auto response = _connection.ResponseBody().ReadAllAsString();
        auto items = ParseDAVListing(response);
        // TODO: clarify use_prefix
        const auto use_prefix = true /* FilepathsHavePathPrefix(items, _options.path) */;
        const auto base_path = use_prefix ? ((_options.path.empty() ? "" : "/" + _options.path) + _path) : _path;
        items = PruneFilepaths(std::move(items), base_path);
        return {VFSError::Ok, std::move(items)};
    }
    else {
        return {HTTPRCToVFSError(result.http_code), {}};
    }
}

// free space, used space
static std::pair<long, long> ParseSpaceQouta(const std::string &_xml)
{
    using namespace pugi;

    xml_document doc;
    const xml_parse_result result = doc.load_string(_xml.c_str());
    if( !result )
        return {-1, -1};

    long free = -1;
    [[clang::no_destroy]] static const auto free_query =
        xpath_query{"./*/*/*/*/*[local-name()='quota-available-bytes']"};
    if( const auto href = doc.select_node(free_query) )
        if( const auto c = href.node().first_child() )
            if( const auto v = c.value() )
                free = atol(v);

    long used = -1;
    [[clang::no_destroy]] static const auto used_query = xpath_query{"./*/*/*/*/*[local-name()='quota-used-bytes']"};
    if( const auto href = doc.select_node(used_query) )
        if( const auto c = href.node().first_child() )
            if( const auto v = c.value() )
                used = atol(v);

    return {free, used};
}

std::tuple<int, long, long> RequestSpaceQuota(const HostConfiguration &_options, Connection &_connection)
{
    const auto g_QuotaMessage = "<?xml version=\"1.0\"?>"
                                "<a:propfind xmlns:a=\"DAV:\">"
                                "<a:prop>"
                                "<a:quota-available-bytes/>"
                                "<a:quota-used-bytes/>"
                                "</a:prop>"
                                "</a:propfind>";

    _connection.SetCustomRequest("PROPFIND");
    _connection.SetHeader(
        std::initializer_list<std::string_view>{"Depth: 0", "Content-Type: application/xml; charset=\"utf-8\""});
    _connection.SetURL(_options.full_url);

    _connection.SetBody(
        {reinterpret_cast<const std::byte *>(g_QuotaMessage), std::string_view(g_QuotaMessage).length()});

    const auto result = _connection.PerformBlockingRequest();
    if( result.vfs_error != VFSError::Ok )
        return {result.vfs_error, -1, -1};

    if( IsOkHTTPRC(result.http_code) ) {
        const auto response = _connection.ResponseBody().ReadAllAsString();
        const auto [free, used] = ParseSpaceQouta(response);
        return {VFSError::Ok, free, used};
    }
    else {
        return {HTTPRCToVFSError(result.http_code), -1, -1};
    }
}

int RequestMKCOL(const HostConfiguration &_options, Connection &_connection, const std::string &_path)
{
    if( _path.back() != '/' )
        throw std::invalid_argument("RequestMKCOL: path must contain a trailing slash");

    _connection.SetCustomRequest("MKCOL");

    const auto header_host = "Host: "s + _options.server_url;
    _connection.SetHeader(std::initializer_list<std::string_view>{header_host});

    const auto url = URIForPath(_options, _path);
    _connection.SetURL(url);

    const auto result = _connection.PerformBlockingRequest();
    if( result.vfs_error != VFSError::Ok )
        return result.vfs_error;
    else
        return HTTPRCToVFSError(result.http_code);
}

int RequestDelete(const HostConfiguration &_options, Connection &_connection, std::string_view _path)
{
    if( _path == "/" )
        return VFSError::FromErrno(EPERM);

    _connection.SetCustomRequest("DELETE");

    const auto header_host = "Host: "s + _options.server_url;
    _connection.SetHeader(std::initializer_list<std::string_view>{header_host});

    const auto url = URIForPath(_options, _path);
    _connection.SetURL(url);

    const auto result = _connection.PerformBlockingRequest();
    if( result.vfs_error != VFSError::Ok )
        return result.vfs_error;
    else
        return HTTPRCToVFSError(result.http_code);
}

int RequestMove(const HostConfiguration &_options,
                Connection &_connection,
                const std::string &_src,
                const std::string &_dst)
{
    if( _src == "/" )
        return VFSError::FromErrno(EPERM);

    _connection.SetCustomRequest("MOVE");

    const auto header_host = "Host: " + _options.server_url;
    const auto header_dest = "Destination: " + URIForPath(_options, _dst);
    _connection.SetHeader(std::initializer_list<std::string_view>{header_host, header_dest});

    const auto url = URIForPath(_options, _src);
    _connection.SetURL(url);

    const auto result = _connection.PerformBlockingRequest();
    if( result.vfs_error != VFSError::Ok )
        return result.vfs_error;
    else
        return HTTPRCToVFSError(result.http_code);
}

} // namespace nc::vfs::webdav
