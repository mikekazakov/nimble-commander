//
//  VFSHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFSHost.h"


VFSHost::VFSHost(const char *_junction_path,
                 shared_ptr<VFSHost> _parent):
    m_JunctionPath(_junction_path),
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
    return false;
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

int VFSHost::Stat(const char *_path, struct stat &_st, int _flags, bool (^_cancel_checker)())
{
    return VFSError::NotSupported;
}

int VFSHost::IterateDirectoryListing(const char *_path, bool (^_handler)(dirent &_dirent))
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
