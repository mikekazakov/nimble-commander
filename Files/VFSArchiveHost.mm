//
//  VFSArchiveHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/dirent.h>
#import "3rd_party/libarchive/archive.h"
#import "3rd_party/libarchive/archive_entry.h"
#import "VFSArchiveHost.h"
#import "VFSArchiveInternal.h"
#import "VFSArchiveFile.h"
#import "VFSArchiveListing.h"
#import "Common.h"
#import "AppleDoubleEA.h"

const char *VFSArchiveHost::Tag = "arc_libarchive";

VFSArchiveHost::VFSArchiveHost(const char *_junction_path,
                               shared_ptr<VFSHost> _parent):
    VFSHost(_junction_path, _parent),
    m_Arc(0)
{
    assert(_parent);
}

VFSArchiveHost::~VFSArchiveHost()
{
    if(m_Arc != 0)
        archive_read_free(m_Arc);
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
    
    if(m_ArFile->Size() <= 0)
        return VFSError::ArclibFileFormat; // libarchive thinks that zero-bytes archives are OK, but I don't think so.
    
    m_Mediator = make_shared<VFSArchiveMediator>();
    m_Mediator->file = m_ArFile;
    
    m_Arc = SpawnLibarchive();
    
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
        bool isreg = (stat->st_mode & S_IFMT) == S_IFREG;
        
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
        
        if(isdir) m_TotalDirs++;
        if(isreg) m_TotalRegs++;
        m_TotalFiles++;
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

int VFSArchiveHost::CreateFile(const char* _path,
                       shared_ptr<VFSFile> &_target,
                       VFSCancelChecker _cancel_checker)
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
                                          VFSCancelChecker _cancel_checker)
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
                                 VFSCancelChecker _cancel_checker)
{
    if(_path[0] != '/') return false;
    char tmp[MAXPATHLEN];
    strcpy(tmp, _path);
    if(tmp[strlen(tmp)-1] != '/' ) strcat(tmp, "/"); // directories are stored with trailing slashes
    
    auto it = m_PathToDir.find(tmp);
    return it != m_PathToDir.end();
}

int VFSArchiveHost::Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker)
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

int VFSArchiveHost::IterateDirectoryListing(const char *_path, function<bool(const VFSDirEnt &_dirent)> _handler)
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
    if(!_path || _path[0] != '/') return 0;
    
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

int VFSArchiveHost::StatFS(const char *_path, VFSStatFS &_stat, VFSCancelChecker _cancel_checker)
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

bool VFSArchiveHost::ShouldProduceThumbnails() const
{
    return true;
}

unique_ptr<VFSArchiveState> VFSArchiveHost::ClosestState(uint32_t _requested_item)
{
    if(_requested_item == 0)
        return nullptr;

    lock_guard<mutex> lock(m_StatesLock);

    uint32_t best_delta = numeric_limits<uint32_t>::max();
    auto best = m_States.end();
    for(auto i = m_States.begin(); i != m_States.end(); ++i) {
        if(  (*i)->UID() < _requested_item ||
           ( (*i)->UID() == _requested_item && !(*i)->Consumed() ) ) {
                uint32_t delta = _requested_item - (*i)->UID();
                if(delta < best_delta) {
                    best_delta = delta;
                    best = i;
                    if(delta <= 1) // the closest one is found, no need to search further
                        break;
                }
            }
        }
    
    if(best != m_States.end()) {
        auto state = move(*best);
        m_States.erase(best);
        return move(state);
    }
    
    return nullptr;
}

void VFSArchiveHost::CommitState(unique_ptr<VFSArchiveState> _state)
{
    if(!_state)
        return;
    
    // will throw away archives positioned at last item - they are useless
    if(_state->UID() < m_LastItemUID) {
        lock_guard<mutex> lock(m_StatesLock);
        m_States.emplace_back(move(_state));
    }
}

int VFSArchiveHost::ArchiveStateForItem(const char *_filename, unique_ptr<VFSArchiveState> &_target)
{
    uint32_t requested_item = ItemUID(_filename);
    if(requested_item == 0)
        return VFSError::NotFound;
    
    auto state = ClosestState(requested_item);
    
    if(!state) {
        auto file = m_ArFile->Clone();
        int res = file->Open(VFSFile::OF_Read);
        if(res < 0)
            return res;
        
        auto new_state = make_unique<VFSArchiveState>(file, SpawnLibarchive());
        if( (res = new_state->Open()) < 0 ) {
            int rc = VFSError::FromLibarchive(new_state->Errno());
            return rc;
        }
        state = move(new_state);
    }
    else if( state->UID() == requested_item && !state->Consumed() ) {
        assert(state->Entry());
        _target = move(state);
        return VFSError::Ok;
    }
    
    bool found = false;
    char path[1024];
    strcpy(path, _filename+1); // skip first symbol, which is '/'
    // TODO: need special case for directories
    
    // consider case-insensitive comparison later
    struct archive_entry *entry;
    while( archive_read_next_header(state->Archive(), &entry) == ARCHIVE_OK )
        if( strcmp(path, archive_entry_pathname(entry)) == 0 ) {
            found = true;
            break;
        }
    
    if(!found)
        return VFSError::NotFound;
    
    state->SetEntry(entry, requested_item);
    _target = move(state);
    
    return VFSError::Ok;
}

struct archive* VFSArchiveHost::SpawnLibarchive()
{
    archive *arc = archive_read_new();
    archive_read_support_filter_all(arc);
    archive_read_support_format_ar(arc);
    archive_read_support_format_cpio(arc);
    archive_read_support_format_empty(arc);
    archive_read_support_format_lha(arc);
    archive_read_support_format_mtree(arc);
    archive_read_support_format_tar(arc);
    archive_read_support_format_xar(arc);
    archive_read_support_format_7zip(arc);
    archive_read_support_format_cab(arc);
    archive_read_support_format_iso9660(arc);
    archive_read_support_format_zip(arc);
    return arc;
}
