//
//  VFSNetFTPHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 17.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "VFSNetFTPHost.h"
#import "VFSNetFTPInternals.h"

using namespace VFSNetFTP;

const char *VFSNetFTPHost::Tag = "net_ftp";

VFSNetFTPHost::VFSNetFTPHost(const char *_serv_url):
    VFSHost(_serv_url, nullptr),
    m_Cache(new Cache)
{


    /*
    CURLInstance inst;
    inst.curl = curl_easy_init();
    curl_easy_setopt(inst.curl, CURLOPT_URL, "ftp://192.168.2.5/" );
//    curl_easy_setopt(inst.curl, CURLOPT_USERPWD, usrpwd.c_str());
//    curl_easy_setopt(inst.curl, CURLOPT_FTPLISTONLY, TRUE);
    
    string str;
    curl_easy_setopt(inst.curl, CURLOPT_WRITEFUNCTION, write_data);
    curl_easy_setopt(inst.curl, CURLOPT_WRITEDATA, &str);
    
    curl_easy_perform(inst.curl);
    
//    printf("%s", str.c_str());
    
//    VFSNetFTPInternals_ParseListing(str);
    auto dir = ParseListing(str.c_str());
    
    m_Cache->InsertDirectory("/", dir);
    
//    curl_easy_setopt(inst.curl, CURLOPT_URL, "ftp://192.168.2.5/Public/" );
//    curl_easy_perform(inst.curl);
    
    curl_easy_cleanup(inst.curl);*/
}

VFSNetFTPHost::~VFSNetFTPHost()
{
}

const char *VFSNetFTPHost::FSTag() const
{
    return Tag;
}

int VFSNetFTPHost::Open(const char *_starting_dir, const VFSNetFTPOptions *_options)
{
    auto instance = SpawnCURL();
    
    int result = DownloadAndCacheListing(instance.get(), _starting_dir, nullptr, nullptr);
    if(result == 0)
    {
        m_ListingInstance = move(instance);
        return 0;
    }
    
    return VFSError::GenericError;
}

int VFSNetFTPHost::DownloadAndCacheListing(CURLInstance *_inst,
                                           const char *_path,
                                           shared_ptr<Directory> *_cached_dir,
                                           bool (^_cancel_checker)())
{
    if(_inst == nullptr || _path == nullptr)
        return VFSError::InvalidCall;
    
    string listing_data;
    int result = DownloadListing(_inst, _path, listing_data, _cancel_checker);
    if( result != 0 )
        return result;
    
    auto dir = ParseListing(listing_data.c_str());
    m_Cache->InsertDirectory(_path, dir);
    
    if(_cached_dir)
        *_cached_dir = dir;
    
    return 0;
}

int VFSNetFTPHost::DownloadListing(CURLInstance *_inst,
                                   const char *_path,
                                   string &_buffer,
                                   bool (^_cancel_checker)())
{
    if(_path == nullptr ||
       _path[0] != '/')
        return VFSError::InvalidCall;
    
    char path[MAXPATHLEN];
    strcpy(path, _path);
    if(path[strlen(path)-1] != '/')
        strcat(path, "/");
    
    char request[MAXPATHLEN*2];
    BuildFullURL(path, request);
    
    
    string response;
    
    _inst->call_lock.lock();
    curl_easy_setopt(_inst->curl, CURLOPT_URL, request);
    curl_easy_setopt(_inst->curl, CURLOPT_WRITEFUNCTION, CURLWriteDataIntoString);
    curl_easy_setopt(_inst->curl, CURLOPT_WRITEDATA, &response);
    SetupRequestCancelCallback(_inst->curl, _cancel_checker);
    int result = curl_easy_perform(_inst->curl);
    ClearRequestCancelCallback(_inst->curl);
    _inst->call_lock.unlock();
    
//    NSLog(@"%s", response.c_str());
    
    if(result != 0)
    {
        // handle somehow
        return VFSError::GenericError;
    }
    
    _buffer.swap(response);
    
    return 0;
}

void VFSNetFTPHost::BuildFullURL(const char *_path, char *_buffer) const
{
    // naive implementation
    sprintf(_buffer, "ftp://%s%s", JunctionPath(), _path);
}

unique_ptr<CURLInstance> VFSNetFTPHost::SpawnCURL()
{
    unique_ptr<CURLInstance> inst(new CURLInstance);
    inst->curl = curl_easy_init();
    // ... set a lot of stuff like connection options/logins/etc here...
    
    
    return inst;
}

int VFSNetFTPHost::Stat(const char *_path,
                        VFSStat &_st,
                        int _flags,
                        bool (^_cancel_checker)())
{
    if(_path == nullptr || _path[0] != '/' )
        return VFSError::InvalidCall;

    string path = _path;
    if(path == "/")
    {
        // special case for root path
        memset(&_st, 0, sizeof(_st));
        _st.mode = S_IRUSR | S_IWUSR | S_IFDIR;
        _st.atime.tv_sec = _st.mtime.tv_sec = _st.btime.tv_sec = _st.ctime.tv_sec = time(0);
        return 0;
    }
    
    // 1st - extract directory and filename from _path
    if(path.back() == '/')
        path.pop_back();
    
    auto last_sl = path.rfind('/');
    assert(last_sl != string::npos);
    string parent_dir(path, 0, last_sl + 1);
    string filename(path, last_sl + 1);
    
    // try to find dir from cache
    auto dir = m_Cache->FindDirectory(parent_dir);
    if(dir && !dir->IsOutdated())
    {
        auto *entry = dir->EntryByName(filename);
        if(entry)
        {
            entry->ToStat(_st);
            return 0;
        }
    }

    // download new listing, sync I/O
    int result = DownloadAndCacheListing(m_ListingInstance.get(), parent_dir.c_str(), &dir, _cancel_checker);
    if(result != 0)
        return result;
    
    assert(dir);
    auto *entry = dir->EntryByName(filename);
    if(entry)
    {
        entry->ToStat(_st);
        return 0;
    }
    return VFSError::NotFound;
}

int VFSNetFTPHost::FetchDirectoryListing(const char *_path,
                                         shared_ptr<VFSListing> *_target,
                                         int _flags,
                                         bool (^_cancel_checker)())
{
    if(_path == nullptr || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    auto dir = m_Cache->FindDirectory(_path);
    if(dir && !dir->IsOutdated())
    {
        auto listing = make_shared<Listing>(dir, _path, _flags, SharedPtr());
        *_target = listing;
        return 0;
    }
    
    // download listing, sync I/O
    int result = DownloadAndCacheListing(m_ListingInstance.get(), _path, &dir, _cancel_checker); // sync I/O here
    if(result != 0)
        return result;
    
    assert(dir);
    
    auto listing = make_shared<Listing>(dir, _path, _flags, SharedPtr());
    *_target = listing;
    return 0;
}
