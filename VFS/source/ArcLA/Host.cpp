// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/dirent.h>
#include <Habanero/CFStackAllocator.h>
#include <Utility/PathManip.h>
#include <Utility/DataBlockAnalysis.h>
#include <libarchive/archive.h>
#include <libarchive/archive_entry.h>
#include <VFS/AppleDoubleEA.h>
#include "../ListingInput.h"
#include "Host.h"
#include "Internal.h"
#include "File.h"
#include "EncodingDetection.h"
#include <sys/param.h>

namespace nc::vfs {

using namespace arc;
using namespace std::literals;

const char *ArchiveHost::UniqueTag = "arc_libarchive";

class VFSArchiveHostConfiguration
{
public:
    std::string path;
    std::optional<std::string> password;
    
    const char *Tag() const
    {
        return ArchiveHost::UniqueTag;
    }
    
    const char *Junction() const
    {
        return path.c_str();
    }
    
    bool operator==(const VFSArchiveHostConfiguration&_rhs) const
    {
        return path == _rhs.path &&
           password == _rhs.password;
    }
};

static VFSConfiguration ComposeConfiguration(const std::string &_path, std::optional<std::string> _passwd)
{
    VFSArchiveHostConfiguration config;
    config.path = _path;
    config.password = std::move(_passwd);
    return VFSConfiguration( std::move(config) );
}

static void DecodeStringToUTF8(const void* _bytes,
                               size_t _sz,
                               CFStringEncoding _enc,
                               char *_buf,
                               size_t _buf_sz )
{
    CFStackAllocator alloc;
    auto str = CFStringCreateWithBytesNoCopy(alloc.Alloc(),
                                             (const UInt8*)_bytes,
                                             _sz,
                                             _enc,
                                             false,
                                             kCFAllocatorNull);
    if( str ) {
        if( auto utf8 = CFStringGetCStringPtr(str, kCFStringEncodingUTF8) )
            strcpy( _buf, utf8 );
        else
            CFStringGetCString(str, _buf, _buf_sz, kCFStringEncodingUTF8);
        CFRelease(str);
    }
    else {
        strcpy( _buf, (const char*)_bytes );
    }
}

ArchiveHost::ArchiveHost(const std::string &_path,
                         const VFSHostPtr &_parent,
                         std::optional<std::string> _password,
                         VFSCancelChecker _cancel_checker):
    Host(_path.c_str(), _parent, UniqueTag),
    m_Configuration( ComposeConfiguration(_path, move(_password)) )
{
    assert(_parent);
    int rc = DoInit(_cancel_checker);
    if(rc < 0) {
        if(m_Arc != 0) { // TODO: ugly
            archive_read_free(m_Arc);
            m_Arc = 0;
        }
        throw VFSErrorException(rc);
    }
}

ArchiveHost::ArchiveHost(const VFSHostPtr &_parent,
                         const VFSConfiguration &_config,
                         VFSCancelChecker _cancel_checker):
    Host( _config.Get<VFSArchiveHostConfiguration>().path.c_str(), _parent, UniqueTag),
    m_Configuration(_config)
{
    assert(_parent);
    int rc = DoInit(_cancel_checker);
    if(rc < 0) {
        if(m_Arc != 0) { // TODO: ugly
            archive_read_free(m_Arc);
            m_Arc = 0;
        }
        throw VFSErrorException(rc);
    }
}

ArchiveHost::~ArchiveHost()
{
    if(m_Arc != 0)
        archive_read_free(m_Arc);
}

bool ArchiveHost::IsImmutableFS() const noexcept
{
    return true;
}

VFSConfiguration ArchiveHost::Configuration() const
{
    return m_Configuration;
}

const VFSArchiveHostConfiguration &ArchiveHost::Config() const
{
    return m_Configuration.GetUnchecked<VFSArchiveHostConfiguration>();
}

VFSMeta ArchiveHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = [](const VFSHostPtr &_parent, const VFSConfiguration& _config, VFSCancelChecker _cancel_checker) {
        return std::make_shared<ArchiveHost>(_parent, _config, _cancel_checker);
    };
    return m;
}

int ArchiveHost::DoInit(VFSCancelChecker _cancel_checker)
{
    assert(m_Arc == 0);

    VFSFilePtr source_file;
    
    int res = Parent()->CreateFile(JunctionPath(), source_file, nil);
    if(res < 0)
        return res;
    
    res = source_file->Open(VFSFlags::OF_Read);
    if(res < 0)
        return res;
    
    if(source_file->Size() <= 0)
        return VFSError::ArclibFileFormat; // libarchive thinks that zero-bytes archives are OK, but I don't think so.
    
    if( Parent()->IsNativeFS() ) {
        m_ArFile = source_file;
    }
    else {
        auto wrapping = std::make_shared<VFSSeqToRandomROWrapperFile>(source_file);
        res = wrapping->Open(VFSFlags::OF_Read, _cancel_checker);
        if( res != VFSError::Ok )
            return res;
        m_ArFile = wrapping;
    }
    
    if( m_ArFile->GetReadParadigm() < VFSFile::ReadParadigm::Sequential ) {
        m_ArFile.reset();
        return VFSError::InvalidCall;
    }
    
    m_Mediator = std::make_shared<Mediator>();
    m_Mediator->file = m_ArFile;
    
    m_Arc = SpawnLibarchive();
    
    archive_read_set_callback_data(m_Arc, m_Mediator.get());
    archive_read_set_read_callback(m_Arc, Mediator::myread);
    archive_read_set_seek_callback(m_Arc, Mediator::myseek);
    res = archive_read_open1(m_Arc);
    if( res < 0 ) {
        archive_read_free(m_Arc);
        m_Arc = 0;
        m_Mediator.reset();
        m_ArFile.reset();
        return -1; // TODO: right error code
    }
    
    // we should fail is archive is encrypted and there's no password provided
    if( archive_read_has_encrypted_entries(m_Arc) > 0 && !Config().password )
        return VFSError::ArclibPasswordRequired;
    
    res = ReadArchiveListing();
    m_ArchiveFileSize = m_ArFile->Size();
    if( archive_read_has_encrypted_entries(m_Arc) > 0 && !Config().password )
        return VFSError::ArclibPasswordRequired;
    
    return res;
}

static bool SplitIntoFilenameAndParentPath(const char *_path,
                                            char *_filename,
                                            int _filename_sz,
                                            char *_parent_path,
                                            int _parent_path_sz)
{
    if( !_path || !_filename || !_parent_path )
        return false;

    const auto path_sz = strlen(_path);
    const auto slash = strrchr(_path, '/');
    if( !slash )
        return false;
    
    if( slash == _path + path_sz - 1 ) {
        std::string_view path( _path, path_sz - 1 );
        const auto second_slash_pos = path.rfind('/');
        if( second_slash_pos == path.npos )
            return false;
        const auto filename_sz = path_sz - second_slash_pos - 2;
        const auto parent_path_sz = second_slash_pos + 1;
        
        if( (int)filename_sz >= _filename_sz || (int)parent_path_sz >= _parent_path_sz )
            return false;
        
        strncpy( _filename, _path + second_slash_pos + 1, filename_sz );
        _filename[filename_sz] = 0;
        strncpy( _parent_path, _path, parent_path_sz );
        _parent_path[parent_path_sz] = 0;
    }
    else {
        const auto filename_sz = path_sz - (slash + 1 - _path);
        const auto parent_path_sz = slash - _path + 1;
        
        if( (int)filename_sz >= _filename_sz || (int)parent_path_sz >= _parent_path_sz )
            return false;
        
        strcpy( _filename, slash + 1 );
        strncpy( _parent_path, _path, parent_path_sz );
        _parent_path[parent_path_sz] = 0;
    }

    return true;
}

int ArchiveHost::ReadArchiveListing()
{
    assert(m_Arc != 0);
    uint32_t aruid = 0;

    {
    Dir root_dir;
    root_dir.full_path = "/";
    root_dir.name_in_parent  = "";
    m_PathToDir.emplace("/", std::move(root_dir));
    }

    std::optional<CFStringEncoding> detected_encoding;

    Dir *parent_dir = &m_PathToDir["/"s];
    struct archive_entry *aentry;
    int ret;
    while ((ret = archive_read_next_header(m_Arc, &aentry)) == ARCHIVE_OK) {
        aruid++;
        const struct stat *stat = archive_entry_stat(aentry);
        char path[1024];
        path[0] = '/';

        const auto entry_pathname = archive_entry_pathname(aentry);
        const auto entry_pathname_len = strlen(entry_pathname);
        if( entry_pathname_len == 0 )
            continue;
        const bool entry_has_heading_slash = entry_pathname[0] == '/';
  
        // pathname can be represented in ANY encoding.
        // if we already have figured out it - convert from it to UTF8 immediately
        if( detected_encoding ) {
            DecodeStringToUTF8(entry_pathname,
                               entry_pathname_len,
                               *detected_encoding,
                               path + (entry_has_heading_slash ? 0 : 1),
                               sizeof(path) - 2);
        }
        else {
            // if we don't know any specific encoding setting for this archive - check for UTF8
            // this checking is supposed to be very fast, for most archives it will return true
            if( IsValidUTF8String(entry_pathname, entry_pathname_len) ) {
                // we can path straightaway
                strcpy(path + (entry_has_heading_slash ? 0 : 1), entry_pathname);
            }
            else {
                // if this archive doesn't use a valid UTF8 encoding -
                // find it out and decode to UTF8
                if( !detected_encoding )
                    detected_encoding = DetectEncoding(entry_pathname, entry_pathname_len);
                
                DecodeStringToUTF8(entry_pathname,
                                   entry_pathname_len,
                                   *detected_encoding,
                                   path + (entry_has_heading_slash ? 0 : 1),
                                   sizeof(path) - 2);
            }
        }
        
        if(strcmp(path, "/.") == 0) continue; // skip "." entry for ISO for example

        int path_len = (int)strlen(path);
        
        const auto isdir = (stat->st_mode & S_IFMT) == S_IFDIR;
        const auto isreg = (stat->st_mode & S_IFMT) == S_IFREG;
        const auto issymlink = (stat->st_mode & S_IFMT) == S_IFLNK;
        
        char short_name[256];
        char parent_path[1024];
        if( !SplitIntoFilenameAndParentPath(path,
                                            short_name, sizeof(short_name),
                                            parent_path, sizeof(parent_path)) )
           continue;
        
        if(parent_dir->full_path != parent_path)
            parent_dir = FindOrBuildDir(parent_path);
                
        DirEntry *entry = 0;
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
            parent_dir->entries.emplace_back();
            entry_index_in_dir = (unsigned)parent_dir->entries.size() - 1;
            entry = &parent_dir->entries.back();
            entry->name = short_name;
        }

        entry->aruid = aruid;
        entry->st = *stat;
        m_ArchivedFilesTotalSize += stat->st_size;
        
        if(m_EntryByUID.size() <= entry->aruid)
            m_EntryByUID.resize( entry->aruid+1 , std::make_pair(nullptr, 0) );
        m_EntryByUID[entry->aruid] = std::make_pair(parent_dir, entry_index_in_dir);
        
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
                Dir dir;
                dir.full_path = path; // full_path is with trailing slash
                dir.name_in_parent = strrchr(tmp, '/')+1;
                m_PathToDir.emplace(path, std::move(dir));
            }
        }
        
        if(isdir) m_TotalDirs++;
        if(isreg) m_TotalRegs++;
        m_TotalFiles++;
    }
    
    m_LastItemUID = aruid - 1;
    
    UpdateDirectorySize(m_PathToDir["/"], "/");
    
    if( ret == ARCHIVE_EOF )
        return VFSError::Ok;

    printf("%s\n", archive_error_string(m_Arc));
    
    if( ret == ARCHIVE_WARN )
        return VFSError::Ok;

    return VFSError::GenericError;
}

uint64_t ArchiveHost::UpdateDirectorySize( Dir &_directory, const std::string &_path )
{
    uint64_t size = 0;
    for( auto &e: _directory.entries )
        if( S_ISDIR(e.st.st_mode) ) {
            const auto subdir_path = _path + e.name + "/";
            const auto it = m_PathToDir.find(subdir_path);
            if( it != end(m_PathToDir) ) {
                const auto subdir_sz = UpdateDirectorySize(it->second, subdir_path);
                e.st.st_size = subdir_sz;
                size += subdir_sz;
            }
        }
        else if( S_ISREG(e.st.st_mode) )
            size += e.st.st_size;
    
    _directory.content_size = size;
    
    return size;
}

Dir* ArchiveHost::FindOrBuildDir(const char* _path_with_tr_sl)
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
    Dir entry;
    entry.full_path = _path_with_tr_sl;
    entry.name_in_parent  = entry_name;
    auto i2 = m_PathToDir.emplace(_path_with_tr_sl, std::move(entry));
    return &(*i2.first).second;
}

void ArchiveHost::InsertDummyDirInto(Dir *_parent, const char* _dir_name)
{
    _parent->entries.emplace_back();
    auto &entry = _parent->entries.back();
    entry.name = _dir_name;
    memset(&entry.st, 0, sizeof(entry.st));
    entry.st.st_mode = S_IFDIR;
}

int ArchiveHost::CreateFile(const char* _path,
                            std::shared_ptr<VFSFile> &_target,
                            const VFSCancelChecker &_cancel_checker)
{
    auto file = std::make_shared<File>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

int ArchiveHost::FetchDirectoryListing(const char *_path,
                                       std::shared_ptr<VFSListing> &_target,
                                       unsigned long _flags,
                                       [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
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
    
    const auto &directory = i->second;
    
    using nc::base::variable_container;
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(_path);
    listing_source.atimes.reset( variable_container<>::type::dense );
    listing_source.mtimes.reset( variable_container<>::type::dense );
    listing_source.ctimes.reset( variable_container<>::type::dense );
    listing_source.btimes.reset( variable_container<>::type::dense );
    listing_source.unix_flags.reset( variable_container<>::type::dense );
    listing_source.uids.reset( variable_container<>::type::dense );
    listing_source.gids.reset( variable_container<>::type::dense );
    listing_source.sizes.reset( variable_container<>::type::dense );
    listing_source.symlinks.reset( variable_container<>::type::sparse );

    if( !(_flags & VFSFlags::F_NoDotDot) ) {
        listing_source.filenames.emplace_back( ".." );
        listing_source.unix_types.emplace_back( DT_DIR );
        listing_source.unix_modes.emplace_back( S_IRUSR | S_IXUSR | S_IFDIR );
        auto curtime = time(0); // it's better to show date of archive itself
        listing_source.atimes.insert(0, curtime );
        listing_source.btimes.insert(0, curtime );
        listing_source.ctimes.insert(0, curtime );
        listing_source.mtimes.insert(0, curtime );
        listing_source.sizes.insert( 0, directory.content_size );
        listing_source.uids.insert( 0, 0 );
        listing_source.gids.insert( 0, 0 );
        listing_source.unix_flags.insert( 0, 0);
    }
    
    for( auto &entry: directory.entries ) {
        listing_source.filenames.emplace_back( entry.name );
        listing_source.unix_types.emplace_back( IFTODT(entry.st.st_mode) );

        int index = int(listing_source.filenames.size() - 1);
        auto stat = entry.st;
        if( S_ISLNK(entry.st.st_mode) )
            if( auto symlink = ResolvedSymlink(entry.aruid) ) {
                listing_source.symlinks.insert( index, symlink->value );
                if( symlink->state == SymlinkState::Resolved )
                    if( auto target_entry = FindEntry(symlink->target_uid) )
                        stat = target_entry->st;
            }
        
        listing_source.unix_modes.emplace_back( stat.st_mode );
        listing_source.sizes.insert( index,
//                                    S_ISDIR(stat.st_mode) ?
//                                        VFSListingInput::unknown_size :
                                        stat.st_size );
        listing_source.atimes.insert( index, stat.st_atime );
        listing_source.ctimes.insert( index, stat.st_ctime );
        listing_source.mtimes.insert( index, stat.st_mtime );
        listing_source.btimes.insert( index, stat.st_birthtime );
        listing_source.uids.insert( index, stat.st_uid );
        listing_source.gids.insert( index, stat.st_gid );
        listing_source.unix_flags.insert( index, stat.st_flags );
    }
    
    _target = VFSListing::Build(std::move(listing_source));
    return 0;
}

bool ArchiveHost::IsDirectory(const char *_path,
                                 unsigned long _flags,
                                 const VFSCancelChecker &_cancel_checker)
{
    if(!_path) return false;
    if(_path[0] != '/') return false;
    if(strcmp(_path, "/") == 0) return true;
        
    return Host::IsDirectory(_path, _flags, _cancel_checker);
}

int ArchiveHost::Stat(const char *_path,
                      VFSStat &_st,
                      unsigned long _flags,
                      [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( !_path )
        return VFSError::InvalidCall;
    if( _path[0] != '/' )
        return VFSError::NotFound;
    
    if( strlen(_path) == 1 ) {
        // we have no info about root dir - dummy here
        memset(&_st, 0, sizeof(_st));
        _st.mode = S_IRUSR | S_IFDIR;
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

int ArchiveHost::ResolvePathIfNeeded(const char *_path, char *_resolved_path, unsigned long _flags)
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

int ArchiveHost::IterateDirectoryListing(const char *_path,
                                         const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
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
            dir.name_len = uint16_t(it.name.length());
            
            if(S_ISDIR(it.st.st_mode)) dir.type = VFSDirEnt::Dir;
            else if(S_ISREG(it.st.st_mode)) dir.type = VFSDirEnt::Reg;
            else if(S_ISLNK(it.st.st_mode)) dir.type = VFSDirEnt::Link;
            else dir.type = VFSDirEnt::Unknown; // other stuff is not supported currently

            if(!_handler(dir))
                break;
        }
    
    return VFSError::Ok;
}

uint32_t ArchiveHost::ItemUID(const char* _filename)
{
    auto it = FindEntry(_filename);
    if(it)
        return it->aruid;
    return 0;
}

const DirEntry *ArchiveHost::FindEntry(const char* _path)
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
    
    if( strcmp(short_name, "..") == 0 ) { // special treatment for dot-dot
        char tmp[1024];
        if( !GetDirectoryContainingItemFromPath(buf, tmp) )
            return nullptr;
        return FindEntry(tmp);
    }
    
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

const DirEntry *ArchiveHost::FindEntry(uint32_t _uid)
{
    if(!_uid || _uid >= m_EntryByUID.size())
        return nullptr;
    
    auto dir = m_EntryByUID[_uid].first;
    auto ind = m_EntryByUID[_uid].second;
    
    assert( ind < dir->entries.size() );
    return &dir->entries[ind];
}

int ArchiveHost::ResolvePath(const char *_path, char *_resolved_path)
{
    if(!_path || _path[0] != '/')
        return VFSError::NotFound;
    
    boost::filesystem::path p = _path;
    p = p.relative_path();
    if(p.filename() == ".") p.remove_filename();
    boost::filesystem::path result_path = "/";
    
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

int ArchiveHost::StatFS([[maybe_unused]] const char *_path,
                        VFSStatFS &_stat,
                        [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
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

bool ArchiveHost::ShouldProduceThumbnails() const
{
    return true;
}

std::unique_ptr<State> ArchiveHost::ClosestState(uint32_t _requested_item)
{
    if(_requested_item == 0)
        return nullptr;

    std::lock_guard<std::mutex> lock(m_StatesLock);

    uint32_t best_delta = std::numeric_limits<uint32_t>::max();
    auto best = m_States.end();
    for( auto i = m_States.begin(), e = m_States.end(); i != e; ++i )
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
    
    if( best != m_States.end() ) {
        auto state = move(*best);
        m_States.erase(best);
        return state;
    }
    
    return nullptr;
}

void ArchiveHost::CommitState(std::unique_ptr<State> _state)
{
    if(!_state)
        return;
    
    // will throw away archives positioned at last item - they are useless
    if(_state->UID() < m_LastItemUID) {
        std::lock_guard<std::mutex> lock(m_StatesLock);
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

int ArchiveHost::ArchiveStateForItem(const char *_filename, std::unique_ptr<State> &_target)
{
    uint32_t requested_item = ItemUID(_filename);
    if(requested_item == 0)
        return VFSError::NotFound;
    
    auto state = ClosestState(requested_item);
    
    if(!state) {
        VFSFilePtr file;
        
        // bad-bad design decision, need to refactor this later
        if( auto wrapping = std::dynamic_pointer_cast<VFSSeqToRandomROWrapperFile>(m_ArFile) )
            file = wrapping->Share();
        else
            file = m_ArFile->Clone();

        if(!file)
            return VFSError::NotSupported;
        
        int res = file->IsOpened() ?
            VFSError::Ok :
            file->Open(VFSFlags::OF_Read);
        if(res < 0)
            return res;
        
        auto new_state = std::make_unique<State>(file, SpawnLibarchive());
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

struct archive* ArchiveHost::SpawnLibarchive()
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
    if( Config().password )
        archive_read_add_passphrase(arc, Config().password->c_str());
    return arc;
}

void ArchiveHost::ResolveSymlink(uint32_t _uid)
{
    if(!_uid || _uid >= m_EntryByUID.size())
        return;
    
    const auto iter = m_Symlinks.find(_uid);
    if(iter == end(m_Symlinks))
        return;
    
    std::lock_guard<std::recursive_mutex> lock(m_SymlinksResolveLock);
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
        
    const boost::filesystem::path dir_path = m_EntryByUID[_uid].first->full_path;
    const boost::filesystem::path symlink_path = symlink.value;
    boost::filesystem::path result_path;
    if( symlink_path.is_relative() ) {
        result_path = dir_path;
//        printf("%s\n", result_path.c_str());
        
        // TODO: check for loops
        for(auto &i: symlink_path) {
            if( i != "." ) {
                if( i != ".." ) {
                    result_path /= i;
                }
                else {
                    if( result_path.filename() == "." )
                        result_path.remove_filename();
                    result_path = result_path.parent_path();
                }
            }
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

const ArchiveHost::Symlink *ArchiveHost::ResolvedSymlink(uint32_t _uid)
{
    auto iter = m_Symlinks.find(_uid);
    if(iter == end(m_Symlinks))
        return nullptr;
    
    if(iter->second.state == SymlinkState::Unresolved)
        ResolveSymlink(_uid);
    
    return &iter->second;
}

int ArchiveHost::ReadSymlink(const char *_symlink_path,
                             char *_buffer,
                             size_t _buffer_size,
                             [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
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

}
