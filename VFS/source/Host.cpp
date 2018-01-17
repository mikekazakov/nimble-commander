// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/PathManip.h>
#include "ListingInput.h"
#include "../include/VFS/Host.h"

namespace nc::vfs {

HostDirObservationTicket::HostDirObservationTicket() noexcept:
    m_Ticket(0),
    m_Host()
{
}

HostDirObservationTicket::HostDirObservationTicket(unsigned long _ticket, weak_ptr<VFSHost> _host) noexcept:
    m_Ticket(_ticket),
    m_Host(_host)
{
    assert( (_ticket == 0 && _host.expired()) || (_ticket != 0 && !_host.expired()) );
}

HostDirObservationTicket::HostDirObservationTicket(HostDirObservationTicket &&_rhs) noexcept:
    m_Ticket(_rhs.m_Ticket),
    m_Host(move(_rhs.m_Host))
{
    _rhs.m_Ticket = 0;
}

HostDirObservationTicket::~HostDirObservationTicket()
{
    reset();
}

HostDirObservationTicket &HostDirObservationTicket::operator=(HostDirObservationTicket &&_rhs)
{
    reset();
    m_Ticket = _rhs.m_Ticket;
    m_Host = move(_rhs.m_Host);
    _rhs.m_Ticket = 0;
    return *this;
}

bool HostDirObservationTicket::valid() const noexcept
{
    return m_Ticket != 0;
}

HostDirObservationTicket::operator bool() const noexcept
{
    return valid();
}

void HostDirObservationTicket::reset()
{
    if(valid()) {
        if(auto h = m_Host.lock())
            h->StopDirChangeObserving(m_Ticket);
        m_Ticket = 0;
        m_Host.reset();
    }
}

const char *Host::UniqueTag = "nullfs";

class VFSHostConfiguration
{
public:
    const char *Tag() const
    {
        return Host::UniqueTag;
    }
        
    const char *Junction() const
    {
        return "";
    }
        
    bool operator==(const VFSHostConfiguration&) const
    {
        return true;
    }
};
    
Host::Host(const char *_junction_path,
           const shared_ptr<Host> &_parent,
           const char *_fs_tag):
    m_JunctionPath(_junction_path ? _junction_path : ""),
    m_Parent(_parent),
    m_Tag(_fs_tag),
    m_Features(0)
{
}

Host::~Host()
{
    if( m_OnDesctruct )
        m_OnDesctruct( this );
}

shared_ptr<VFSHost> Host::SharedPtr()
{
    return shared_from_this();
}

shared_ptr<const VFSHost> Host::SharedPtr() const
{
    return shared_from_this();
}

const char *Host::Tag() const noexcept
{
    return m_Tag;
}

const VFSHostPtr& Host::Parent() const noexcept
{
    return m_Parent;    
}

const char* Host::JunctionPath() const noexcept
{
    return m_JunctionPath.c_str();
}

bool Host::IsWritable() const
{
    return false;
}

bool Host::IsWritableAtPath(const char *_dir) const
{
    return IsWritable();
}

int Host::CreateFile(const char* _path,
                     shared_ptr<VFSFile> &_target,
                     const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

bool Host::IsDirectory(const char *_path,
                       unsigned long _flags,
                       const VFSCancelChecker &_cancel_checker)
{
    VFSStat st;
    if(Stat(_path, st, _flags, _cancel_checker) < 0)
        return false;
    
    return (st.mode & S_IFMT) == S_IFDIR;
}

bool Host::IsSymlink(const char *_path,
                     unsigned long _flags,
                     const VFSCancelChecker &_cancel_checker)
{
    VFSStat st;
    if(Stat(_path, st, _flags, _cancel_checker) < 0)
        return false;
    
    return (st.mode & S_IFMT) == S_IFLNK;
}

bool Host::FindLastValidItem(const char *_orig_path,
                             char *_valid_path,
                             unsigned long _flags,
                             const VFSCancelChecker &_cancel_checker)
{
    // TODO: maybe it's better to go left-to-right than right-to-left
    if(_orig_path[0] != '/') return false;
    
    char tmp[MAXPATHLEN*8];
    strcpy(tmp, _orig_path);
    if(IsPathWithTrailingSlash(tmp) &&
       strcmp(tmp, "/") != 0 )
        tmp[strlen(tmp)-1] = 0; // cut trailing slash if any

    VFSStat st;
    while(true)
    {
        if(_cancel_checker && _cancel_checker())
            return false;
  
        int ret = Stat(tmp, st, _flags, _cancel_checker);
        if(ret == 0)
        {
            strcpy(_valid_path, tmp);
            return true;
        }
            
        char *sl = strrchr(tmp, '/');
        assert(sl != 0);
        if(sl == tmp) return false;
        *sl = 0;
    }

    return false;
}

ssize_t Host::CalculateDirectorySize(const char *_path,
                                     const VFSCancelChecker &_cancel_checker)
{
    if(_path == 0 || _path[0] != '/')
        return VFSError::InvalidCall;
    
    queue<path> look_paths;
    int64_t total_size = 0;
    
    look_paths.emplace(_path);
    while( !look_paths.empty() ) {
        if(_cancel_checker && _cancel_checker()) // check if we need to quit
            return VFSError::Cancelled;
        
        IterateDirectoryListing(look_paths.front().c_str(), [&](const VFSDirEnt& _dirent){
            path full_path = look_paths.front() / _dirent.name;
            if(_dirent.type == VFSDirEnt::Dir)
                look_paths.emplace(move(full_path));
            else {
                VFSStat stat;
                if(Stat(full_path.c_str(), stat, VFSFlags::F_NoFollow, 0) == 0)
                    total_size += stat.size;
            }
            return true;
        });
        look_paths.pop();
    }
    
    return total_size;
}

bool Host::IsDirChangeObservingAvailable(const char *_path)
{
    return false;
}

HostDirObservationTicket Host::DirChangeObserve(const char *_path, function<void()> _handler)
{
    return {};
}

void Host::StopDirChangeObserving(unsigned long _ticket)
{
}

int Host::Stat(const char *_path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::IterateDirectoryListing(const char *_path, const function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    // TODO: write a default implementation using listing fetching.
    // it will be less efficient, but for some FS like PS it will be ok
    return VFSError::NotSupported;
}

int Host::StatFS(const char *_path, VFSStatFS &_stat, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::Unlink(const char *_path, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::Trash(const char *_path, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::CreateDirectory(const char* _path, int _mode, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::ReadSymlink(const char *_path, char *_buffer, size_t _buffer_size, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::CreateSymlink(const char *_symlink_path, const char *_symlink_value, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::SetTimes(const char *_path,
                   optional<time_t> _birth_time,
                   optional<time_t> _mod_time,
                   optional<time_t> _chg_time,
                   optional<time_t> _acc_time,
                   const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

bool Host::ShouldProduceThumbnails() const
{
    return false;
}

int Host::RemoveDirectory(const char *_path, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::Rename(const char *_old_path, const char *_new_path, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::SetPermissions(const char *_path, uint16_t _mode, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::GetXAttrs(const char *_path, vector< pair<string, vector<uint8_t>>> &_xattrs)
{
    return VFSError::NotSupported;
}

const shared_ptr<Host> &Host::DummyHost()
{
    static auto host = make_shared<Host>("", nullptr, Host::UniqueTag);
    return host;
}

VFSConfiguration Host::Configuration() const
{
    static auto config = VFSConfiguration( VFSHostConfiguration() );
    return config;
}

bool Host::Exists(const char *_path, const VFSCancelChecker &_cancel_checker)
{
    VFSStat st;
    return Stat(_path, st, 0, _cancel_checker) == 0;
}

bool Host::IsImmutableFS() const noexcept
{
    return false;
}

bool Host::IsNativeFS() const noexcept
{
    return false;
}

bool Host::ValidateFilename(const char *_filename) const
{
    if( !_filename )
        return false;

    const auto max_filename_len = 256;
    const auto i = _filename, e = _filename + strlen(_filename);
    if( i == e || e - i > max_filename_len )
        return false;

    static const char invalid_chars[] = ":\\/\r\t\n";
    return find_first_of(i, e, begin(invalid_chars), end(invalid_chars)) == e;
}

int Host::FetchDirectoryListing(const char *_path,
                                shared_ptr<Listing> &_target,
                                unsigned long _flags,
                                const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::FetchSingleItemListing(const char *_path,
                                 shared_ptr<Listing> &_target,
                                 unsigned long _flags,
                                 const VFSCancelChecker &_cancel_checker)
{
    // as we came here - there's no special implementation in derived class,
    // so need to try to emulate it with available methods.
    
    if( !_path || _path[0] != '/' )
        return VFSError::InvalidCall;
    
    if( _cancel_checker && _cancel_checker() )
        return VFSError::Cancelled;
    
    char path[MAXPATHLEN], directory[MAXPATHLEN], filename[MAXPATHLEN];
    strcpy(path, _path);
    
    if( !EliminateTrailingSlashInPath(path) ||
        !GetDirectoryContainingItemFromPath(path, directory) ||
        !GetFilenameFromPath(path, filename) )
        return VFSError::InvalidCall;
    
    VFSStat lstat;

    int ret = Stat(_path, lstat, VFSFlags::F_NoFollow);
    if( ret != 0 )
        return ret;
    
    nc::vfs::ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = directory;
    listing_source.inodes.reset( variable_container<>::type::common );
    listing_source.atimes.reset( variable_container<>::type::common );
    listing_source.mtimes.reset( variable_container<>::type::common );
    listing_source.ctimes.reset( variable_container<>::type::common );
    listing_source.btimes.reset( variable_container<>::type::common );
    listing_source.add_times.reset( variable_container<>::type::common );
    listing_source.unix_flags.reset( variable_container<>::type::common );
    listing_source.uids.reset( variable_container<>::type::common );
    listing_source.gids.reset( variable_container<>::type::common );
    listing_source.sizes.reset( variable_container<>::type::common );
    listing_source.symlinks.reset( variable_container<>::type::sparse );
    listing_source.display_filenames.reset( variable_container<>::type::sparse );
    
    listing_source.unix_modes.resize(1);
    listing_source.unix_types.resize(1);
    listing_source.filenames.emplace_back( filename );
        
    listing_source.inodes[0]        = lstat.inode;
    listing_source.unix_types[0]    = IFTODT(lstat.mode);
    listing_source.atimes[0]        = lstat.atime.tv_sec;
    listing_source.mtimes[0]        = lstat.mtime.tv_sec;
    listing_source.ctimes[0]        = lstat.ctime.tv_sec;
    listing_source.btimes[0]        = lstat.btime.tv_sec;
    listing_source.unix_modes[0]    = lstat.mode;
    listing_source.unix_flags[0]    = lstat.flags;
    listing_source.uids[0]          = lstat.uid;
    listing_source.gids[0]          = lstat.gid;
    listing_source.sizes[0]         = lstat.size;

     if( listing_source.unix_types[0] == DT_LNK ) {
        // read an actual link path
        char linkpath[MAXPATHLEN];
        if( ReadSymlink(path, linkpath, MAXPATHLEN) == 0 )
            listing_source.symlinks.insert(0, linkpath);
        
        // stat the target file
        VFSStat stat;
        if( Stat(_path, stat, 0) == 0 ) {
            listing_source.unix_modes[0]    = stat.mode;
            listing_source.unix_flags[0]    = stat.flags;
            listing_source.uids[0]          = stat.uid;;
            listing_source.gids[0]          = stat.gid;
            listing_source.sizes[0]         = stat.size;
        }
    }

    _target = VFSListing::Build( move(listing_source) );
    
    return 0;
}

int Host::FetchFlexibleListingItems(const string& _directory_path,
                                    const vector<string> &_filenames,
                                    unsigned long _flags,
                                    vector<VFSListingItem> &_result,
                                    const VFSCancelChecker &_cancel_checker)
{
    shared_ptr<VFSListing> listing;
    int ret = FetchDirectoryListing(_directory_path.c_str(), listing, _flags, _cancel_checker);
    if( ret != 0 )
        return ret;
    
    _result.clear();
    _result.reserve( _filenames.size() );
    
    // O(n) implementation, can write as O(logn) with indirection indeces map
    for(unsigned i = 0, e = listing->Count(); i != e; ++i)
        for(auto &filename: _filenames)
            if( listing->Filename(i) == filename )
                _result.emplace_back( listing->Item(i) );
    
    return 0;
}

void Host::SetDesctructCallback( function<void(const VFSHost*)> _callback )
{
    m_OnDesctruct = _callback;
}

int Host::SetOwnership(const char *_path,
                       unsigned _uid,
                       unsigned _gid,
                       const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::FetchUsers(vector<VFSUser> &_target, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::FetchGroups(vector<VFSGroup> &_target, const VFSCancelChecker &_cancel_checker)
{
    return VFSError::NotSupported;
}

int Host::SetFlags(const char *_path, uint32_t _flags, const VFSCancelChecker &_cancel_checker )
{
    return VFSError::NotSupported;
}

void Host::SetFeatures( uint64_t _features_bitset )
{
    m_Features = _features_bitset;
}

void Host::AddFeatures( uint64_t _features_bitset )
{
    SetFeatures( Features() | _features_bitset );
}

uint64_t Host::Features() const noexcept
{
    return m_Features;
}

uint64_t Host::FullHashForPath( const char *_path ) const noexcept
{
    if( !_path )
        return 0;

    const auto max_hosts = 8;
    array<const VFSHost*, max_hosts> hosts;
    int hosts_n = 0;
    
    auto cur = this;
    while( cur && hosts_n < max_hosts ) {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }
    
    const auto buf_sz = 4096;
    char buf[buf_sz];
    char *p = &buf[0];
    
    while( hosts_n > 0 ) {
        const auto host = hosts[--hosts_n];
        p = stpcpy(p, host->Tag());
        p = stpcpy(p, "|");
        p = stpcpy(p, host->JunctionPath());
        p = stpcpy(p, "|");
    }
    p = stpcpy(p, _path);
    
    return hash<string_view>()( string_view(&buf[0], p - &buf[0]) );
}

string Host::MakePathVerbose( const char *_path ) const
{
    array<const Host*, 8> hosts;
    int hosts_n = 0;
    
    auto cur = this;
    while( cur && hosts_n < 8  ) {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }
    
    string verbose_path;
    while( hosts_n > 0 )
        verbose_path += hosts[--hosts_n]->Configuration().VerboseJunction();
    
    verbose_path += _path;
    return verbose_path;
}
    
bool Host::IsCaseSensitiveAtPath(const char *_dir) const
{
    return true;
}

}
