// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/stat.h>
#include "Internals.h"
#include "Host.h"

namespace nc::vfs::ftp {

size_t CURLWriteDataIntoString(void *buffer, size_t size, size_t nmemb, void *userp)
{
    auto sz = size * nmemb;
    char *tmp = (char*)alloca(sz+1);
    memcpy(tmp, buffer, sz);
    tmp[sz] = 0;
    
    //    printf("%s", tmp);

    string *str = (string*)userp;
    (*str) += tmp;
    
    return sz;
}

static int parse_dir_unix(const char *line,
                          struct stat *sbuf,
                          char *file,
                          char *link) {
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
    
    memset(file, 0, sizeof(char)*1024);
    memset(&tm, 0, sizeof(tm));
    memset(&tt, 0, sizeof(tt));
    
#define SPACES "%*[ \t]"
    res = sscanf(line,
                 "%11s"
                 "%lu"  SPACES
                 "%32s" SPACES
                 "%32s" SPACES
                 "%llu" SPACES
                 "%3s"  SPACES
                 "%2s"  SPACES
                 "%5s"  "%*c"
                 "%1023c",
                 mode, &nlink, user, group, &size, month, day, year, file);
    if (res < 9) {
        res = sscanf(line,
                     "%11s"
                     "%32s" SPACES
                     "%32s" SPACES
                     "%llu" SPACES
                     "%3s"  SPACES
                     "%2s"  SPACES
                     "%5s"  "%*c"
                     "%1023c",
                     mode, user, group, &size, month, day, year, file);
        if (res < 8) {
            return 0;
        }
    }
#undef SPACES
    
    char *link_marker = strstr(file, " -> ");
    if (link_marker) {
        strcpy(link, link_marker + 4);
        *link_marker = '\0';
    }
    
    int i = 0;
    if (mode[i] == 'd') {
        sbuf->st_mode |= S_IFDIR;
    } else if (mode[i] == 'l') {
        sbuf->st_mode |= S_IFLNK;
    } else {
        sbuf->st_mode |= S_IFREG;
    }
    for (i = 1; i < 10; ++i) {
        if (mode[i] != '-') {
            sbuf->st_mode |= 1 << (9 - i);
        }
    }
    
    sbuf->st_nlink = (nlink_t)nlink;
    
    sbuf->st_size = size;
    /*    if (ftpfs.blksize) {
     sbuf->st_blksize = ftpfs.blksize;
     sbuf->st_blocks =
     ((size + ftpfs.blksize - 1) & ~((unsigned long long) ftpfs.blksize - 1)) >> 9;
     }*/
    
    sprintf(date,"%s,%s,%s", year, month, day);
    tt = time(NULL);
    gmtime_r(&tt, &tm);
    tm.tm_sec = tm.tm_min = tm.tm_hour = 0;
    if(strchr(year, ':')) {
        int cur_mon = tm.tm_mon;  // save current month
        strptime(date, "%H:%M,%b,%d", &tm);
        // Unix systems omit the year for the last six months
        if (cur_mon + 5 < tm.tm_mon) {  // month from last year
            //            DEBUG(2, "correct year: cur_mon: %d, file_mon: %d\n", cur_mon, tm.tm_mon);
            tm.tm_year--;  // correct the year
        }
    } else {
        strptime(date, "%Y,%b,%d", &tm);
    }
    
    sbuf->st_atime = sbuf->st_ctime = sbuf->st_mtime = mktime(&tm);
    
    return 1;
}
    
static int parse_dir_win(const char *line,
                         struct stat *sbuf,
                         char *file,
                         char *link)
{
    char date[9];
    char hour[8];
    char size[33];
    struct tm tm;
    time_t tt;
    int res;
    (void)link;
        
    memset(file, 0, sizeof(char)*1024);
    memset(&tm, 0, sizeof(tm));
    memset(&tt, 0, sizeof(tt));
        
    res = sscanf(line, "%8s%*[ \t]%7s%*[ \t]%32s%*[ \t]%1023c",
                 date, hour, size, file);
    if (res < 4) {
        return 0;
    }
        
    
    tt = time(NULL);
    gmtime_r(&tt, &tm);
    tm.tm_sec = tm.tm_min = tm.tm_hour = 0;
    strptime(date, "%m-%d-%y", &tm);
    strptime(hour, "%I:%M%p", &tm);
        
    sbuf->st_atime = sbuf->st_ctime = sbuf->st_mtime = mktime(&tm);
    sbuf->st_nlink = 1;
        
    if (!strcmp(size, "<DIR>")) {
        sbuf->st_mode |= S_IFDIR;
    } else {
        unsigned long long nsize = strtoull(size, NULL, 0);
        sbuf->st_mode |= S_IFREG;
        sbuf->st_size = nsize;
    }
        
    return 1;
}

    
shared_ptr<Directory> ParseListing(const char *_str)
{
    if(_str == nullptr)
        return nullptr;
    
    const char *line_start = _str;
    const char *line_end = nullptr;
    
    auto directory = make_shared<Directory>();
    auto &entries = directory->entries;
    
    static const auto current_line_sz = 4096;
    char current_line[current_line_sz];
    while( (line_end = strchr(line_start, '\n')) != nullptr )
    {
        //      handle win-style newlines somehow:
        //        if (end > start && *(end-1) == '\r') end--;
        assert(line_end - line_start < current_line_sz);
        
        memcpy(current_line,
               line_start,
               line_end - line_start
               );
        current_line[line_end - line_start] = 0;
        
        struct stat st;
        memset(&st, 0, sizeof(st));
        char filename[MAXPATHLEN];
        char link[MAXPATHLEN];
        if(parse_dir_unix(current_line, &st, filename, link) ||
            parse_dir_win(current_line, &st, filename, link) )
        {
            if(strcmp(filename, ".") != 0 &&
               strcmp(filename, "..") != 0)
            {
                entries.emplace_back();
                auto &ent = entries.back();

                ent.name = filename;
                ent.cfname = CFStringCreateWithUTF8StdStringNoCopy(ent.name);
                if( !ent.cfname )
                    ent.cfname = CFStringCreateWithMacOSRomanStdStringNoCopy(ent.name);
                ent.mode = st.st_mode;
                ent.size = st.st_size;
                ent.time = st.st_mtime;
            }
        }
        else
        {
            printf("failed to parse: %s\n", current_line);
        }
 
        line_start = line_end + 1;
    }

    return directory;
}

CURLInstance::~CURLInstance()
{
    if(curl)
    {
        curl_easy_cleanup(curl);
        curl = 0;
    }
        
    if(curlm)
        curl_multi_cleanup(curlm);
}

CURLcode CURLInstance::PerformEasy()
{
    assert(!IsAttached());
    return curl_easy_perform(curl);
}

CURLcode CURLInstance::PerformMulti()
{
//    bool error = false;
    int running_handles = 0;
    CURLcode result = CURLE_OK;
    
    while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(curlm, &running_handles));
    
    
    while(running_handles)
    {
        struct timeval timeout = {0, 10000};
        
        fd_set fdread, fdwrite, fdexcep;
        int maxfd;
        
        FD_ZERO(&fdread);
        FD_ZERO(&fdwrite);
        FD_ZERO(&fdexcep);
        curl_multi_fdset(curlm, &fdread, &fdwrite, &fdexcep, &maxfd);
        
        if (select(maxfd+1, &fdread, &fdwrite, &fdexcep, &timeout) == -1)
        {
//            error = true;
            break;
        }
        
        while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(curlm, &running_handles));
    }
    
    
    // check for error codes here
    if (running_handles == 0) {
        int msgs_left = 1;
        while (msgs_left)
        {
            CURLMsg* msg = curl_multi_info_read(curlm, &msgs_left);
            if (msg == NULL ||
                msg->msg != CURLMSG_DONE ||
                msg->data.result != CURLE_OK)
            {
                if(msg)
                    result = msg->data.result;
            }
        }
    }
    return result;
}

CURLMcode CURLInstance::Attach()
{
    assert(!IsAttached());
    CURLMcode e = curl_multi_add_handle(curlm, curl);
    if(e == CURLM_OK)
        attached = true;
    
    return e;
}

CURLMcode CURLInstance::Detach()
{
    assert(IsAttached());
    CURLMcode e = curl_multi_remove_handle(curlm, curl);
    if(e == CURLM_OK)
        attached = false;
    return e;
}
    
int CURLInstance::ProgressCallback(void *clientp, double dltotal, double dlnow, double ultotal, double ulnow)
{
    CURLInstance *_this = (CURLInstance *)clientp;
    return _this->prog_func ? _this->prog_func(dltotal, dlnow, ultotal, ulnow) : 0;
}

void CURLInstance::EasySetupProgFunc()
{
    EasySetOpt(CURLOPT_PROGRESSFUNCTION, ProgressCallback);
    EasySetOpt(CURLOPT_PROGRESSDATA, this);
    EasySetOpt(CURLOPT_NOPROGRESS, 0);
    prog_func = nil;
}

void CURLInstance::EasyClearProgFunc()
{
    EasySetOpt(CURLOPT_PROGRESSFUNCTION, nullptr);
    EasySetOpt(CURLOPT_PROGRESSDATA, nullptr);
    EasySetOpt(CURLOPT_NOPROGRESS, 1);
    prog_func = nil;
}

int CURLErrorToVFSError(CURLcode _curle)
{
    using namespace VFSError;
    switch (_curle) {
        case CURLE_LOGIN_DENIED:            return NetFTPLoginDenied;
        case CURLE_URL_MALFORMAT:           return NetFTPURLMalformat;
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
        case CURLE_BAD_CONTENT_ENCODING:    return NetFTPServerProblem;
        case CURLE_COULDNT_RESOLVE_PROXY:   return NetFTPCouldntResolveProxy;
        case CURLE_COULDNT_RESOLVE_HOST:
        case CURLE_FTP_CANT_GET_HOST:       return NetFTPCouldntResolveHost;
        case CURLE_COULDNT_CONNECT:         return NetFTPCouldntConnect;
        case CURLE_REMOTE_ACCESS_DENIED:
        case CURLE_UPLOAD_FAILED:           return NetFTPAccessDenied;
        case CURLE_PARTIAL_FILE:
        case CURLE_FTP_BAD_DOWNLOAD_RESUME: return UnexpectedEOF;
        case CURLE_OPERATION_TIMEDOUT:      return NetFTPOperationTimeout;
        case CURLE_SEND_ERROR:
        case CURLE_RECV_ERROR:              return FromErrno(EIO);
        case CURLE_REMOTE_FILE_NOT_FOUND:   return NotFound;
        case CURLE_SSL_CONNECT_ERROR:
        case CURLE_SSL_ENGINE_NOTFOUND:
        case CURLE_SSL_ENGINE_SETFAILED:
        case CURLE_SSL_CERTPROBLEM:
        case CURLE_SSL_CIPHER:
        case CURLE_SSL_CACERT:
        case CURLE_USE_SSL_FAILED:          return NetFTPSSLFailure;
        default: return FromErrno(EIO);
    }
}

}
