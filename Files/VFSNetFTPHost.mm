//
//  VFSNetFTPHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 17.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "VFSNetFTPHost.h"
#import "VFSNetFTPInternals.h"
#import "VFSNetFTPCache.h"
#import "VFSNetFTPFile.h"
#import "path_manip.h"

using namespace VFSNetFTP;

const char *VFSNetFTPHost::Tag = "net_ftp";

VFSNetFTPHost::VFSNetFTPHost(const char *_serv_url):
    VFSHost(_serv_url, nullptr),
    m_Cache(make_unique<VFSNetFTP::Cache>())
{
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
    curl_easy_setopt(instance->curl, CURLOPT_VERBOSE, 1);
    curl_easy_setopt(instance->curl, CURLOPT_FTP_FILEMETHOD, g_CURLFTPMethod);
    
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
    m_Cache->InsertLISTDirectory(_path, dir);
    
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

string VFSNetFTPHost::BuildFullURLString(const char *_path) const
{
    // naive implementation
    string url = "ftp://";
    url += JunctionPath();
    url += _path;
    return url;
}

unique_ptr<CURLInstance> VFSNetFTPHost::SpawnCURL()
{
    auto inst = make_unique<CURLInstance>();
    inst->curl = curl_easy_init();
    // ... set a lot of stuff like connection options/logins/etc here...
        
//    curl_easy_setopt(inst->curl, CURLOPT_VERBOSE, 1);
    
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
    if(dir)
    {
        auto entry = dir->EntryByName(filename);
        if(entry)
        {
            if(!entry->dirty)
            { // if entry is here and it's not outdated - return it
                entry->ToStat(_st);
                return 0;
            }
            // if entry is here and it is outdated - we have to fetch a new listing
        }
        else if(!dir->IsOutdated())
        { // if we can't find entry and dir is not outdated - return NotFound.
            return VFSError::NotFound;
        }
    }

    // assume that file is freshly created and thus we don't have it in current cache state
    // download new listing, sync I/O
    int result = DownloadAndCacheListing(m_ListingInstance.get(), parent_dir.c_str(), &dir, _cancel_checker);
    if(result != 0)
    {
//        NSLog(@"VFSNetFTPHost::Stat failed to download listing");
        return result;
    }
    
    assert(dir);
    if(auto entry = dir->EntryByName(filename))
    {
        entry->ToStat(_st);
        return 0;
    }
//    NSLog(@"VFSNetFTPHost::Stat failed to found item");
    return VFSError::NotFound;
}

int VFSNetFTPHost::FetchDirectoryListing(const char *_path,
                                         shared_ptr<VFSListing> *_target,
                                         int _flags,
                                         bool (^_cancel_checker)())
{
/*    if(_path == nullptr || _path[0] != '/' )
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
    return 0;*/
    shared_ptr<VFSNetFTP::Directory> dir;
    int result = GetActualListing(m_ListingInstance.get(), _path, &dir, _cancel_checker);
    if(result != 0)
        return result;
    
    assert(dir);
    auto listing = make_shared<Listing>(dir, _path, _flags, SharedPtr());
    *_target = listing;
    return 0;
}

int VFSNetFTPHost::GetActualListing(VFSNetFTP::CURLInstance *_inst,
                     const char *_path,
                     shared_ptr<VFSNetFTP::Directory> *_cached_dir,
                     bool (^_cancel_checker)())
{
    if(_path == nullptr || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    auto dir = m_Cache->FindDirectory(_path);
    if(dir && !dir->IsOutdated())
    {
        *_cached_dir = dir;
        return 0;
    }
    
    // download listing, sync I/O
    int result = DownloadAndCacheListing(m_ListingInstance.get(), _path, &dir, _cancel_checker); // sync I/O here
    if(result != 0)
        return result;
    
    assert(dir);
    
    *_cached_dir = dir;
    return 0;
}

unique_ptr<VFSNetFTP::CURLInstance> VFSNetFTPHost::InstanceForIO()
{
    return SpawnCURL();
}

int VFSNetFTPHost::CreateFile(const char* _path,
                              shared_ptr<VFSFile> &_target,
                              bool (^_cancel_checker)())
{
    auto file = make_shared<VFSNetFTPFile>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

bool VFSNetFTPHost::ShouldProduceThumbnails()
{
    return false;
}

int VFSNetFTPHost::Unlink(const char *_path, bool (^_cancel_checker)())
{
    char filename[MAXPATHLEN],
         directory[MAXPATHLEN],
         cmd[MAXPATHLEN],
         url[MAXPATHLEN];

    if(IsPathWithTrailingSlash(_path))
        return VFSError::InvalidCall;

    if(!GetFilenameFromPath(_path, filename))
        return VFSError::InvalidCall;
    
    if(!GetDirectoryContainingItemFromPath(_path, directory))
        return VFSError::InvalidCall;

    sprintf(cmd, "DELE %s", filename);
    BuildFullURL(directory, url);
    
    auto curl = SpawnCURL(); // TODO: need to somehow get this handle from cache pool
    
    struct curl_slist* header = NULL;
    header = curl_slist_append(header, cmd);
    
    curl_easy_setopt(curl->curl, CURLOPT_POSTQUOTE, header);
    curl_easy_setopt(curl->curl, CURLOPT_URL, url);
    curl_easy_setopt(curl->curl, CURLOPT_WRITEFUNCTION, 0);
    curl_easy_setopt(curl->curl, CURLOPT_WRITEDATA, 0);
    curl_easy_setopt(curl->curl, CURLOPT_NOBODY, 1);
    CURLcode curl_res = curl_easy_perform(curl->curl);
    curl_easy_setopt(curl->curl, CURLOPT_POSTQUOTE, NULL);
    curl_easy_setopt(curl->curl, CURLOPT_NOBODY, 0);
    curl_slist_free_all(header);
    
    if(curl_res == CURLE_OK)
        m_Cache->CommitUnlink(_path);
    
    return curl_res == CURLE_OK ?
            VFSError::Ok :
            VFSError::FromErrno(EPERM); // TODO: convert curl_res to something meaningful
}

int VFSNetFTPHost::CreateDirectory(const char* _path, bool (^_cancel_checker)())
{
    path path = _path;
    if(path.is_absolute() == false)
        return VFSError::InvalidCall;

    if(*--path.end() == ".") // remove trailing slash if any
        path.remove_filename();
    
    string cmd = "MKD " + path.filename().native();
    string url = BuildFullURLString((path.parent_path() / "/").c_str());
    
    auto curl = SpawnCURL(); // TODO: need to somehow get this handle from cache pool
    
    struct curl_slist* header = NULL;
    header = curl_slist_append(header, cmd.c_str());
    curl_easy_setopt(curl->curl, CURLOPT_POSTQUOTE, header);
    curl_easy_setopt(curl->curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl->curl, CURLOPT_WRITEFUNCTION, 0);
    curl_easy_setopt(curl->curl, CURLOPT_WRITEDATA, 0);
    curl_easy_setopt(curl->curl, CURLOPT_NOBODY, 1);
//    curl_easy_setopt(curl->curl, CURLOPT_VERBOSE, 1);
    CURLcode curl_res = curl_easy_perform(curl->curl);
    curl_easy_setopt(curl->curl, CURLOPT_POSTQUOTE, NULL);
    curl_easy_setopt(curl->curl, CURLOPT_NOBODY, 0);
    curl_slist_free_all(header);
    
    if(curl_res == CURLE_OK)
        m_Cache->CommitMKD(path.native());
    
    return curl_res == CURLE_OK ?
                        VFSError::Ok :
                        VFSError::FromErrno(EPERM); // TODO: convert curl_res to something meaningful
}

int VFSNetFTPHost::RemoveDirectory(const char *_path, bool (^_cancel_checker)())
{
    path path = _path;
    if(path.is_absolute() == false)
        return VFSError::InvalidCall;
    
    if(*--path.end() == ".") // remove trailing slash if any
        path.remove_filename();
    
    string cmd = "RMD " + path.filename().native();
    string url = BuildFullURLString((path.parent_path() / "/").c_str());
    
    auto curl = SpawnCURL(); // TODO: need to somehow get this handle from cache pool
    
    struct curl_slist* header = NULL;
    header = curl_slist_append(header, cmd.c_str());
    curl_easy_setopt(curl->curl, CURLOPT_POSTQUOTE, header);
    curl_easy_setopt(curl->curl, CURLOPT_URL, url.c_str());
    curl_easy_setopt(curl->curl, CURLOPT_WRITEFUNCTION, 0);
    curl_easy_setopt(curl->curl, CURLOPT_WRITEDATA, 0);
    curl_easy_setopt(curl->curl, CURLOPT_NOBODY, 1);
    CURLcode curl_res = curl_easy_perform(curl->curl);
    curl_easy_setopt(curl->curl, CURLOPT_POSTQUOTE, NULL);
    curl_easy_setopt(curl->curl, CURLOPT_NOBODY, 0);
    curl_slist_free_all(header);
    
    if(curl_res == CURLE_OK)
        m_Cache->CommitRMD(path.native());
    
    return curl_res == CURLE_OK ?
                        VFSError::Ok :
                        VFSError::FromErrno(EPERM); // TODO: convert curl_res to something meaningful
}

void VFSNetFTPHost::MakeDirectoryStructureDirty(const char *_path)
{
    if(auto dir = m_Cache->FindDirectory(_path))
    {
        InformDirectoryChanged(dir->path);
        dir->dirty_structure = true;
    }
}

unsigned long VFSNetFTPHost::DirChangeObserve(const char *_path, void (^_handler)())
{
    if(_path == 0 || _path[0] != '/')
        return 0;

    lock_guard<mutex> lock(m_UpdateHandlersLock);
    
    m_UpdateHandlers.emplace_back();
    auto &h = m_UpdateHandlers.back();
    h.ticket = m_LastUpdateTicket++;
    h.path = _path;
    if(h.path.back() != '/') h.path += '/';
    h.handler = _handler;
    
    return h.ticket;
}

void VFSNetFTPHost::StopDirChangeObserving(unsigned long _ticket)
{
    lock_guard<mutex> lock(m_UpdateHandlersLock);
    m_UpdateHandlers.erase(remove_if(begin(m_UpdateHandlers),
                                     end(m_UpdateHandlers),
                                     [=](auto &_h) {return _h.ticket == _ticket;}),
                           m_UpdateHandlers.end());
}

void VFSNetFTPHost::InformDirectoryChanged(const string &_dir_wth_sl)
{
    lock_guard<mutex> lock(m_UpdateHandlersLock);
    for(auto &i: m_UpdateHandlers)
        if(i.path == _dir_wth_sl)
            i.handler();
}

bool VFSNetFTPHost::IsWriteable() const
{
    return true;
}

int VFSNetFTPHost::IterateDirectoryListing(const char *_path, bool (^_handler)(const VFSDirEnt &_dirent))
{
    shared_ptr<VFSNetFTP::Directory> dir;
    int result = GetActualListing(m_ListingInstance.get(), _path, &dir, nullptr);
    if(result != 0)
        return result;
    
    for(auto &i: dir->entries)
    {
        VFSDirEnt e;
        strcpy(e.name, i.name.c_str());
        e.name_len = i.name.length();
        e.type = IFTODT(i.mode);

        if( !_handler(e) )
            break;
    }
    return 0;
}

static int TalkAlot(CURL *, curl_infotype, char *s, size_t n , void *)
{
    string str(s, n);
//    NSLog(@"%s", str.c_str());
    NSLog(@"%@", [NSString stringWithUTF8String:str.c_str()]);
    return 0;
}

unique_ptr<VFSNetFTP::CURLInstance> VFSNetFTPHost::InstanceForIOAtDir(const char *_dir)
{
    // try to find cached inst in exact this directory
    auto i = m_IOIntances.find(_dir);
    if(i != end(m_IOIntances))
    {
        auto r = move(i->second);
        m_IOIntances.erase(i);
        return r;
    }
    
    // if can't find - return any cached
    if(!m_IOIntances.empty())
    {
        i = m_IOIntances.begin();
        auto r = move(i->second);
        m_IOIntances.erase(i);
        return r;
    }
    
    // if we're empty - just create and return new inst
    auto inst =  SpawnCURL();
    inst->curlm = curl_multi_init();
    curl_multi_add_handle(inst->curlm, inst->curl);
    
    curl_easy_setopt(inst->curl, CURLOPT_VERBOSE, 1);
//    curl_easy_setopt(inst->curl, CURLOPT_DEBUGFUNCTION, TalkAlot);
    curl_easy_setopt(inst->curl, CURLOPT_FTP_FILEMETHOD, g_CURLFTPMethod);
//    curl_easy_setopt(inst->curl, CURLOPT_TCP_NODELAY, 1);
    
//    curl_easy_setopt(inst->curl, CURLOPT_NOSIGNAL, 1);
//
    
    return inst;
}

void VFSNetFTPHost::CommitIOInstanceAtDir(const char *_dir, unique_ptr<VFSNetFTP::CURLInstance> _i)
{
//    void curl_easy_reset(CURL *handle );
    curl_easy_reset(_i->curl);
    curl_easy_setopt(_i->curl, CURLOPT_VERBOSE, 1);
//    curl_easy_setopt(_i->curl, CURLOPT_DEBUGFUNCTION, TalkAlot);

//    curl_easy_setopt(_i->curl, CURLOPT_NOSIGNAL, 1);
    
    
    curl_easy_setopt(_i->curl, CURLOPT_FTP_FILEMETHOD, g_CURLFTPMethod);
//    curl_easy_setopt(_i->curl, CURLOPT_TCP_NODELAY, 1);
    
//    curl_easy_setopt(_i->curl, CURLOPT_VERBOSE, 1);
    m_IOIntances[_dir] = move(_i);
}
