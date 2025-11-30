// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Requests.h"
#include "Connection.h"
#include "DateTimeParser.h"
#include "PathRoutines.h"
#include "ReadBuffer.h"
#include "WebDAVHost.h"
#include "Internal.h"
#include <Base/algo.h>
#include <CFNetwork/CFNetworkErrors.h>
#include <algorithm>
#include <pugixml/pugixml.hpp>

namespace nc::vfs::webdav {

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

std::expected<HTTPRequests::Mask, Error> RequestServerOptions(const HostConfiguration &_options,
                                                              Connection &_connection)
{
    if( const std::expected<void, Error> rc = _connection.SetCustomRequest("OPTIONS"); !rc )
        return std::unexpected(rc.error());
    if( const std::expected<void, Error> rc = _connection.SetURL(_options.full_url); !rc )
        return std::unexpected(rc.error());

    const std::expected<int, Error> http_code = _connection.PerformBlockingRequest();

    if( !http_code )
        return std::unexpected(http_code.error());

    if( IsOkHTTPRC(*http_code) ) {
        const auto header = _connection.ResponseHeader();
        const auto requests = ParseSupportedRequests(header);
        return requests;
    }
    else {
        return std::unexpected(HTTPRCToError(*http_code).value_or(Error{Error::POSIX, EIO}));
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

std::expected<std::vector<PropFindResponse>, Error>
RequestDAVListing(const HostConfiguration &_options, Connection &_connection, const std::string &_path)
{
    if( _path.back() != '/' )
        throw std::invalid_argument("FetchDAVListing: path must contain a trailing slash");

    if( std::expected<void, Error> rc = _connection.SetCustomRequest("PROPFIND"); !rc )
        return std::unexpected(rc.error());

    const auto header = std::initializer_list<std::string_view>{
        "Depth: 1", "translate: f", "Content-Type: application/xml; charset=\"utf-8\""};
    if( std::expected<void, Error> rc = _connection.SetHeader(header); !rc )
        return std::unexpected(rc.error());

    const auto url = URIForPath(_options, _path);
    if( std::expected<void, Error> rc = _connection.SetURL(url); !rc )
        return std::unexpected(rc.error());

    const std::string_view g_PropfindMessage = "<?xml version=\"1.0\"?>"
                                               "<a:propfind xmlns:a=\"DAV:\">"
                                               "<a:prop>"
                                               "<a:resourcetype/>"
                                               "<a:getcontentlength/>"
                                               "<a:getlastmodified/>"
                                               "<a:creationdate/>"
                                               "</a:prop>"
                                               "</a:propfind>";
    if( std::expected<void, Error> rc = _connection.SetBody(
            {reinterpret_cast<const std::byte *>(g_PropfindMessage.data()), g_PropfindMessage.length()});
        !rc )
        return std::unexpected(rc.error());

    const std::expected<int, Error> http_code = _connection.PerformBlockingRequest();
    if( !http_code )
        return std::unexpected(http_code.error());

    if( IsOkHTTPRC(*http_code) ) {
        const auto response = _connection.ResponseBody().ReadAllAsString();
        auto items = ParseDAVListing(response);
        // TODO: clarify use_prefix
        const auto use_prefix = true /* FilepathsHavePathPrefix(items, _options.path) */;
        const auto base_path = use_prefix ? ((_options.path.empty() ? "" : "/" + _options.path) + _path) : _path;
        items = PruneFilepaths(std::move(items), base_path);
        return std::move(items);
    }
    else {
        return std::unexpected(HTTPRCToError(*http_code).value_or(Error{Error::POSIX, EIO}));
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

std::expected<SpaceQuota, Error> RequestSpaceQuota(const HostConfiguration &_options, Connection &_connection)
{
    const std::string_view g_QuotaMessage = "<?xml version=\"1.0\"?>"
                                            "<a:propfind xmlns:a=\"DAV:\">"
                                            "<a:prop>"
                                            "<a:quota-available-bytes/>"
                                            "<a:quota-used-bytes/>"
                                            "</a:prop>"
                                            "</a:propfind>";

    if( std::expected<void, Error> rc = _connection.SetCustomRequest("PROPFIND"); !rc )
        return std::unexpected(rc.error());

    const auto header =
        std::initializer_list<std::string_view>{"Depth: 0", "Content-Type: application/xml; charset=\"utf-8\""};
    if( std::expected<void, Error> rc = _connection.SetHeader(header); !rc )
        return std::unexpected(rc.error());

    if( std::expected<void, Error> rc = _connection.SetURL(_options.full_url); !rc )
        return std::unexpected(rc.error());

    if( std::expected<void, Error> rc =
            _connection.SetBody({reinterpret_cast<const std::byte *>(g_QuotaMessage.data()), g_QuotaMessage.length()});
        !rc )
        return std::unexpected(rc.error());

    const std::expected<int, Error> http_code = _connection.PerformBlockingRequest();
    if( !http_code )
        return std::unexpected(http_code.error());

    if( IsOkHTTPRC(*http_code) ) {
        const auto response = _connection.ResponseBody().ReadAllAsString();
        const auto [free, used] = ParseSpaceQouta(response);
        SpaceQuota sq;
        sq.free = free;
        sq.used = used;
        return sq;
    }
    else {
        return std::unexpected(HTTPRCToError(*http_code).value_or(Error{Error::POSIX, EIO}));
    }
}

std::expected<void, Error>
RequestMKCOL(const HostConfiguration &_options, Connection &_connection, const std::string &_path)
{
    using namespace std::literals;
    if( _path.back() != '/' )
        throw std::invalid_argument("RequestMKCOL: path must contain a trailing slash");

    if( std::expected<void, Error> rc = _connection.SetCustomRequest("MKCOL"); !rc )
        return std::unexpected(rc.error());

    const auto header_host = "Host: "s + _options.server_url;
    if( std::expected<void, Error> rc = _connection.SetHeader(std::initializer_list<std::string_view>{header_host});
        !rc )
        return std::unexpected(rc.error());

    const auto url = URIForPath(_options, _path);
    if( std::expected<void, Error> rc = _connection.SetURL(url); !rc )
        return std::unexpected(rc.error());

    const std::expected<int, Error> http_code = _connection.PerformBlockingRequest();
    if( !http_code )
        return std::unexpected(http_code.error());
    if( const std::optional<Error> err = HTTPRCToError(*http_code) )
        return std::unexpected(*err);

    return {};
}

std::expected<void, Error>
RequestDelete(const HostConfiguration &_options, Connection &_connection, std::string_view _path)
{
    using namespace std::literals;
    if( _path == "/" )
        return std::unexpected(Error{Error::POSIX, EPERM});

    if( std::expected<void, Error> rc = _connection.SetCustomRequest("DELETE"); !rc )
        return std::unexpected(rc.error());

    const auto header_host = "Host: "s + _options.server_url;
    if( std::expected<void, Error> rc = _connection.SetHeader(std::initializer_list<std::string_view>{header_host});
        !rc )
        return std::unexpected(rc.error());

    const auto url = URIForPath(_options, _path);
    if( std::expected<void, Error> rc = _connection.SetURL(url); !rc )
        return std::unexpected(rc.error());

    const std::expected<int, Error> http_code = _connection.PerformBlockingRequest();
    if( !http_code )
        return std::unexpected(http_code.error());
    if( const std::optional<Error> err = HTTPRCToError(*http_code) )
        return std::unexpected(*err);

    return {};
}

std::expected<void, Error> RequestMove(const HostConfiguration &_options,
                                       Connection &_connection,
                                       const std::string &_src,
                                       const std::string &_dst)
{
    if( _src == "/" )
        return std::unexpected(Error{Error::POSIX, EPERM});

    if( std::expected<void, Error> rc = _connection.SetCustomRequest("MOVE"); !rc )
        return std::unexpected(rc.error());

    const auto header_host = "Host: " + _options.server_url;
    const auto header_dest = "Destination: " + URIForPath(_options, _dst);
    if( std::expected<void, Error> rc =
            _connection.SetHeader(std::initializer_list<std::string_view>{header_host, header_dest});
        !rc )
        return std::unexpected(rc.error());

    const auto url = URIForPath(_options, _src);
    if( std::expected<void, Error> rc = _connection.SetURL(url); !rc )
        return std::unexpected(rc.error());

    const std::expected<int, Error> http_code = _connection.PerformBlockingRequest();
    if( !http_code )
        return std::unexpected(http_code.error());
    if( const std::optional<Error> err = HTTPRCToError(*http_code) )
        return std::unexpected(*err);

    return {};
}

} // namespace nc::vfs::webdav
