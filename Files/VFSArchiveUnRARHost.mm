//
//  VFSArchiveUnRARHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 02.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <string.h>
#include "Common.h"
#include "VFSNativeHost.h"
#include "VFSArchiveUnRARHost.h"
#include "VFSArchiveUnRARInternals.h"
#include "VFSArchiveUnRARListing.h"
#include "VFSArchiveUnRARFile.h"

static time_t DosTimeToUnixTime(uint32_t _dos_time)
{
    uint32_t l = _dos_time; // a dosdate
    
    int year    =  ((l>>25)&127) + 1980;// 7 bits
    int month   =   (l>>21)&15;         // 4 bits
    int day     =   (l>>16)&31;         // 5 bits
    int hour    =   (l>>11)&31;         // 5 bits
    int minute  =   (l>>5) &63;         // 6 bits
    int second  =   (l     &31) * 2;    // 5 bits
    
    struct tm timeinfo;
    timeinfo.tm_year    = year - 1900;
    timeinfo.tm_mon     = month - 1;
    timeinfo.tm_mday    = day;
    timeinfo.tm_hour    = hour;
    timeinfo.tm_min     = minute;
    timeinfo.tm_sec     = second;
    
    return timegm(&timeinfo);
}

const char *VFSArchiveUnRARHost::Tag = "arc_unrar";

VFSArchiveUnRARHost::VFSArchiveUnRARHost(const char *_junction_path):
    VFSHost(_junction_path, VFSNativeHost::SharedHost()),
    m_SeekCacheControl(dispatch_queue_create(NULL, NULL))
{
}

VFSArchiveUnRARHost::~VFSArchiveUnRARHost()
{
    dispatch_sync(m_SeekCacheControl, ^{});
    dispatch_release(m_SeekCacheControl);
}

const char *VFSArchiveUnRARHost::FSTag() const
{
    return Tag;
}

bool VFSArchiveUnRARHost::IsRarArchive(const char *_archive_native_path)
{
    if(_archive_native_path == nullptr ||
       _archive_native_path[0] != '/')
        return false;

    // check extension
    char ext[MAXPATHLEN];
    if(!GetExtensionFromPath(_archive_native_path, ext))
        return false;
    string sext(ext);
    transform(begin(sext), end(sext), begin(sext), ::tolower);
    if(sext != "rar")
        return false;
    
	HANDLE rar_file;
    RAROpenArchiveDataEx flags;
    memset(&flags, 0, sizeof(flags));
	flags.ArcName = (char*)_archive_native_path;
	flags.OpenMode = RAR_OM_LIST;
    
	rar_file = RAROpenArchiveEx(&flags);
    bool result = rar_file != 0;
    RARCloseArchive(rar_file);
    
    return result;
}

int VFSArchiveUnRARHost::Open()
{
    if(!Parent() || Parent()->IsNativeFS() == false)
        return VFSError::NotSupported;
    
    if(stat(JunctionPath(), &m_ArchiveFileStat) != 0)
        return VFSError::FromErrno(EIO);
    
	HANDLE rar_file;
    RAROpenArchiveDataEx flags;
    memset(&flags, 0, sizeof(flags));
	flags.ArcName = (char*)JunctionPath();
	flags.OpenMode = RAR_OM_LIST;
    
	rar_file = RAROpenArchiveEx(&flags);
    if(rar_file == 0)
        return VFSError::UnRARFailedToOpenArchive;
    
    int ret = InitialReadFileList(rar_file);
    RARCloseArchive(rar_file);
    
    if(ret < 0)
        return ret;
    
    return 0;
}

int VFSArchiveUnRARHost::InitialReadFileList(void *_rar_handle)
{
    auto root_dir = m_PathToDir.emplace("/", VFSArchiveUnRARDirectory());
    root_dir.first->second.full_path = "/";
    root_dir.first->second.time = m_ArchiveFileStat.st_mtimespec.tv_sec;
    
    uint32_t uuid = 1;
    unsigned solid_items = 0;
    m_UnpackedItemsSize = 0;
    m_PackedItemsSize   = 0;
    
    RARHeaderDataEx header;
    
    int read_head_ret, proc_file_ret;
    while((read_head_ret = RARReadHeaderEx(_rar_handle, &header)) == 0)
    {
        if((header.Flags & RHDF_SOLID) != 0)
            solid_items++;
        
        // doing UTF32LE->UTF8 to be sure about single-byte RAR encoding
        CFStringRef utf32le = CFStringCreateWithBytesNoCopy(NULL,
                                                            (UInt8*)header.FileNameW,
                                                            wcslen(header.FileNameW)*sizeof(wchar_t),
                                                            kCFStringEncodingUTF32LE,
                                                            false,
                                                            kCFAllocatorNull);
        char utf8buf[4096] = {'/', 0};
        CFStringGetFileSystemRepresentation(utf32le, utf8buf+1, 4096-1);
//        NSLog(@"%@", (__bridge NSString*)utf32le);
        CFRelease(utf32le);
        

        const char *last_sl = strrchr(utf8buf, '/');
        assert(last_sl != 0);
        string parent_dir_path(utf8buf, last_sl + 1 - utf8buf);

        string entry_short_name(last_sl + 1);
        
        VFSArchiveUnRARDirectory    *parent_dir = FindOrBuildDirectory(parent_dir_path);
        VFSArchiveUnRAREntry        *entry = nullptr;
        
        bool is_directory = (header.Flags & RHDF_DIRECTORY) != 0;
        if(is_directory)
            for(auto &i: parent_dir->entries)
                if(i.name == entry_short_name)
                {
                    entry = &i;
                    break;
                }
        
        if(entry == nullptr)
        {
            parent_dir->entries.emplace_back();
            entry = &parent_dir->entries.back();
            entry->name = entry_short_name;
        }
        
        entry->cfname       = CFStringCreateWithUTF8StdStringNoCopy(entry->name);
        entry->rar_name     = header.FileName;
        entry->isdir        = is_directory;
        entry->packed_size  = uint64_t(header.PackSize) | ( uint64_t(header.PackSizeHigh) << 32 );
        entry->unpacked_size= uint64_t(header.UnpSize) | ( uint64_t(header.UnpSizeHigh) << 32 );
        entry->time         = DosTimeToUnixTime(header.FileTime);
        entry->uuid         = uuid++;
        /*
        mode_t mode = header.FileAttr;
         // No using now. need to do some test about real POSIX mode data here, not only read-for-owner access.
         */

        m_UnpackedItemsSize +=  entry->unpacked_size;
        m_PackedItemsSize   += entry->packed_size;
        
        
        if(is_directory)
            FindOrBuildDirectory(string(utf8buf) + '/')->time = entry->time;
        
		if ((proc_file_ret = RARProcessFile(_rar_handle, RAR_SKIP, NULL, NULL)) != 0)
            return VFSError::GenericError; // TODO: need an adequate error code here
	}
    
    if(read_head_ret == ERAR_MISSING_PASSWORD)
        return VFSArchiveUnRARErrorToVFSError(read_head_ret);
    
    m_LastItemUID = uuid - 1;
    m_IsSolidArchive = solid_items > 0;
    
    return 0;
}

VFSArchiveUnRARDirectory *VFSArchiveUnRARHost::FindOrBuildDirectory(const string& _path_with_tr_sl)
{
    auto i = m_PathToDir.find(_path_with_tr_sl);
    if(i != m_PathToDir.end())
        return &i->second;
    
    auto last_sl = _path_with_tr_sl.size() - 2;
    while(_path_with_tr_sl[last_sl] != '/')
        --last_sl;
    
    auto parent_dir = FindOrBuildDirectory( string(_path_with_tr_sl, 0, last_sl + 1) );
    auto &entries = parent_dir->entries;

    string short_name(_path_with_tr_sl, last_sl + 1, _path_with_tr_sl.size() - last_sl - 2);
    
    if( find_if(begin(entries), end(entries), [&](const VFSArchiveUnRAREntry&i) {return i.name == short_name;} )
       == end(parent_dir->entries) ) {
        parent_dir->entries.emplace_back();
        parent_dir->entries.back().name = short_name;
    }
    
    auto dir = m_PathToDir.emplace(_path_with_tr_sl, VFSArchiveUnRARDirectory());
    dir.first->second.full_path = _path_with_tr_sl;
    return &dir.first->second;
}

int VFSArchiveUnRARHost::FetchDirectoryListing(const char *_path,
                                               shared_ptr<VFSListing> *_target,
                                               int _flags,
                                               bool (^_cancel_checker)())
{
    auto dir = FindDirectory(_path);
    if(!dir)
        return VFSError::NotFound;

    auto listing = make_shared<VFSArchiveUnRARListing>(*dir, _path, _flags, SharedPtr());
    
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    
    *_target = listing;
    
    return VFSError::Ok;
}

int VFSArchiveUnRARHost::IterateDirectoryListing(const char *_path,
                                                 bool (^_handler)(const VFSDirEnt &_dirent))
{
    auto dir = FindDirectory(_path);
    if(!dir)
        return VFSError::NotFound;

    VFSDirEnt dirent;
    for(auto &it: dir->entries)
    {
        strcpy(dirent.name, it.name.c_str());
        dirent.name_len = it.name.length();
        dirent.type = it.isdir ? VFSDirEnt::Dir : VFSDirEnt::Reg;

        if(!_handler(dirent))
            break;
    }
    
    return 0;
}

const VFSArchiveUnRARDirectory *VFSArchiveUnRARHost::FindDirectory(const string& _path) const
{
    string path = _path;
    if(path.back() != '/')
        path += '/';

    auto i = m_PathToDir.find(path);
    if(i == m_PathToDir.end())
        return nullptr;
    
    return &i->second;
}

int VFSArchiveUnRARHost::Stat(const char *_path, VFSStat &_st, int _flags, bool (^_cancel_checker)())
{
    static VFSStat::meaningT m;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        memset(&m, sizeof(m), 0);
        m.size = 1;
        m.mode = 1;
        m.mtime = 1;
        m.atime = 1;
        m.ctime = 1;
        m.btime = 1;
    });
    
    if(_path == 0)
        return VFSError::InvalidCall;
    
    if(_path[0] != '/')
        return VFSError::NotFound;
    
    if(strlen(_path) == 1)
    {
        // we have no info about root dir - dummy here
        memset(&_st, 0, sizeof(_st));
        _st.mode = S_IRUSR | S_IWUSR | S_IFDIR;
        return VFSError::Ok;
    }
    
    auto it = FindEntry(_path);
    if(it)
    {
        memset(&_st, 0, sizeof(_st));
        _st.size = it->unpacked_size;
        _st.mode = S_IRUSR | S_IWUSR | (it->isdir ? (S_IXUSR|S_IFDIR) : S_IFREG);
        _st.atime.tv_sec = it->time;
        _st.mtime.tv_sec = it->time;
        _st.ctime.tv_sec = it->time;
        _st.btime.tv_sec = it->time;
        _st.meaning = m;
        return VFSError::Ok;
    }
    
    return VFSError::NotFound;
}

const VFSArchiveUnRAREntry *VFSArchiveUnRARHost::FindEntry(const string &_full_path) const
{
    if(_full_path.empty())
        return nullptr;
    if(_full_path[0] != '/')
        return nullptr;
    if(_full_path.length() == 1 && _full_path[0] == '/')
        return nullptr;
    
    string path = _full_path;
    if(path.back() == '/')
        path.pop_back();
    
    auto last_sl = path.rfind('/');
    assert(last_sl != string::npos);
    string parent_dir(path, 0, last_sl + 1);
    
    auto directory = m_PathToDir.find(parent_dir);
    if(directory == m_PathToDir.end())
        return nullptr;

    string filename(path.c_str() + last_sl + 1);
    for(const auto &it: directory->second.entries)
        if(it.name == filename)
            return &it;

    return nullptr;
}

uint32_t VFSArchiveUnRARHost::ItemUUID(const string& _filename) const
{
    if(auto entry = FindEntry(_filename))
        return entry->uuid;
    return 0;
}

unique_ptr<VFSArchiveUnRARSeekCache> VFSArchiveUnRARHost::SeekCache(uint32_t _requested_item)
{
    if(_requested_item == 0)
        return 0;
    
    __block unique_ptr<VFSArchiveUnRARSeekCache> res;
    
    dispatch_sync(m_SeekCacheControl, ^{
        // choose the closest cached archive handle if any
        uint32_t best_delta = -1;
        auto best = m_SeekCaches.end();
        for(auto i = m_SeekCaches.begin(); i != m_SeekCaches.end(); ++i)
        {
            if((*i)->uid < _requested_item)
            {
                uint32_t delta = _requested_item - (*i)->uid;
                if(delta < best_delta)
                {
                    best_delta = delta;
                    best = i;
                    if(delta == 1) // the closest one is found, no need to search further
                        break;
                }
            }
        }
        if(best != m_SeekCaches.end())
        {
            res = move(*best);
            m_SeekCaches.erase(best);
//            NSLog(@"found cached");
            return;
        }
        
        // open a new archive handle
        HANDLE rar_file;
        RAROpenArchiveDataEx flags;
        memset(&flags, 0, sizeof(flags));
        flags.ArcName = (char*)JunctionPath();
        flags.OpenMode = RAR_OM_EXTRACT;
        
        rar_file = RAROpenArchiveEx(&flags);
        if(rar_file == 0)
            return;
        
//        NSLog(@"spawned new");
        res = unique_ptr<VFSArchiveUnRARSeekCache>(new VFSArchiveUnRARSeekCache);
        res->rar_handle = rar_file;
    });
    
    return move(res);
}

void VFSArchiveUnRARHost::CommitSeekCache(unique_ptr<VFSArchiveUnRARSeekCache> _sc)
{
    assert(_sc->uid < m_LastItemUID);
    __block unique_ptr<VFSArchiveUnRARSeekCache> sc(move(_sc));
    dispatch_sync(m_SeekCacheControl, ^{
        m_SeekCaches.push_back(move(sc));
    });
}

int VFSArchiveUnRARHost::CreateFile(const char* _path,
                                    shared_ptr<VFSFile> &_target,
                                    bool (^_cancel_checker)())
{
    auto file = make_shared<VFSArchiveUnRARFile>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

bool VFSArchiveUnRARHost::ShouldProduceThumbnails()
{
//    if(m_IsSolidArchive && m_PackedItemsSize > 64*1024*1024)
//        return false;
//    return true;
    return false;
}

uint32_t VFSArchiveUnRARHost::LastItemUUID() const
{
    return m_LastItemUID;
};

int VFSArchiveUnRARHost::StatFS(const char *_path, VFSStatFS &_stat, bool (^_cancel_checker)())
{
    char vol_name[256];
    if(!GetFilenameFromPath(JunctionPath(), vol_name))
        return VFSError::InvalidCall;
    
    _stat.volume_name = vol_name;
    _stat.total_bytes = m_UnpackedItemsSize;
    _stat.free_bytes = 0;
    _stat.avail_bytes = 0;
    
    return 0;
}
