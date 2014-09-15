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

bool VFSNetFTPOptions::Equal(const VFSHostOptions &_r) const
{
    if(typeid(_r) != typeid(*this))
        return false;

    const VFSNetFTPOptions& r = (const VFSNetFTPOptions&)_r;
    return user == r.user &&
            passwd == r.passwd &&
            port == r.port;
}

VFSNetFTPHost::VFSNetFTPHost(const char *_serv_url):
    VFSHost(_serv_url, nullptr),
    m_Cache(make_unique<VFSNetFTP::Cache>())
{
    m_Cache->SetChangesCallback(^(const string &_at_dir) {
        InformDirectoryChanged(_at_dir.back() == '/' ? _at_dir : _at_dir + "/" );
    });
}

VFSNetFTPHost::~VFSNetFTPHost()
{
}

const char *VFSNetFTPHost::FSTag() const
{
    return Tag;
}

int VFSNetFTPHost::Open(const char *_starting_dir, const VFSNetFTPOptions &_options)
{
    m_Options = make_shared<VFSNetFTPOptions>(_options);
    
    auto instance = SpawnCURL();
    
    int result = DownloadAndCacheListing(instance.get(), _starting_dir, nullptr, nullptr);
    if(result == 0)
    {
        m_ListingInstance = move(instance);
        return 0;
    }
    
    return result;
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
    string path = _path;
    InformDirectoryChanged(path.back() == '/' ? path : path + "/");
    
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
    
    string path = _path;
    if(path.back() != '/')
        path += '/';
    
    string request = BuildFullURLString(path.c_str());
    string response;
    
    _inst->call_lock.lock();
    _inst->EasySetOpt(CURLOPT_URL, request.c_str());
    _inst->EasySetOpt(CURLOPT_WRITEFUNCTION, CURLWriteDataIntoString);
    _inst->EasySetOpt(CURLOPT_WRITEDATA, &response);
    _inst->EasySetupProgFunc();
    _inst->prog_func = ^(double, double, double, double) {
        if(_cancel_checker == nil)
            return 0;
        return _cancel_checker() ? 1 : 0;
    };
    
    CURLcode result = _inst->PerformEasy();
    _inst->EasyClearProgFunc();
    _inst->call_lock.unlock();
    
//    NSLog(@"%s", response.c_str());
    
    if(result != 0)
        return CURLErrorToVFSError(result);
    
    _buffer.swap(response);
    
    return 0;
}

string VFSNetFTPHost::BuildFullURLString(const char *_path) const
{
    // naive implementation
    string url = "ftp://";
    url += JunctionPath();
    url += _path;
    return url;
}

string VFSNetFTPHost::VerboseJunctionPath() const
{
    return "ftp://"s + JunctionPath();
}

unique_ptr<CURLInstance> VFSNetFTPHost::SpawnCURL()
{
    auto inst = make_unique<CURLInstance>();
    inst->curl = curl_easy_init();
    BasicOptsSetup(inst.get());
    return inst;
}

int VFSNetFTPHost::Stat(const char *_path,
                        VFSStat &_st,
                        int _flags,
                        bool (^_cancel_checker)())
{
    if(_path == nullptr || _path[0] != '/' )
        return VFSError::InvalidCall;

    path path = _path;
    if(path == "/")
    {
        // special case for root path
        memset(&_st, 0, sizeof(_st));
        _st.mode = S_IRUSR | S_IWUSR | S_IFDIR;
        _st.atime.tv_sec = _st.mtime.tv_sec = _st.btime.tv_sec = _st.ctime.tv_sec = time(0);

        _st.meaning.size = 1;
        _st.meaning.mode = 1;
        _st.meaning.mtime = _st.meaning.ctime = _st.meaning.btime = _st.meaning.atime = 1;
        return 0;
    }
    
    // 1st - extract directory and filename from _path
    if(path.filename() == ".")
        path.remove_filename();
    
    string parent_dir = path.parent_path().native();
    string filename = path.filename().native();
    
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
    shared_ptr<VFSNetFTP::Directory> dir;
    int result = GetListingForFetching(m_ListingInstance.get(), _path, &dir, _cancel_checker);
    if(result != 0)
        return result;
    
    assert(dir);
    auto listing = make_shared<Listing>(dir, _path, _flags, SharedPtr());
    *_target = listing;
    return 0;
}

int VFSNetFTPHost::GetListingForFetching(VFSNetFTP::CURLInstance *_inst,
                     const char *_path,
                     shared_ptr<VFSNetFTP::Directory> *_cached_dir,
                     bool (^_cancel_checker)())
{
    if(_path == nullptr || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    auto dir = m_Cache->FindDirectory(_path);
    if(dir && !dir->IsOutdated() && !dir->has_dirty_items)
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

bool VFSNetFTPHost::ShouldProduceThumbnails() const
{
    return false;
}

int VFSNetFTPHost::Unlink(const char *_path, bool (^_cancel_checker)())
{
    path path = _path;
    if(path.is_absolute() == false || path.filename() == ".")
        return VFSError::InvalidCall;
    
    string cmd = "DELE " + path.filename().native();
    string url = BuildFullURLString((path.parent_path() / "/").c_str());
    
    CURLMcode curlm_e;
    auto curl = InstanceForIOAtDir( path.parent_path() );
    if(curl->IsAttached()) {
        curlm_e = curl->Detach();
        assert(curlm_e == CURLM_OK);
    }
  
    struct curl_slist* header = NULL;
    header = curl_slist_append(header, cmd.c_str());
    curl->EasySetOpt(CURLOPT_POSTQUOTE, header);
    curl->EasySetOpt(CURLOPT_URL, url.c_str());
    curl->EasySetOpt(CURLOPT_WRITEFUNCTION, 0);
    curl->EasySetOpt(CURLOPT_WRITEDATA, 0);
    curl->EasySetOpt(CURLOPT_NOBODY, 1);

    curlm_e = curl->Attach();
    assert(curlm_e == CURLM_OK);
    CURLcode curl_res = curl->PerformMulti();
    
    curl_slist_free_all(header);
    
    if(curl_res == CURLE_OK)
        m_Cache->CommitUnlink(_path);
    
    CommitIOInstanceAtDir(path.parent_path(), move(curl));
    
    return curl_res == CURLE_OK ?
            VFSError::Ok :
            VFSError::FromErrno(EPERM); // TODO: convert curl_res to something meaningful
}

// _mode is ignored, since we can't specify any access mode from ftp
int VFSNetFTPHost::CreateDirectory(const char* _path, int _mode, bool (^_cancel_checker)())
{
    path path = _path;
    if(path.is_absolute() == false)
        return VFSError::InvalidCall;

    if(*--path.end() == ".") // remove trailing slash if any
        path.remove_filename();
    
    string cmd = "MKD " + path.filename().native();
    string url = BuildFullURLString((path.parent_path() / "/").c_str());
    
    CURLMcode curlm_e;
    auto curl = InstanceForIOAtDir( path.parent_path() );
    if(curl->IsAttached()) {
        curlm_e = curl->Detach();
        assert(curlm_e == CURLM_OK);
    }
    
    struct curl_slist* header = NULL;
    header = curl_slist_append(header, cmd.c_str());
    curl->EasySetOpt(CURLOPT_POSTQUOTE, header);
    curl->EasySetOpt(CURLOPT_URL, url.c_str());
    curl->EasySetOpt(CURLOPT_WRITEFUNCTION, 0);
    curl->EasySetOpt(CURLOPT_WRITEDATA, 0);
    curl->EasySetOpt(CURLOPT_NOBODY, 1);
    
    curlm_e = curl->Attach();
    assert(curlm_e == CURLM_OK);
    
    CURLcode curl_e = curl->PerformMulti();
    
    curl_slist_free_all(header);
    
    if(curl_e == CURLE_OK)
        m_Cache->CommitMKD(path.native());
    
    CommitIOInstanceAtDir(path.parent_path(), move(curl));
    
    return curl_e == CURLE_OK ?
                        VFSError::Ok :
                        VFSError::FromErrno(EPERM); // TODO: convert curl_res to something meaningful
}

int VFSNetFTPHost::RemoveDirectory(const char *_path, bool (^_cancel_checker)())
{
    path path = _path;
    if(path.is_absolute() == false)
        return VFSError::InvalidCall;
    
    if(path.filename() == ".") // remove trailing slash if any
        path.remove_filename();
    
    string cmd = "RMD " + path.filename().native();
    string url = BuildFullURLString((path.parent_path() / "/").c_str());
    
    CURLMcode curlm_e;
    auto curl = InstanceForIOAtDir( path.parent_path() );
    if(curl->IsAttached()) {
        curlm_e = curl->Detach();
        assert(curlm_e == CURLM_OK);
    }
    
    struct curl_slist* header = NULL;
    header = curl_slist_append(header, cmd.c_str());
    curl->EasySetOpt(CURLOPT_POSTQUOTE, header);
    curl->EasySetOpt(CURLOPT_URL, url.c_str());
    curl->EasySetOpt(CURLOPT_WRITEFUNCTION, 0);
    curl->EasySetOpt(CURLOPT_WRITEDATA, 0);
    curl->EasySetOpt(CURLOPT_NOBODY, 1);

    curlm_e = curl->Attach();
    assert(curlm_e == CURLM_OK);
    CURLcode curl_res = curl->PerformMulti();
    curl_slist_free_all(header);
    
    if(curl_res == CURLE_OK)
        m_Cache->CommitRMD(path.native());
    
    CommitIOInstanceAtDir(path.parent_path(), move(curl));
    
    return curl_res == CURLE_OK ?
                        VFSError::Ok :
                        VFSError::FromErrno(EPERM); // TODO: convert curl_res to something meaningful
}

int VFSNetFTPHost::Rename(const char *_old_path, const char *_new_path, bool (^_cancel_checker)())
{
    path old_path = _old_path, new_path = _new_path;
    if(old_path.is_absolute() == false || new_path.is_absolute() == false)
        return VFSError::InvalidCall;
    
    if(old_path.filename() == ".") // remove trailing slash if any
        old_path.remove_filename();
    if(new_path.filename() == ".") // remove trailing slash if any
        new_path.remove_filename();
    
    string url = BuildFullURLString((old_path.parent_path() / "/").c_str());
    string cmd1 = "RNFR "s + old_path.native();
    string cmd2 = "RNTO "s + new_path.native();
    
    CURLMcode curlm_e;
    auto curl = InstanceForIOAtDir( old_path.parent_path() );
    if(curl->IsAttached()) {
        curlm_e = curl->Detach();
        assert(curlm_e == CURLM_OK);
    }
    
    struct curl_slist* header = NULL;
    header = curl_slist_append(header, cmd1.c_str());
    header = curl_slist_append(header, cmd2.c_str());
    curl->EasySetOpt(CURLOPT_POSTQUOTE, header);
    curl->EasySetOpt(CURLOPT_URL, url.c_str());
    curl->EasySetOpt(CURLOPT_WRITEFUNCTION, 0);
    curl->EasySetOpt(CURLOPT_WRITEDATA, 0);
    curl->EasySetOpt(CURLOPT_NOBODY, 1);

    curlm_e = curl->Attach();
    assert(curlm_e == CURLM_OK);
    CURLcode curl_res = curl->PerformMulti();
    
    curl_slist_free_all(header);
    
    if(curl_res == CURLE_OK)
        m_Cache->CommitRename(old_path.native(), new_path.native());
    
    CommitIOInstanceAtDir(old_path.parent_path(), move(curl));
    
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
    assert(_dir_wth_sl.back() == '/');
    lock_guard<mutex> lock(m_UpdateHandlersLock);
    for(auto &i: m_UpdateHandlers)
        if(i.path == _dir_wth_sl)
            i.handler();
}

bool VFSNetFTPHost::IsWriteable() const
{
    return true;
}

bool VFSNetFTPHost::IsWriteableAtPath(const char *_dir) const
{
    return true;
}

int VFSNetFTPHost::IterateDirectoryListing(const char *_path, bool (^_handler)(const VFSDirEnt &_dirent))
{
    shared_ptr<VFSNetFTP::Directory> dir;
    int result = GetListingForFetching(m_ListingInstance.get(), _path, &dir, nullptr);
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

unique_ptr<VFSNetFTP::CURLInstance> VFSNetFTPHost::InstanceForIOAtDir(const path &_dir)
{
    assert(_dir.filename() != ".");
    lock_guard<mutex> lock(m_IOIntancesLock);
    
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
    auto inst = SpawnCURL();
    inst->curlm = curl_multi_init();
    inst->Attach();
    
    return inst;
}

void VFSNetFTPHost::CommitIOInstanceAtDir(const path &_dir, unique_ptr<VFSNetFTP::CURLInstance> _i)
{
    assert(_dir.filename() != ".");
    lock_guard<mutex> lock(m_IOIntancesLock);
    
    _i->EasyReset();
    BasicOptsSetup(_i.get());
    m_IOIntances[_dir] = move(_i);
}

void VFSNetFTPHost::BasicOptsSetup(VFSNetFTP::CURLInstance *_inst)
{
    _inst->EasySetOpt(CURLOPT_VERBOSE, g_CURLVerbose);
    _inst->EasySetOpt(CURLOPT_FTP_FILEMETHOD, g_CURLFTPMethod);
    
    if(m_Options->user != "")
        _inst->EasySetOpt(CURLOPT_USERNAME, m_Options->user.c_str());
    if(m_Options->passwd != "")
        _inst->EasySetOpt(CURLOPT_PASSWORD, m_Options->passwd.c_str());
    if(m_Options->port > 0)
        _inst->EasySetOpt(CURLOPT_PORT, m_Options->port);

    // TODO: SSL support
    // _inst->EasySetOpt(CURLOPT_USE_SSL, CURLUSESSL_TRY);
    // _inst->EasySetOpt(CURLOPT_SSL_VERIFYPEER, false);
    // _inst->EasySetOpt(CURLOPT_SSL_VERIFYHOST, false);
}

shared_ptr<VFSHostOptions> VFSNetFTPHost::Options() const
{
    return m_Options;
}

int VFSNetFTPHost::StatFS(const char *_path, VFSStatFS &_stat, bool (^_cancel_checker)())
{
    _stat.avail_bytes = _stat.free_bytes = _stat.total_bytes = 0;
    _stat.volume_name = JunctionPath();
    return 0;
}
