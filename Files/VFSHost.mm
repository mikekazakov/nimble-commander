//
//  VFSHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/stat.h>
#import "VFSHost.h"

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

VFSHost::VFSHost(const char *_junction_path,
                 shared_ptr<VFSHost> _parent):
    m_JunctionPath(_junction_path ? _junction_path : ""),
    m_Parent(_parent)
{
}

VFSHost::~VFSHost()
{
}

const char *VFSHost::FSTag() const
{
    return "";
}

shared_ptr<VFSHost> VFSHost::Parent() const
{
    return m_Parent;    
}

const char* VFSHost::JunctionPath() const
{
    return m_JunctionPath.c_str();
}

bool VFSHost::IsWriteable() const
{
    return false;
}

bool VFSHost::IsWriteableAtPath(const char *_dir) const
{
    return false;
}

int VFSHost::FetchDirectoryListing(
                                  const char *_path,
                                  shared_ptr<VFSListing> *_target,
                                  int _flags,                                   
                                  bool (^_cancel_checker)()
                                  )
{
    return VFSError::NotSupported;
}

int VFSHost::CreateFile(const char* _path,
                       shared_ptr<VFSFile> *_target,
                       bool (^_cancel_checker)())
{
    return VFSError::NotSupported;
}

bool VFSHost::IsDirectory(const char *_path,
                          int _flags,
                          bool (^_cancel_checker)())
{
    VFSStat st;
    if(Stat(_path, st, _flags, _cancel_checker) < 0)
        return false;
    
    return (st.mode & S_IFMT) == S_IFDIR;
}

bool VFSHost::FindLastValidItem(const char *_orig_path,
                               char *_valid_path,
                               int _flags,
                               bool (^_cancel_checker)())
{
    return false;
}

int VFSHost::CalculateDirectoriesSizes(
                                    chained_strings _dirs,
                                    const string &_root_path,
                                    bool (^_cancel_checker)(),
                                    void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size)
                                    )
{
    return VFSError::NotSupported;
}

unsigned long VFSHost::DirChangeObserve(const char *_path, void (^_handler)())
{
    return 0;
}

void VFSHost::StopDirChangeObserving(unsigned long _ticket)
{
}

int VFSHost::Stat(const char *_path, VFSStat &_st, int _flags, bool (^_cancel_checker)())
{
    return VFSError::NotSupported;
}

int VFSHost::IterateDirectoryListing(const char *_path, bool (^_handler)(const VFSDirEnt &_dirent))
{
    // TODO: write a default implementation using listing fetching.
    // it will be less efficient, but for some FS like PS it will be ok
    return VFSError::NotSupported;
}

int VFSHost::StatFS(const char *_path, VFSStatFS &_stat, bool (^_cancel_checker)())
{
    return VFSError::NotSupported;
}

int VFSHost::Unlink(const char *_path, bool (^_cancel_checker)())
{
    return VFSError::NotSupported;
}

int VFSHost::CreateDirectory(const char* _path, bool (^_cancel_checker)())
{
    return VFSError::NotSupported;
}

int VFSHost::ReadSymlink(const char *_path, char *_buffer, size_t _buffer_size, bool (^_cancel_checker)())
{
    return VFSError::NotSupported;
}

int VFSHost::CreateSymlink(const char *_symlink_path, const char *_symlink_value, bool (^_cancel_checker)())
{
    return VFSError::NotSupported;
}

int VFSHost::SetTimes(const char *_path,
                      int _flags,
                      struct timespec *_birth_time,
                      struct timespec *_mod_time,
                      struct timespec *_chg_time,
                      struct timespec *_acc_time,
                      bool (^_cancel_checker)()
                     )
{
    return VFSError::NotSupported;
}
