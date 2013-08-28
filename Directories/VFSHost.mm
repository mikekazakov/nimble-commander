//
//  VFSHost.cpp
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFSHost.h"


VFSHost::VFSHost(const char *_junction_path,
                 std::shared_ptr<VFSHost> _parent):
    m_JunctionPath(_junction_path),
    m_Parent(_parent)
{
}

VFSHost::~VFSHost()
{
}

std::shared_ptr<VFSHost> VFSHost::Parent() const
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

int VFSHost::FetchDirectoryListing(
                                  const char *_path,
                                  std::shared_ptr<VFSListing> *_target,
                                  bool (^_cancel_checker)()
                                  )
{
    return VFSError::NotSupported;
}

int VFSHost::CreateFile(const char* _path,
                       std::shared_ptr<VFSFile> *_target,
                       bool (^_cancel_checker)())
{
    return VFSError::NotSupported;
}