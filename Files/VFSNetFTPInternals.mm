//
//  VFSNetFTPInternals.cpp
//  Files
//
//  Created by Michael G. Kazakov on 17.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <sys/stat.h>
#include "Common.h"
#include "VFSNetFTPInternals.h"
#include "VFSNetFTPHost.h"

namespace VFSNetFTP
{

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
    
    sbuf->st_nlink = nlink;
    
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
        
Listing::Listing(shared_ptr<Directory> _dir,
                 const char *_path,
                 int _flags,
                 shared_ptr<VFSHost> _host):
    VFSListing(_path, _host),
    m_Directory(_dir)
{
    size_t shift = (_flags & VFSHost::F_NoDotDot) ? 0 : 1;
    if(strcmp(_path, "/") == 0)
        shift = 0; // no dot-dot dir for root dir
        
    size_t i = 0, e = _dir->entries.size();
    m_Items.resize(_dir->entries.size() + shift);
    for(;i!=e;++i)
    {
        auto &source = _dir->entries[i];
        auto &dest = m_Items[i + shift];
        
        dest.m_Name = source.name.c_str();
        dest.m_NameLen = source.name.length();
        dest.m_CFName = source.cfname;
        dest.m_Size = (source.mode & S_IFDIR) ? VFSListingItem::InvalidSize : source.size;
        dest.m_ATime = source.time;
        dest.m_MTime = source.time;
        dest.m_CTime = source.time;
        dest.m_BTime = source.time;
        dest.m_Mode = source.mode;
        dest.m_Type = (source.mode & S_IFDIR) ? DT_DIR : DT_REG;
        dest.FindExtension();
    }
    
    if(shift)
    {
        auto &dest = m_Items[0];
        dest.m_Name = "..";
        dest.m_NameLen = 2;
        dest.m_Mode = S_IRUSR | S_IWUSR | S_IFDIR;
        dest.m_CFName = CFSTR("..");
        dest.m_Size = VFSListingItem::InvalidSize;
        
        auto curtime = time(0);
        dest.m_ATime = curtime;
        dest.m_MTime = curtime;
        dest.m_CTime = curtime;
        dest.m_BTime = curtime;
    }
}

int RequestCancelCallback(void *clientp, double dltotal, double dlnow, double ultotal, double ulnow)
{
    if(clientp == nullptr)
        return 0;
    bool (^checker)() = (__bridge bool(^)()) clientp;
    bool res = checker();
    return res ? 1 : 0;
}

void SetupRequestCancelCallback(CURL *_curl, bool (^_cancel_checker)())
{
    if(_cancel_checker)
    {
        curl_easy_setopt(_curl, CURLOPT_PROGRESSFUNCTION, RequestCancelCallback);
        curl_easy_setopt(_curl, CURLOPT_PROGRESSDATA, (__bridge void *)_cancel_checker);
        curl_easy_setopt(_curl, CURLOPT_NOPROGRESS, 0);
    }
    else
    {
        ClearRequestCancelCallback(_curl);
    }
}

void ClearRequestCancelCallback(CURL *_curl)
{
    curl_easy_setopt(_curl, CURLOPT_PROGRESSFUNCTION, nullptr);
    curl_easy_setopt(_curl, CURLOPT_PROGRESSDATA, nullptr);
    curl_easy_setopt(_curl, CURLOPT_NOPROGRESS, 1);
}

    
CURLcode CURLInstance::PerformMulti()
{
    bool error = false;
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
            error = true;
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

}