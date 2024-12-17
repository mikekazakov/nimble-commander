// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Internals.h"
#include "Host.h"
#include <fmt/format.h>
#include <sys/stat.h>
#include <VFS/Log.h>

namespace nc::vfs::ftp {

size_t CURLWriteDataIntoString(void *buffer, size_t size, size_t nmemb, void *userp)
{
    Log::Trace("CURLWriteDataIntoString({}, {}, {}, {}) called", buffer, size, nmemb, userp);
    auto sz = size * nmemb;
    char *tmp = static_cast<char *>(alloca(sz + 1));
    memcpy(tmp, buffer, sz);
    tmp[sz] = 0;
    std::string *str = static_cast<std::string *>(userp);
    (*str) += tmp;

    return sz;
}

static int parse_dir_unix(const char *line, struct stat *sbuf, char *file, char *link)
{
    char mode[12];
    long nlink = 1;
    char user[33];
    char group[33];
    unsigned long long size;
    char month[4];
    char day[3];
    char year[6];
    char date[20];
    struct tm tm;
    time_t tt;
    int res;

    memset(file, 0, sizeof(char) * 1024);
    memset(&tm, 0, sizeof(tm));
    memset(&tt, 0, sizeof(tt));

#define SPACES "%*[ \t]"
    res = sscanf(line,
                 "%11s"
                 "%lu" SPACES "%32s" SPACES "%32s" SPACES "%llu" SPACES "%3s" SPACES "%2s" SPACES "%5s"
                 "%*c"
                 "%1023c",
                 mode,
                 &nlink,
                 user,
                 group,
                 &size,
                 month,
                 day,
                 year,
                 file);
    if( res < 9 ) {
        res = sscanf(line,
                     "%11s"
                     "%32s" SPACES "%32s" SPACES "%llu" SPACES "%3s" SPACES "%2s" SPACES "%5s"
                     "%*c"
                     "%1023c",
                     mode,
                     user,
                     group,
                     &size,
                     month,
                     day,
                     year,
                     file);
        if( res < 8 ) {
            return 0;
        }
    }
#undef SPACES

    char *link_marker = strstr(file, " -> ");
    if( link_marker ) {
        strcpy(link, link_marker + 4);
        *link_marker = '\0';
    }

    int i = 0;
    if( mode[i] == 'd' ) {
        sbuf->st_mode |= S_IFDIR;
    }
    else if( mode[i] == 'l' ) {
        sbuf->st_mode |= S_IFLNK;
    }
    else {
        sbuf->st_mode |= S_IFREG;
    }
    for( i = 1; i < 10; ++i ) {
        if( mode[i] != '-' ) {
            sbuf->st_mode |= 1 << (9 - i);
        }
    }

    sbuf->st_nlink = static_cast<nlink_t>(nlink);
    sbuf->st_size = size;

    *fmt::format_to(date, "{},{},{}", year, month, day) = 0;
    tt = time(nullptr);
    gmtime_r(&tt, &tm);
    tm.tm_sec = tm.tm_min = tm.tm_hour = 0;
    if( strchr(year, ':') ) {
        const int cur_mon = tm.tm_mon; // save current month
        strptime(date, "%H:%M,%b,%d", &tm);
        // Unix systems omit the year for the last six months
        if( cur_mon + 5 < tm.tm_mon ) { // month from last year
            tm.tm_year--;               // correct the year
        }
    }
    else {
        strptime(date, "%Y,%b,%d", &tm);
    }

    sbuf->st_atime = sbuf->st_ctime = sbuf->st_mtime = mktime(&tm);

    return 1;
}

static int parse_dir_win(const char *line, struct stat *sbuf, char *file, char *link)
{
    char date[9];
    char hour[8];
    char size[33];
    struct tm tm;
    time_t tt;
    int res;
    (void)link;

    memset(file, 0, sizeof(char) * 1024);
    memset(&tm, 0, sizeof(tm));
    memset(&tt, 0, sizeof(tt));

    res = sscanf(line, "%8s%*[ \t]%7s%*[ \t]%32s%*[ \t]%1023c", date, hour, size, file);
    if( res < 4 ) {
        return 0;
    }

    tt = time(nullptr);
    gmtime_r(&tt, &tm);
    tm.tm_sec = tm.tm_min = tm.tm_hour = 0;
    strptime(date, "%m-%d-%y", &tm);
    strptime(hour, "%I:%M%p", &tm);

    sbuf->st_atime = sbuf->st_ctime = sbuf->st_mtime = mktime(&tm);
    sbuf->st_nlink = 1;

    if( !strcmp(size, "<DIR>") ) {
        sbuf->st_mode |= S_IFDIR;
    }
    else {
        const unsigned long long nsize = strtoull(size, nullptr, 0);
        sbuf->st_mode |= S_IFREG;
        sbuf->st_size = nsize;
    }

    return 1;
}

std::shared_ptr<Directory> ParseListing(const char *_str)
{
    if( _str == nullptr )
        return nullptr;

    const char *line_start = _str;
    const char *line_end = nullptr;

    auto directory = std::make_shared<Directory>();
    auto &entries = directory->entries;

    static const auto current_line_sz = 4096;
    char current_line[current_line_sz];
    while( (line_end = strchr(line_start, '\n')) != nullptr ) {
        //      handle win-style newlines somehow:
        //        if (end > start && *(end-1) == '\r') end--;
        assert(line_end - line_start < current_line_sz);

        memcpy(current_line, line_start, line_end - line_start);
        current_line[line_end - line_start] = 0;

        struct stat st;
        memset(&st, 0, sizeof(st));
        char filename[2048];
        char link[2048];
        if( parse_dir_unix(current_line, &st, filename, link) || parse_dir_win(current_line, &st, filename, link) ) {
            if( strcmp(filename, ".") != 0 && strcmp(filename, "..") != 0 ) {
                entries.emplace_back();
                auto &ent = entries.back();
                ent.name = filename;
                ent.mode = st.st_mode;
                ent.size = st.st_size;
                ent.time = st.st_mtime;
            }
        }
        else {
            fmt::println("failed to parse: {}", current_line);
        }

        line_start = line_end + 1;
    }

    return directory;
}

CURLInstance::~CURLInstance()
{
    if( curl ) {
        curl_easy_cleanup(curl);
        curl = nullptr;
    }

    if( curlm )
        curl_multi_cleanup(curlm);
}

CURLcode CURLInstance::PerformEasy() const
{
    Log::Trace("CURLInstance::PerformEasy() called");
    assert(!IsAttached());
    return curl_easy_perform(curl);
}

CURLcode CURLInstance::PerformMulti() const
{
    int still_running = 0;
    do {
        CURLMcode mc;
        mc = curl_multi_perform(curlm, &still_running);
        if( mc == CURLM_OK ) {
            mc = curl_multi_wait(curlm, nullptr, 0, 10000, nullptr);
        }
        if( mc != CURLM_OK ) {
            Log::Error("curl_multi failed, code {}", std::to_underlying(mc));
            break;
        }
    } while( still_running );

    CURLcode result = CURLE_OK;

    // check for error codes here
    if( still_running == 0 ) {
        int msgs_left = 1;
        while( msgs_left ) {
            CURLMsg *msg = curl_multi_info_read(curlm, &msgs_left);
            if( msg == nullptr || msg->msg != CURLMSG_DONE || msg->data.result != CURLE_OK ) {
                if( msg )
                    result = msg->data.result;
            }
        }
    }
    return result;
}

CURLMcode CURLInstance::Attach()
{
    assert(!IsAttached());
    const CURLMcode e = curl_multi_add_handle(curlm, curl);
    if( e == CURLM_OK )
        attached = true;

    return e;
}

CURLMcode CURLInstance::Detach()
{
    assert(IsAttached());
    const CURLMcode e = curl_multi_remove_handle(curlm, curl);
    if( e == CURLM_OK )
        attached = false;
    return e;
}

int CURLInstance::ProgressCallback(void *clientp,
                                   curl_off_t dltotal,
                                   curl_off_t dlnow,
                                   curl_off_t ultotal,
                                   curl_off_t ulnow)
{
    CURLInstance *_this = static_cast<CURLInstance *>(clientp);
    return _this->prog_func ? _this->prog_func(dltotal, dlnow, ultotal, ulnow) : 0;
}

void CURLInstance::EasySetupProgFunc()
{
    EasySetOpt(CURLOPT_XFERINFOFUNCTION, ProgressCallback);
    EasySetOpt(CURLOPT_PROGRESSDATA, this);
    EasySetOpt(CURLOPT_NOPROGRESS, 0);
    prog_func = nil;
}

void CURLInstance::EasyClearProgFunc()
{
    EasySetOpt(CURLOPT_XFERINFOFUNCTION, nullptr);
    EasySetOpt(CURLOPT_PROGRESSDATA, nullptr);
    EasySetOpt(CURLOPT_NOPROGRESS, 1);
    prog_func = nil;
}

size_t ReadBuffer::Size() const noexcept
{
    return m_Buf.size();
}

const void *ReadBuffer::Data() const noexcept
{
    return m_Buf.data();
}

void ReadBuffer::Clear()
{
    m_Buf.clear();
}

size_t ReadBuffer::Write(const void *_src, size_t _size, size_t _nmemb, void *_this)
{
    assert(_this != nullptr);
    return static_cast<ReadBuffer *>(_this)->DoWrite(_src, _size, _nmemb);
}

size_t ReadBuffer::DoWrite(const void *_src, size_t _size, size_t _nmemb)
{
    Log::Trace("ReadBuffer::Write({}, {}, {}) called", _src, _size, _nmemb);
    const size_t bytes = _size * _nmemb;

    m_Buf.insert(m_Buf.end(), static_cast<const std::byte *>(_src), static_cast<const std::byte *>(_src) + bytes);

    return bytes;
}

void ReadBuffer::Discard(size_t _sz)
{
    Log::Trace("ReadBuffer::Discard({}) called", _sz);
    assert(_sz <= m_Buf.size());
    m_Buf.erase(m_Buf.begin(), std::next(m_Buf.begin(), _sz));
}

void WriteBuffer::Write(const void *_mem, size_t _size)
{
    Log::Trace("WriteBuffer::Write({}, {}) called", _mem, _size);
    m_Buf.insert(m_Buf.end(), static_cast<const std::byte *>(_mem), static_cast<const std::byte *>(_mem) + _size);
}

size_t WriteBuffer::Read(void *_dest, size_t size, size_t nmemb, void *_this)
{
    assert(_this != nullptr);
    return static_cast<WriteBuffer *>(_this)->DoRead(_dest, size, nmemb);
}

size_t WriteBuffer::DoRead(void *_dest, size_t _size, size_t _nmemb)
{
    Log::Trace("WriteBuffer::DoRead({}, {}, {}) called", _dest, _size, _nmemb);

    assert(m_Consumed <= m_Buf.size());
    const size_t feed = std::min(_size * _nmemb, m_Buf.size() - m_Consumed);
    std::memcpy(_dest, m_Buf.data() + m_Consumed, feed);
    m_Consumed += feed;
    assert(m_Consumed <= m_Buf.size());
    Log::Trace("WriteBuffer: fed {} bytes", feed);
    return feed;
}

void WriteBuffer::DiscardConsumed() noexcept
{
    Log::Trace("WriteBuffer::DiscardConsumed() called, m_Consumed={}", m_Consumed);
    assert(m_Consumed <= m_Buf.size());
    m_Buf.erase(m_Buf.begin(), std::next(m_Buf.begin(), m_Consumed));
    m_Consumed = 0;
}

size_t WriteBuffer::Size() const noexcept
{
    return m_Buf.size();
}

size_t WriteBuffer::Consumed() const noexcept
{
    return m_Consumed;
}

bool WriteBuffer::Exhausted() const noexcept
{
    assert(m_Consumed <= m_Buf.size());
    return m_Consumed == m_Buf.size();
}

int CURLErrorToVFSError(CURLcode _curle)
{
    using namespace VFSError;
    switch( _curle ) {
        case CURLE_LOGIN_DENIED:
            return NetFTPLoginDenied;
        case CURLE_URL_MALFORMAT:
            return NetFTPURLMalformat;
        case CURLE_FTP_WEIRD_SERVER_REPLY:
        case CURLE_FTP_WEIRD_PASS_REPLY:
        case CURLE_FTP_WEIRD_PASV_REPLY:
        case CURLE_FTP_WEIRD_227_FORMAT:
        case CURLE_FTP_COULDNT_USE_REST:
        case CURLE_FTP_COULDNT_RETR_FILE:
        case CURLE_FTP_COULDNT_SET_TYPE:
        case CURLE_QUOTE_ERROR:
        case CURLE_RANGE_ERROR:
        case CURLE_FTP_PORT_FAILED:
        case CURLE_BAD_CONTENT_ENCODING:
            return NetFTPServerProblem;
        case CURLE_COULDNT_RESOLVE_PROXY:
            return NetFTPCouldntResolveProxy;
        case CURLE_COULDNT_RESOLVE_HOST:
        case CURLE_FTP_CANT_GET_HOST:
            return NetFTPCouldntResolveHost;
        case CURLE_COULDNT_CONNECT:
            return NetFTPCouldntConnect;
        case CURLE_REMOTE_ACCESS_DENIED:
        case CURLE_UPLOAD_FAILED:
            return NetFTPAccessDenied;
        case CURLE_PARTIAL_FILE:
        case CURLE_FTP_BAD_DOWNLOAD_RESUME:
            return UnexpectedEOF;
        case CURLE_OPERATION_TIMEDOUT:
            return NetFTPOperationTimeout;
        case CURLE_SEND_ERROR:
        case CURLE_RECV_ERROR:
            return FromErrno(EIO);
        case CURLE_REMOTE_FILE_NOT_FOUND:
            return NotFound;
        case CURLE_SSL_CONNECT_ERROR:
        case CURLE_SSL_ENGINE_NOTFOUND:
        case CURLE_SSL_ENGINE_SETFAILED:
        case CURLE_SSL_CERTPROBLEM:
        case CURLE_SSL_CIPHER:
        case CURLE_SSL_CACERT:
        case CURLE_USE_SSL_FAILED:
            return NetFTPSSLFailure;
        default:
            return FromErrno(EIO);
    }
}

} // namespace nc::vfs::ftp
