//
//  VFSHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <sys/stat.h>
#include "../Common.h"
#include "../path_manip.h"
#include "VFSHost.h"


static_assert(sizeof(VFSStat) == 128, "");
const char *VFSHost::Tag = "nullfs";

bool VFSStatFS::operator==(const VFSStatFS& _r) const
{
    return total_bytes == _r.total_bytes &&
    free_bytes == _r.free_bytes  &&
    avail_bytes == _r.avail_bytes &&
    volume_name == _r.volume_name;
}

bool VFSStatFS::operator!=(const VFSStatFS& _r) const
{
    return total_bytes != _r.total_bytes ||
    free_bytes != _r.free_bytes  ||
    avail_bytes != _r.avail_bytes ||
    volume_name != _r.volume_name;
}

void VFSStat::FromSysStat(const struct stat &_from, VFSStat &_to)
{
    _to.dev     = _from.st_dev;
    _to.rdev    = _from.st_rdev;
    _to.inode   = _from.st_ino;
    _to.mode    = _from.st_mode;
    _to.nlink   = _from.st_nlink;
    _to.uid     = _from.st_uid;
    _to.gid     = _from.st_gid;
    _to.size    = _from.st_size;
    _to.blocks  = _from.st_blocks;
    _to.blksize = _from.st_blksize;
    _to.flags   = _from.st_flags;
    _to.atime   = _from.st_atimespec;
    _to.mtime   = _from.st_mtimespec;
    _to.ctime   = _from.st_ctimespec;
    _to.btime   = _from.st_birthtimespec;
    _to.meaning = AllMeaning();
}

void VFSStat::ToSysStat(const VFSStat &_from, struct stat &_to)
{
    memset(&_to, 0, sizeof(_to));
    _to.st_dev              = _from.dev;
    _to.st_rdev             = _from.rdev;
    _to.st_ino              = _from.inode;
    _to.st_mode             = _from.mode;
    _to.st_nlink            = _from.nlink;
    _to.st_uid              = _from.uid;
    _to.st_gid              = _from.gid;
    _to.st_size             = _from.size;
    _to.st_blocks           = _from.blocks;
    _to.st_blksize          = _from.blksize;
    _to.st_flags            = _from.flags;
    _to.st_atimespec        = _from.atime;
    _to.st_mtimespec        = _from.mtime;
    _to.st_ctimespec        = _from.ctime;
    _to.st_birthtimespec    = _from.btime;
}

struct stat VFSStat::SysStat() const noexcept
{
    struct stat st;
    ToSysStat(*this, st);
    return st;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////// VFSHostDirObservationTicket
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

VFSHostDirObservationTicket::VFSHostDirObservationTicket() noexcept:
    m_Ticket(0),
    m_Host()
{
}

VFSHostDirObservationTicket::VFSHostDirObservationTicket(unsigned long _ticket, weak_ptr<VFSHost> _host) noexcept:
    m_Ticket(_ticket),
    m_Host(_host)
{
    assert( (_ticket == 0 && _host.expired()) || (_ticket != 0 && !_host.expired()) );
}

VFSHostDirObservationTicket::VFSHostDirObservationTicket(VFSHostDirObservationTicket &&_rhs) noexcept:
    m_Ticket(_rhs.m_Ticket),
    m_Host(move(_rhs.m_Host))
{
    _rhs.m_Ticket = 0;
}

VFSHostDirObservationTicket::~VFSHostDirObservationTicket()
{
    reset();
}

VFSHostDirObservationTicket &VFSHostDirObservationTicket::operator=(VFSHostDirObservationTicket &&_rhs)
{
    reset();
    m_Ticket = _rhs.m_Ticket;
    m_Host = move(_rhs.m_Host);
    _rhs.m_Ticket = 0;
    return *this;
}

bool VFSHostDirObservationTicket::valid() const noexcept
{
    return m_Ticket != 0;
}

void VFSHostDirObservationTicket::reset()
{
    if(valid()) {
        if(auto h = m_Host.lock())
            h->StopDirChangeObserving(m_Ticket);
        m_Ticket = 0;
        m_Host.reset();
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////// VFSHostConfiguration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class VFSHostConfiguration
{
public:
    
    const char *Tag() const
    {
        return VFSHost::Tag;
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

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////// VFSHost
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

VFSHost::VFSHost(const char *_junction_path,
                 shared_ptr<VFSHost> _parent,
                 const char *_fs_tag):
    m_JunctionPath(_junction_path ? _junction_path : ""),
    m_Parent(_parent),
    m_Tag(_fs_tag)
{
}

VFSHost::~VFSHost()
{
}

const char *VFSHost::FSTag() const noexcept
{
    return m_Tag;
}

const VFSHostPtr& VFSHost::Parent() const noexcept
{
    return m_Parent;    
}

const char* VFSHost::JunctionPath() const noexcept
{
    return m_JunctionPath.c_str();
}

bool VFSHost::IsWriteable() const
{
    return false;
}

bool VFSHost::IsWriteableAtPath(const char *_dir) const
{
    return IsWriteable();
}

int VFSHost::CreateFile(const char* _path,
                       shared_ptr<VFSFile> &_target,
                       VFSCancelChecker _cancel_checker)
{
    return VFSError::NotSupported;
}

bool VFSHost::IsDirectory(const char *_path,
                          int _flags,
                          VFSCancelChecker _cancel_checker)
{
    VFSStat st;
    if(Stat(_path, st, _flags, _cancel_checker) < 0)
        return false;
    
    return (st.mode & S_IFMT) == S_IFDIR;
}

bool VFSHost::IsSymlink(const char *_path,
                        int _flags,
                        VFSCancelChecker _cancel_checker)
{
    VFSStat st;
    if(Stat(_path, st, _flags, _cancel_checker) < 0)
        return false;
    
    return (st.mode & S_IFMT) == S_IFLNK;
}

bool VFSHost::FindLastValidItem(const char *_orig_path,
                               char *_valid_path,
                               int _flags,
                               VFSCancelChecker _cancel_checker)
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

ssize_t VFSHost::CalculateDirectorySize(const char *_path,
                                        VFSCancelChecker _cancel_checker
                                        )
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

bool VFSHost::IsDirChangeObservingAvailable(const char *_path)
{
    return false;
}

VFSHostDirObservationTicket VFSHost::DirChangeObserve(const char *_path, function<void()> _handler)
{
    return {};
}

void VFSHost::StopDirChangeObserving(unsigned long _ticket)
{
}

int VFSHost::Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker)
{
    return VFSError::NotSupported;
}

int VFSHost::IterateDirectoryListing(const char *_path, function<bool(const VFSDirEnt &_dirent)> _handler)
{
    // TODO: write a default implementation using listing fetching.
    // it will be less efficient, but for some FS like PS it will be ok
    return VFSError::NotSupported;
}

int VFSHost::StatFS(const char *_path, VFSStatFS &_stat, VFSCancelChecker _cancel_checker)
{
    return VFSError::NotSupported;
}

int VFSHost::Unlink(const char *_path, VFSCancelChecker _cancel_checker)
{
    return VFSError::NotSupported;
}

int VFSHost::CreateDirectory(const char* _path, int _mode, VFSCancelChecker _cancel_checker)
{
    return VFSError::NotSupported;
}

int VFSHost::ReadSymlink(const char *_path, char *_buffer, size_t _buffer_size, VFSCancelChecker _cancel_checker)
{
    return VFSError::NotSupported;
}

int VFSHost::CreateSymlink(const char *_symlink_path, const char *_symlink_value, VFSCancelChecker _cancel_checker)
{
    return VFSError::NotSupported;
}

int VFSHost::SetTimes(const char *_path,
                      int _flags,
                      struct timespec *_birth_time,
                      struct timespec *_mod_time,
                      struct timespec *_chg_time,
                      struct timespec *_acc_time,
                      VFSCancelChecker _cancel_checker
                     )
{
    return VFSError::NotSupported;
}

bool VFSHost::ShouldProduceThumbnails() const
{
    return true;
}

int VFSHost::RemoveDirectory(const char *_path, VFSCancelChecker _cancel_checker)
{
    return VFSError::NotSupported;
}

int VFSHost::Rename(const char *_old_path, const char *_new_path, VFSCancelChecker _cancel_checker)
{
    return VFSError::NotSupported;
}

int VFSHost::GetXAttrs(const char *_path, vector< pair<string, vector<uint8_t>>> &_xattrs)
{
    return VFSError::NotSupported;
}

const shared_ptr<VFSHost> &VFSHost::DummyHost()
{
    static auto host = make_shared<VFSHost>("", nullptr, VFSHost::Tag);
    return host;
}

VFSConfiguration VFSHost::Configuration() const
{
    static auto config = VFSConfiguration( VFSHostConfiguration() );
    return config;
}

bool VFSHost::Exists(const char *_path, VFSCancelChecker _cancel_checker)
{
    VFSStat st;
    return Stat(_path, st, 0, _cancel_checker) == 0;
}

bool VFSHost::IsImmutableFS() const noexcept
{
    return false;
}

bool VFSHost::IsNativeFS() const noexcept
{
    return false;
}

bool VFSHost::ValidateFilename(const char *_filename) const
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

int VFSHost::FetchFlexibleListing(const char *_path, shared_ptr<VFSListing> &_target, int _flags, VFSCancelChecker _cancel_checker)
{
    return VFSError::NotSupported;
}

int VFSHost::FetchFlexibleListingItems(const string& _directory_path,
                                       const vector<string> &_filenames,
                                       int _flags,
                                       vector<VFSListingItem> &_result,
                                       VFSCancelChecker _cancel_checker)
{
    shared_ptr<VFSListing> listing;
    int ret = FetchFlexibleListing(_directory_path.c_str(), listing, _flags, _cancel_checker);
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
