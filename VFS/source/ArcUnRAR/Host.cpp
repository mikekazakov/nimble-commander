// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/PathManip.h>
#include "../Native/Host.h"
#include "../ListingInput.h"
#include "Host.h"
#include "Internals.h"
#include "File.h"
#include <sys/dirent.h>
#include <sys/param.h>

namespace nc::vfs {

using namespace unrar;

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

const char *UnRARHost::UniqueTag = "arc_unrar";

class VFSArchiveUnRARHostConfiguration
{
public:
    std::string path;
    
    const char *Tag() const
    {
        return UnRARHost::UniqueTag;
    }
    
    const char *Junction() const
    {
        return path.c_str();
    }
    
    bool operator==(const VFSArchiveUnRARHostConfiguration&_rhs) const
    {
        return path == _rhs.path;
    }
};

static VFSConfiguration ComposeConfiguration( const std::string &_path )
{
    VFSArchiveUnRARHostConfiguration config;
    config.path = _path;
    return VFSConfiguration( std::move(config) );
}

UnRARHost::UnRARHost(const std::string &_path):
    Host(_path.c_str(), VFSNativeHost::SharedHost(), UniqueTag),
    m_SeekCacheControl(dispatch_queue_create(NULL, NULL)),
    m_Configuration( ComposeConfiguration(_path) )
{
    int rc = DoInit();
    if(rc < 0)
        throw VFSErrorException(rc);
}

UnRARHost::UnRARHost(const VFSHostPtr &_parent, const VFSConfiguration &_config):
    Host(_config.Get<VFSArchiveUnRARHostConfiguration>().path.c_str(), _parent, UniqueTag),
    m_SeekCacheControl(dispatch_queue_create(NULL, NULL)),
    m_Configuration(_config)
{
    if(!_parent->IsNativeFS())
        throw VFSErrorException(VFSError::InvalidCall);
    
    int rc = DoInit();
    if(rc < 0)
        throw VFSErrorException(rc);
}

UnRARHost::~UnRARHost()
{
    dispatch_sync(m_SeekCacheControl, ^{});
    dispatch_release(m_SeekCacheControl);
}

bool UnRARHost::IsImmutableFS() const noexcept
{
    return true;
}

VFSConfiguration UnRARHost::Configuration() const
{
    return m_Configuration;
}

VFSMeta UnRARHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = [](const VFSHostPtr &_parent, const VFSConfiguration& _config, VFSCancelChecker _cancel_checker) {
        return std::make_shared<UnRARHost>(_parent, _config);
    };
    return m;
}

bool UnRARHost::IsRarArchive(const char *_archive_native_path)
{
    if(_archive_native_path == nullptr ||
       _archive_native_path[0] != '/')
        return false;

    // check extension
    char ext[MAXPATHLEN];
    if(!GetExtensionFromPath(_archive_native_path, ext))
        return false;
    std::string sext(ext);
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

int UnRARHost::DoInit()
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

int UnRARHost::InitialReadFileList(void *_rar_handle)
{
    auto root_dir = m_PathToDir.emplace("/", Directory());
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
        std::string parent_dir_path(utf8buf, last_sl + 1 - utf8buf);

        std::string entry_short_name(last_sl + 1);
        
        Directory    *parent_dir = FindOrBuildDirectory(parent_dir_path);
        Entry        *entry = nullptr;
        
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
            FindOrBuildDirectory(std::string(utf8buf) + '/')->time = entry->time;
        
		if ((proc_file_ret = RARProcessFile(_rar_handle, RAR_SKIP, NULL, NULL)) != 0)
            return VFSError::GenericError; // TODO: need an adequate error code here
	}
    
    if(read_head_ret == ERAR_MISSING_PASSWORD)
        return VFSArchiveUnRARErrorToVFSError(read_head_ret);
    
    m_LastItemUID = uuid - 1;
    m_IsSolidArchive = solid_items > 0;
    
    return 0;
}

Directory *UnRARHost::FindOrBuildDirectory(const std::string& _path_with_tr_sl)
{
    auto i = m_PathToDir.find(_path_with_tr_sl);
    if(i != m_PathToDir.end())
        return &i->second;
    
    auto last_sl = _path_with_tr_sl.size() - 2;
    while(_path_with_tr_sl[last_sl] != '/')
        --last_sl;
    
    auto parent_dir = FindOrBuildDirectory( std::string(_path_with_tr_sl, 0, last_sl + 1) );
    auto &entries = parent_dir->entries;

    std::string short_name(_path_with_tr_sl, last_sl + 1, _path_with_tr_sl.size() - last_sl - 2);
    
    if( find_if(begin(entries), end(entries), [&](const auto &_i) {return _i.name == short_name;} )
       == end(parent_dir->entries) ) {
        parent_dir->entries.emplace_back();
        parent_dir->entries.back().name = short_name;
    }
    
    auto dir = m_PathToDir.emplace(_path_with_tr_sl, Directory());
    dir.first->second.full_path = _path_with_tr_sl;
    return &dir.first->second;
}

int UnRARHost::FetchDirectoryListing(const char *_path,
                                     std::shared_ptr<VFSListing> &_target,
                                     unsigned long _flags,
                                     const VFSCancelChecker &_cancel_checker)
{
    auto dir = FindDirectory(_path);
    if(!dir)
        return VFSError::NotFound;

    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(_path);
    listing_source.atimes.reset( variable_container<>::type::dense );
    listing_source.mtimes.reset( variable_container<>::type::dense );
    listing_source.ctimes.reset( variable_container<>::type::dense );
    listing_source.btimes.reset( variable_container<>::type::dense );
    listing_source.sizes.reset( variable_container<>::type::dense );
    
    if( !(_flags & VFSFlags::F_NoDotDot) ) {
        listing_source.filenames.emplace_back( ".." );
        listing_source.unix_types.emplace_back( DT_DIR );
        listing_source.unix_modes.emplace_back( S_IRUSR | S_IXUSR | S_IFDIR );
        auto curtime = time(0); // it's better to show date of archive itself
        listing_source.atimes.insert(0, curtime );
        listing_source.btimes.insert(0, curtime );
        listing_source.ctimes.insert(0, curtime );
        listing_source.mtimes.insert(0, curtime );
        listing_source.sizes.insert( 0, ListingInput::unknown_size );
    }
    
    for( auto &entry: dir->entries ) {
        listing_source.filenames.emplace_back( entry.name );
        listing_source.unix_types.emplace_back( entry.isdir ? DT_DIR : DT_REG );
        listing_source.unix_modes.emplace_back( S_IRUSR | (entry.isdir ? S_IFDIR : S_IFREG) );
        int index = int(listing_source.filenames.size() - 1);
        listing_source.sizes.insert( index,
                                    entry.isdir ?
                                        ListingInput::unknown_size :
                                        entry.unpacked_size );
        listing_source.atimes.insert( index, entry.time );
        listing_source.ctimes.insert( index, entry.time );
        listing_source.btimes.insert( index, entry.time );
        listing_source.mtimes.insert( index, entry.time );
    }
    
    _target = VFSListing::Build(std::move(listing_source));
    return VFSError::Ok;
}

int UnRARHost::IterateDirectoryListing(const char *_path,
                                       const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    auto dir = FindDirectory(_path);
    if(!dir)
        return VFSError::NotFound;

    VFSDirEnt dirent;
    for(auto &it: dir->entries)
    {
        strcpy(dirent.name, it.name.c_str());
        dirent.name_len = uint16_t(it.name.length());
        dirent.type = it.isdir ? VFSDirEnt::Dir : VFSDirEnt::Reg;

        if(!_handler(dirent))
            break;
    }
    
    return 0;
}

const Directory *UnRARHost::FindDirectory(const std::string& _path) const
{
    std::string path = _path;
    if(path.back() != '/')
        path += '/';

    auto i = m_PathToDir.find(path);
    if(i == m_PathToDir.end())
        return nullptr;
    
    return &i->second;
}

int UnRARHost::Stat(const char *_path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    static VFSStat::meaningT m;
    static std::once_flag once;
    call_once(once, []{
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

const Entry *UnRARHost::FindEntry(const std::string &_full_path) const
{
    if(_full_path.empty())
        return nullptr;
    if(_full_path[0] != '/')
        return nullptr;
    if(_full_path.length() == 1 && _full_path[0] == '/')
        return nullptr;
    
    std::string path = _full_path;
    if(path.back() == '/')
        path.pop_back();
    
    auto last_sl = path.rfind('/');
    assert(last_sl != std::string::npos);
    std::string parent_dir(path, 0, last_sl + 1);
    
    auto directory = m_PathToDir.find(parent_dir);
    if(directory == m_PathToDir.end())
        return nullptr;

    std::string filename(path.c_str() + last_sl + 1);
    for(const auto &it: directory->second.entries)
        if(it.name == filename)
            return &it;

    return nullptr;
}

uint32_t UnRARHost::ItemUUID(const std::string& _filename) const
{
    if(auto entry = FindEntry(_filename))
        return entry->uuid;
    return 0;
}

std::unique_ptr<unrar::SeekCache> UnRARHost::SeekCache(uint32_t _requested_item)
{
    if(_requested_item == 0)
        return 0;
    
    __block std::unique_ptr<unrar::SeekCache> res;
    
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
        res = std::make_unique<unrar::SeekCache>();
        res->rar_handle = rar_file;
    });
    
    auto tmp = move(res);
    return tmp;
}

void UnRARHost::CommitSeekCache(std::unique_ptr<unrar::SeekCache> _sc)
{
    assert(_sc->uid < m_LastItemUID);
    __block std::unique_ptr<unrar::SeekCache> sc(move(_sc));
    dispatch_sync(m_SeekCacheControl, ^{
        m_SeekCaches.push_back(move(sc));
    });
}

int UnRARHost::CreateFile(const char* _path,
                          std::shared_ptr<VFSFile> &_target,
                          const VFSCancelChecker &_cancel_checker)
{
    auto file = std::make_shared<unrar::File>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

bool UnRARHost::ShouldProduceThumbnails() const
{
    return false;
}

uint32_t UnRARHost::LastItemUUID() const
{
    return m_LastItemUID;
};

int UnRARHost::StatFS(const char *_path, VFSStatFS &_stat, const VFSCancelChecker &_cancel_checker)
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

}
