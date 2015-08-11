//
//  VFSArchiveHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 27.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/dirent.h>
#import "../3rd_party/libarchive/archive.h"
#import "../3rd_party/libarchive/archive_entry.h"
#import "VFSArchiveHost.h"
#import "VFSArchiveInternal.h"
#import "VFSArchiveFile.h"
#import "VFSArchiveListing.h"
#import "Common.h"
#import "AppleDoubleEA.h"

const char *VFSArchiveHost::Tag = "arc_libarchive";

class VFSArchiveHostConfiguration
{
public:
    string path;
    
    const char *Tag() const
    {
        return VFSArchiveHost::Tag;
    }
    
    const char *Junction() const
    {
        return path.c_str();
    }
    
    bool operator==(const VFSArchiveHostConfiguration&_rhs) const
    {
        return path == _rhs.path;
    }
};

VFSArchiveHost::VFSArchiveHost(const string &_path, const VFSHostPtr &_parent):
    VFSHost(_path.c_str(), _parent)
{
    assert(_parent);
    {
        VFSArchiveHostConfiguration config;
        config.path = _path;
        m_Configuration = VFSConfiguration( move(config) );
    }

    int rc = DoInit();
    if(rc < 0) {
        if(m_Arc != 0) { // TODO: ugly
            archive_read_free(m_Arc);
            m_Arc = 0;
        }
        throw VFSErrorException(rc);
    }
}

VFSArchiveHost::VFSArchiveHost(const VFSHostPtr &_parent, const VFSConfiguration &_config):
    VFSHost( _config.Get<VFSArchiveHostConfiguration>().path.c_str(), _parent),
    m_Configuration(_config)
{
    assert(_parent);
    int rc = DoInit();
    if(rc < 0) {
        if(m_Arc != 0) { // TODO: ugly
            archive_read_free(m_Arc);
            m_Arc = 0;
        }
        throw VFSErrorException(rc);
    }
}

VFSArchiveHost::~VFSArchiveHost()
{
    if(m_Arc != 0)
        archive_read_free(m_Arc);
}

const char *VFSArchiveHost::FSTag() const
{
    return Tag;
}

bool VFSArchiveHost::IsImmutableFS() const noexcept
{
    return true;
}

VFSConfiguration VFSArchiveHost::Configuration() const
{
    return m_Configuration;
}

VFSMeta VFSArchiveHost::Meta()
{
    VFSMeta m;
    m.Tag = Tag;
    m.SpawnWithConfig = [](const VFSHostPtr &_parent, const VFSConfiguration& _config) {
        return make_shared<VFSArchiveHost>(_parent, _config);
    };
    return m;
}

int VFSArchiveHost::DoInit()
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
    
    res = m_ArFile->Open(VFSFlags::OF_Read);
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
    uint32_t aruid = 0;

    {
    VFSArchiveDir root_dir;
    root_dir.full_path = "/";
    root_dir.name_in_parent  = "";
    m_PathToDir.emplace("/", move(root_dir));
    }

    VFSArchiveDir *parent_dir = &m_PathToDir["/"s];
    struct archive_entry *aentry;
    int ret;
    while ((ret = archive_read_next_header(m_Arc, &aentry)) == ARCHIVE_OK) {
        aruid++;
        const struct stat *stat = archive_entry_stat(aentry);
        char path[1024];
        path[0] = '/';
        strcpy(path + 1, archive_entry_pathname(aentry));
        
        if(strcmp(path, "/.") == 0) continue; // skip "." entry for ISO for example

        int path_len = (int)strlen(path);
        
        bool isdir = (stat->st_mode & S_IFMT) == S_IFDIR;
        bool isreg = (stat->st_mode & S_IFMT) == S_IFREG;
        bool issymlink = (stat->st_mode & S_IFMT) == S_IFLNK;
        
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
        unsigned entry_index_in_dir = 0;
        if(isdir) // check if it wasn't added before via FindOrBuildDir
            for(size_t i = 0, e = parent_dir->entries.size(); i<e; ++i) {
                auto &it = parent_dir->entries[i];
                if( (it.st.st_mode & S_IFMT) == S_IFDIR && it.name == short_name) {
                    entry = &it;
                    entry_index_in_dir = (unsigned)i;
                    break;
                }
            }
        
        if(entry == 0) {
            parent_dir->entries.push_back(VFSArchiveDirEntry());
            entry_index_in_dir = (unsigned)parent_dir->entries.size() - 1;
            entry = &parent_dir->entries.back();
            entry->name = short_name;
        }

        entry->aruid = aruid;
        entry->st = *stat;
        m_ArchivedFilesTotalSize += stat->st_size;
        
        if(m_EntryByUID.size() <= entry->aruid)
            m_EntryByUID.resize( entry->aruid+1 , make_pair(nullptr, 0) );
        m_EntryByUID[entry->aruid] = make_pair(parent_dir, entry_index_in_dir);
        
        if(issymlink) { // read any symlink values at archive opening time
            const char *link = archive_entry_symlink(aentry);
            Symlink symlink;
            symlink.uid = entry->aruid;
            if(!link || link[0] == 0) { // for invalid symlinks - mark them as invalid without resolving
                symlink.value = "";
                symlink.state = SymlinkState::Invalid;
            }
            else {
                symlink.value = link;
            }
            m_Symlinks.emplace(entry->aruid, symlink);
            m_NeedsPathResolving = true;
        }
    
        if(isdir) {
            // it's a directory
            if(path[strlen(path)-1] != '/') strcat(path, "/");
            if(m_PathToDir.find(path) == m_PathToDir.end())
            { // check if it wasn't added before via FindOrBuildDir
                char tmp[1024];
                strcpy(tmp, path);
                tmp[path_len-1] = 0;
                VFSArchiveDir dir;
                dir.full_path = path; // full_path is with trailing slash
                dir.name_in_parent = strrchr(tmp, '/')+1;
                m_PathToDir.emplace(path, move(dir));
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
        return &(*i).second;
    
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
    VFSArchiveDir entry;
    entry.full_path = _path_with_tr_sl;
    entry.name_in_parent  = entry_name;
    auto i2 = m_PathToDir.emplace(_path_with_tr_sl, move(entry));
    return &(*i2.first).second;
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
                                          unique_ptr<VFSListing> &_target,
                                          int _flags,
                                          VFSCancelChecker _cancel_checker)
{
    char path[MAXPATHLEN*2];
    int res = ResolvePathIfNeeded(_path, path, _flags);
    if(res < 0)
        return res;
    
    if(path[strlen(path)-1] != '/')
        strcat(path, "/");
    
    auto i = m_PathToDir.find(path);
    if(i == m_PathToDir.end())
        return VFSError::NotFound;

    auto listing = make_unique<VFSArchiveListing>(i->second, _path, _flags, SharedPtr());
    
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    
    _target = move(listing);
    
    return VFSError::Ok;
}

bool VFSArchiveHost::IsDirectory(const char *_path,
                                 int _flags,
                                 VFSCancelChecker _cancel_checker)
{
    if(!_path) return false;
    if(_path[0] != '/') return false;
    if(strcmp(_path, "/") == 0) return true;
        
    return VFSHost::IsDirectory(_path, _flags, _cancel_checker);
}

int VFSArchiveHost::Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker)
{
    if(!_path) return VFSError::InvalidCall;
    if(_path[0] != '/') return VFSError::NotFound;
    
    if(strlen(_path) == 1) {
        // we have no info about root dir - dummy here
        memset(&_st, 0, sizeof(_st));
        return VFSError::Ok;
    }
    
    char resolve_buf[MAXPATHLEN*2];
    int res = ResolvePathIfNeeded(_path, resolve_buf, _flags);
    if(res < 0)
        return res;
    
    if(auto it = FindEntry(resolve_buf)) {
        VFSStat::FromSysStat(it->st, _st);
        return VFSError::Ok;
    }
    return VFSError::NotFound;
}

int VFSArchiveHost::ResolvePathIfNeeded(const char *_path, char *_resolved_path, int _flags)
{
    if(!_path || !_resolved_path)
        return VFSError::InvalidCall;
    
    if( !m_NeedsPathResolving || (_flags & VFSFlags::F_NoFollow) )
        strcpy(_resolved_path, _path);
    else {
        int res = ResolvePath(_path, _resolved_path);
        if(res < 0)
            return res;
    }
    return VFSError::Ok;
}

int VFSArchiveHost::IterateDirectoryListing(const char *_path, function<bool(const VFSDirEnt &_dirent)> _handler)
{
    assert(_path != 0);
    if(_path[0] != '/')
        return VFSError::NotFound;

    char buf[1024];

    int ret = ResolvePathIfNeeded(_path, buf, 0);
    if(ret < 0)
        return ret;
        
    if(buf[strlen(buf)-1] != '/')
        strcat(buf, "/"); // we store directories with trailing slash
    
    auto i = m_PathToDir.find(buf);
    if(i == m_PathToDir.end())
        return VFSError::NotFound;
    
    VFSDirEnt dir;
    
    for(const auto &it: i->second.entries)
        {
            strcpy(dir.name, it.name.c_str());
            dir.name_len = it.name.length();
            
            if(S_ISDIR(it.st.st_mode)) dir.type = VFSDirEnt::Dir;
            else if(S_ISREG(it.st.st_mode)) dir.type = VFSDirEnt::Reg;
            else if(S_ISLNK(it.st.st_mode)) dir.type = VFSDirEnt::Link;
            else dir.type = VFSDirEnt::Unknown; // other stuff is not supported currently

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
    if(i == end(m_PathToDir))
        return 0;
    
    // ok, found dir, now let's find item
    size_t short_name_len = strlen(short_name);
    for(const auto &it: i->second.entries)
        if(it.name.length() == short_name_len && it.name.compare(short_name) == 0)
            return &it;
    
    return 0;
}

const VFSArchiveDirEntry *VFSArchiveHost::FindEntry(uint32_t _uid)
{
    if(!_uid || _uid >= m_EntryByUID.size())
        return nullptr;
    
    auto dir = m_EntryByUID[_uid].first;
    auto ind = m_EntryByUID[_uid].second;
    
    assert( ind < dir->entries.size() );
    return &dir->entries[ind];
}

int VFSArchiveHost::ResolvePath(const char *_path, char *_resolved_path)
{
    if(!_path || _path[0] != '/')
        return VFSError::NotFound;
    
    path p = _path;
    p = p.relative_path();
    if(p.filename() == ".") p.remove_filename();
    path result_path = "/";
    
    uint32_t result_uid = 0;
    for( auto &i: p ) {
        result_path /= i;
        
        auto entry = FindEntry(result_path.c_str());
        if(!entry)
            return VFSError::NotFound;
        
        result_uid = entry->aruid;
        
        if( (entry->st.st_mode & S_IFMT) == S_IFLNK ) {
            auto symlink_it = m_Symlinks.find(entry->aruid);
            if(symlink_it == end(m_Symlinks))
                return VFSError::NotFound;
            
            auto &s = symlink_it->second;
            if(s.state == SymlinkState::Unresolved)
                ResolveSymlink(s.uid);
            if( s.state != SymlinkState::Resolved )
                return VFSError::NotFound;; // current part points to nowhere
            
            result_path = s.target_path;
            result_uid = s.target_uid;
        }
    }
    
    strcpy(_resolved_path, result_path.c_str());
    return result_uid;
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
        
        if(m_States.size() > 32) { // purge the latest one
            auto last = begin(m_States);
            for(auto i = begin(m_States), e = end(m_States); i!=e; ++i)
                if((*i)->UID() > (*last)->UID())
                    last = i;
            m_States.erase(last);
        }
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
        if(!file)
            return VFSError::NotSupported;
        
        int res = file->Open(VFSFlags::OF_Read);
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
    uint32_t entry_uid = state->UID();
    while( archive_read_next_header(state->Archive(), &entry) == ARCHIVE_OK ) {
        entry_uid++;
        if( entry_uid == requested_item ) {
            found = true;
            break;
        }
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
    archive_read_support_format_lha(arc);
    archive_read_support_format_mtree(arc);
    archive_read_support_format_tar(arc);
    archive_read_support_format_xar(arc);
    archive_read_support_format_7zip(arc);
    archive_read_support_format_cab(arc);
    archive_read_support_format_iso9660(arc);
    archive_read_support_format_warc(arc);
    archive_read_support_format_xar(arc);
    archive_read_support_format_zip_seekable(arc);
    return arc;
}

void VFSArchiveHost::ResolveSymlink(uint32_t _uid)
{
    if(!_uid || _uid >= m_EntryByUID.size())
        return;
    
    auto iter = m_Symlinks.find(_uid);
    if(iter == end(m_Symlinks))
        return;
    
    lock_guard<recursive_mutex> lock(m_SymlinksResolveLock);
    auto &symlink = iter->second;
    if(symlink.state != SymlinkState::Unresolved)
        return; // was resolved in race condition
    
    symlink.state = SymlinkState::Invalid;
    
    if(symlink.value == "." ||
       symlink.value == "./") {
        // special treating for some weird cases
        symlink.state = SymlinkState::Loop;
        return;
    }
        
    path dir_path = m_EntryByUID[_uid].first->full_path;
    path symlink_path = symlink.value;
    path result_path;
    if(symlink_path.is_relative()) {
        result_path = dir_path;
//        printf("%s\n", result_path.c_str());
        
        // TODO: process possible ".." and entries
        // TODO: check for loops
        for(auto &i: symlink_path) {
            if( i != "." )
                result_path /= i;
//            printf("%s\n", result_path.c_str());
            
            uint32_t curr_uid = ItemUID(result_path.c_str());
            if(curr_uid == 0 || curr_uid == _uid)
                return;
            
            if( m_Symlinks.find(curr_uid) != end(m_Symlinks) ) {
                // current entry is a symlink - needs an additional processing
                auto &s = m_Symlinks[curr_uid];
                if(s.state == SymlinkState::Unresolved)
                    ResolveSymlink(s.uid);
                
                if( s.state != SymlinkState::Resolved )
                    return; // current part points to nowhere
                
                result_path = s.target_path;
            }
        }
    }
    else {
        result_path = symlink_path;
    }
    
    uint32_t result_uid = ItemUID(result_path.c_str());
    if(result_uid == 0)
        return;
    symlink.target_path = result_path.native();
    symlink.target_uid = result_uid;
    symlink.state = SymlinkState::Resolved;
}

const VFSArchiveHost::Symlink *VFSArchiveHost::ResolvedSymlink(uint32_t _uid)
{
    auto iter = m_Symlinks.find(_uid);
    if(iter == end(m_Symlinks))
        return nullptr;
    
    if(iter->second.state == SymlinkState::Unresolved)
        ResolveSymlink(_uid);
    
    return &iter->second;
}

int VFSArchiveHost::ReadSymlink(const char *_symlink_path, char *_buffer, size_t _buffer_size, VFSCancelChecker _cancel_checker)
{
    auto entry = FindEntry(_symlink_path);
    if(!entry)
        return VFSError::NotFound;
    
    if( (entry->st.st_mode & S_IFMT) != S_IFLNK )
        return VFSError::FromErrno(EINVAL);
        
    auto symlink_it = m_Symlinks.find(entry->aruid);
    if(symlink_it == end(m_Symlinks))
        return VFSError::NotFound;

    auto &val = symlink_it->second.value;
    
    if(val.size() >= _buffer_size)
        return VFSError::SmallBuffer;

    strcpy(_buffer, val.c_str());
    
    return VFSError::Ok;
}
