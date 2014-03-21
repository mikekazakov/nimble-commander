//
//  VFSArchiveHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <assert.h>
#import <sys/dirent.h>
#import "3rd_party/libarchive/archive.h"
#import "3rd_party/libarchive/archive_entry.h"
#import "VFSArchiveHost.h"
#import "VFSArchiveInternal.h"
#import "VFSArchiveFile.h"
#import "VFSArchiveListing.h"
#import "Common.h"

const char *VFSArchiveHost::Tag = "archive";

VFSArchiveHost::VFSArchiveHost(const char *_junction_path,
                               shared_ptr<VFSHost> _parent):
    VFSHost(_junction_path, _parent),
    m_Arc(0),
    m_SeekCacheControl(dispatch_queue_create("info.filesmanager.Files.VFSArchiveHost.sc_control_queue", DISPATCH_QUEUE_SERIAL))
{
}

VFSArchiveHost::~VFSArchiveHost()
{
    dispatch_sync(m_SeekCacheControl, ^{});
    dispatch_release(m_SeekCacheControl);
    if(m_Arc != 0)
        archive_read_free(m_Arc);
    for(auto i:m_SeekCaches)
        archive_read_free(i->arc);
    for(auto &i: m_PathToDir)
        delete i.second;
}

const char *VFSArchiveHost::FSTag() const
{
    return Tag;
}

int VFSArchiveHost::Open()
{
    assert(m_Arc == 0);

    int res = Parent()->CreateFile(JunctionPath(), m_ArFile, nil);
    if(res < 0)
        return res;
    
    if(m_ArFile->GetReadParadigm() < VFSFile::ReadParadigm::Seek)
    {
        m_ArFile.reset();
        return VFSError::InvalidCall;
    }
    
    res = m_ArFile->Open(VFSFile::OF_Read);
    if(res < 0)
        return res;
    
    m_Mediator = make_shared<VFSArchiveMediator>();
    m_Mediator->file = m_ArFile;
    
    m_Arc = archive_read_new();
    archive_read_support_filter_all(m_Arc);
	archive_read_support_format_ar(m_Arc);
	archive_read_support_format_cpio(m_Arc);
	archive_read_support_format_empty(m_Arc);
	archive_read_support_format_lha(m_Arc);
	archive_read_support_format_mtree(m_Arc);
	archive_read_support_format_tar(m_Arc);
	archive_read_support_format_xar(m_Arc);
	archive_read_support_format_7zip(m_Arc);
	archive_read_support_format_cab(m_Arc);
	archive_read_support_format_iso9660(m_Arc);
	archive_read_support_format_zip(m_Arc);
    
    archive_read_set_callback_data(m_Arc, m_Mediator.get());
    archive_read_set_read_callback(m_Arc, VFSArchiveMediator::myread);
    archive_read_set_seek_callback(m_Arc, VFSArchiveMediator::myseek);
    res = archive_read_open1(m_Arc);
    if(res < 0)
    {
        archive_read_free(m_Arc);
        m_Arc = 0;
        m_Mediator.reset();
        m_ArFile.reset();
        return -1; // TODO: right error code
    }
    
    res = ReadArchiveListing();
    m_ArchiveFileSize = m_ArFile->Size();    
    
    return res;
}

int VFSArchiveHost::ReadArchiveListing()
{
    assert(m_Arc != 0);
    uint32_t aruid = 1;
    VFSArchiveDir *root = new VFSArchiveDir;
    root->full_path = "/";
    root->name_in_parent  = "";
    m_PathToDir.insert(make_pair("/", root));

    VFSArchiveDir *parent_dir = root;
    struct archive_entry *entry;
    int ret;
    while ((ret = archive_read_next_header(m_Arc, &entry)) == ARCHIVE_OK)
    {
        const struct stat *stat = archive_entry_stat(entry);
        char path[1024];
        path[0] = '/';
        strcpy(path + 1, archive_entry_pathname(entry));
        
        if(strcmp(path, "/.") == 0) continue; // skip "." entry for ISO for example

        int path_len = (int)strlen(path);
        
        bool isdir = (stat->st_mode & S_IFMT) == S_IFDIR;
        
        char short_name[256];
        char parent_path[1024];
        {
            char tmp[1024];
            strcpy(tmp, path);
            if(tmp[path_len-1] == '/') // cut trailing slash if any
                tmp[path_len-1] = 0;
            char *last_slash = strrchr(tmp, '/');
            strcpy(short_name, last_slash+1);
            *(last_slash+1)=0;
            strcpy(parent_path, tmp);
        }
        
        if(parent_dir->full_path != parent_path)
            parent_dir = FindOrBuildDir(parent_path);
        
        VFSArchiveDirEntry *entry = 0;
        if(isdir) // check if it wasn't added before via FindOrBuildDir
            for(auto &it: parent_dir->entries)
                if( (it.st.st_mode & S_IFMT) == S_IFDIR && it.name == short_name) {
                    entry = &it;
                    break;
                }
        
        if(entry == 0) {
            parent_dir->entries.push_back(VFSArchiveDirEntry());
            entry = &parent_dir->entries.back();
            entry->name = short_name;
        }

        entry->aruid = aruid++;
        entry->st = *stat;
        m_ArchivedFilesTotalSize += stat->st_size;
        
        if(isdir)
        {
            // it's a directory
            if(path[strlen(path)-1] != '/') strcat(path, "/");
            if(m_PathToDir.find(path) == m_PathToDir.end())
            { // check if it wasn't added before via FindOrBuildDir
                char tmp[1024];
                strcpy(tmp, path);
                tmp[path_len-1] = 0;
                VFSArchiveDir *dir = new VFSArchiveDir;
                dir->full_path = path; // full_path is with trailing slash
                dir->name_in_parent = strrchr(tmp, '/')+1;
                m_PathToDir.insert(make_pair(path, dir));
            }
        }
    }
    
    
    m_LastItemUID = aruid - 1;
    
    if(ret == ARCHIVE_EOF)
        return VFSError::Ok;

    printf("%s\n", archive_error_string(m_Arc));
    
    return VFSError::GenericError;
}

VFSArchiveDir* VFSArchiveHost::FindOrBuildDir(const char* _path_with_tr_sl)
{
    assert(IsPathWithTrailingSlash(_path_with_tr_sl));
    auto i = m_PathToDir.find(_path_with_tr_sl);
    if(i != m_PathToDir.end())
        return (*i).second;
    
    char entry_name[256];
    char parent_path[1024];
    strcpy(parent_path, _path_with_tr_sl);
    parent_path[strlen(parent_path)-1] = 0;
    strcpy(entry_name, strrchr(parent_path, '/')+1);
    *(strrchr(parent_path, '/')+1) = 0;
    
    auto parent_dir = FindOrBuildDir(parent_path);

//    printf("FindOrBuildDir: adding new dir %s\n", _path_with_tr_sl);
    
    // TODO: need to check presense of entry_name in parent_dir
    
    InsertDummyDirInto(parent_dir, entry_name);
    VFSArchiveDir *entry = new VFSArchiveDir;
    entry->full_path = _path_with_tr_sl;
    entry->name_in_parent  = entry_name;
    auto i2 = m_PathToDir.insert(make_pair(_path_with_tr_sl, entry));
    return (*i2.first).second;
}

void VFSArchiveHost::InsertDummyDirInto(VFSArchiveDir *_parent, const char* _dir_name)
{
    _parent->entries.push_back(VFSArchiveDirEntry());
    auto &entry = _parent->entries.back();
    entry.name = _dir_name;
    memset(&entry.st, 0, sizeof(entry.st));
    entry.st.st_mode = S_IFDIR;
}

struct archive* VFSArchiveHost::Archive()
{
    return m_Arc;
}

shared_ptr<VFSFile> VFSArchiveHost::ArFile() const
{
    return m_ArFile;
}

int VFSArchiveHost::CreateFile(const char* _path,
                       shared_ptr<VFSFile> &_target,
                       bool (^_cancel_checker)())
{
    auto file = make_shared<VFSArchiveFile>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

int VFSArchiveHost::FetchDirectoryListing(const char *_path,
                                          shared_ptr<VFSListing> *_target,
                                          int _flags,
                                          bool (^_cancel_checker)())
{
    char path[1024];
    strcpy(path, _path);
    if(path[strlen(path)-1] != '/')
        strcat(path, "/");
    
    
    auto i = m_PathToDir.find(path);
    if(i == m_PathToDir.end())
        return VFSError::NotFound;

    shared_ptr<VFSArchiveListing> listing = make_shared<VFSArchiveListing>
        (i->second, path, _flags, SharedPtr());
    
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    
    *_target = listing;
    
    return VFSError::Ok;
}

bool VFSArchiveHost::IsDirectory(const char *_path,
                                 int _flags,
                                 bool (^_cancel_checker)())
{
    if(_path[0] != '/') return false;
    char tmp[MAXPATHLEN];
    strcpy(tmp, _path);
    if(tmp[strlen(tmp)-1] != '/' ) strcat(tmp, "/"); // directories are stored with trailing slashes
    
    auto it = m_PathToDir.find(tmp);
    return it != m_PathToDir.end();
}

int VFSArchiveHost::Stat(const char *_path, VFSStat &_st, int _flags, bool (^_cancel_checker)())
{
    // currenty do not support symlinks in archives, so ignore NoFollow flag
    assert(_path != 0);
    if(_path[0] != '/') return VFSError::NotFound;
    
    if(strlen(_path) == 1)
    {
        // we have no info about root dir - dummy here
        memset(&_st, 0, sizeof(_st));
        return VFSError::Ok;
    }
    
    auto it = FindEntry(_path);
    if(it)
    {
        VFSStat::FromSysStat(it->st, _st);
        return VFSError::Ok;
    }
    return VFSError::NotFound;
}

int VFSArchiveHost::IterateDirectoryListing(const char *_path, bool (^_handler)(const VFSDirEnt &_dirent))
{
    assert(_path != 0);
    if(_path[0] != '/')
        return VFSError::NotFound;

    char buf[1024];
    strcpy(buf, _path);
    if(buf[strlen(buf)-1] != '/')
        strcat(buf, "/"); // we store directories with trailing slash
    
    auto i = m_PathToDir.find(buf);
    if(i == m_PathToDir.end())
        return VFSError::NotFound;
    
    VFSDirEnt dir;
    
    for(const auto &it: i->second->entries)
        {
            strcpy(dir.name, it.name.c_str());
            dir.name_len = it.name.length();
            
            if(S_ISDIR(it.st.st_mode)) dir.type = VFSDirEnt::Dir;
            else if(S_ISREG(it.st.st_mode)) dir.type = VFSDirEnt::Reg;
            else dir.type = VFSDirEnt::Unknown; // symlinks and other stuff are not supported currently

            if(!_handler(dir))
                break;
        }
    
    return VFSError::Ok;
}

uint32_t VFSArchiveHost::ItemUID(const char* _filename)
{
    auto it = FindEntry(_filename);
    if(it)
        return it->aruid;
    return 0;
}

const VFSArchiveDirEntry *VFSArchiveHost::FindEntry(const char* _path)
{
    assert(_path != 0);
    if(_path[0] != '/') return 0;
    
    // 1st - try to find _path directly (assume it's directory)
    char buf[1024], short_name[256];
    strcpy(buf, _path);
    
    char *last_sl = strrchr(buf, '/');
    
    if(last_sl == buf && strlen(buf) == 1)
        return 0; // we have no info about root dir
    if(last_sl == buf + strlen(buf) - 1)
    {
        *last_sl = 0; // cut trailing slash
        last_sl = strrchr(buf, '/');
        assert(last_sl != 0); //sanity check
    }
    
    strcpy(short_name, last_sl + 1);
    *(last_sl + 1) = 0;
    // now:
    // buf - directory with trailing slash
    // short_name - entry name within that directory
    
    assert(strcmp(short_name, "..")); // no ".." resolving in VFS (currently?)
    
    auto i = m_PathToDir.find(buf);
    if(i == m_PathToDir.end())
        return 0;
    
    // ok, found dir, now let's find item
    for(const auto &it: i->second->entries)
        if(it.name == short_name)
            return &it;
    
    return 0;
}

void VFSArchiveHost::CommitSeekCache(shared_ptr<VFSArchiveSeekCache> _sc)
{
/*    if(m_SeekCache.get())
    {
        // flush current one
        archive_read_free(m_SeekCache->arc);
    }
    
    m_SeekCache = _sc;*/
    dispatch_sync(m_SeekCacheControl, ^{
        // will throw away archives positioned at last item - they are useless
        // they will be closed automatically
        if(_sc->uid < m_LastItemUID)
        {
            m_SeekCaches.push_back(_sc);
        }
        else
        {
            archive_read_free(_sc->arc);
        }
    });
}

shared_ptr<VFSArchiveSeekCache> VFSArchiveHost::SeekCache(uint32_t _requested_item)
{
    if(_requested_item == 0)
        return 0;

    __block shared_ptr<VFSArchiveSeekCache> res;
    dispatch_sync(m_SeekCacheControl, ^{
        // choose the closest if any
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
            res = *best;
            m_SeekCaches.erase(best);
        }
    });
    
    return res;
}

int VFSArchiveHost::StatFS(const char *_path, VFSStatFS &_stat, bool (^_cancel_checker)())
{
    char vol_name[256];
    if(!GetFilenameFromPath(JunctionPath(), vol_name))
       return VFSError::InvalidCall;
    
    _stat.volume_name = vol_name;
    _stat.total_bytes = m_ArchivedFilesTotalSize;
    _stat.free_bytes = 0;
    _stat.avail_bytes = 0;
    
    return 0;
}

bool VFSArchiveHost::ShouldProduceThumbnails()
{
    return false;
}
