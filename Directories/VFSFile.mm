//
//  VFSFile.mm
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFSFile.h"
#import "VFSError.h"

VFSFile::VFSFile(const char* _relative_path, std::shared_ptr<VFSHost> _host):
    m_RelativePath(_relative_path),
    m_Host(_host)
{
}

VFSFile::~VFSFile()
{
    Close();
}

const char* VFSFile::RelativePath() const
{
    return m_RelativePath.c_str();
}

std::shared_ptr<VFSHost> VFSFile::Host() const
{
    return m_Host;
}

VFSFile::ReadParadigm VFSFile::GetReadParadigm() const
{
    return ReadParadigm::NoRead;
}

ssize_t VFSFile::Read(void *_buf, size_t _size)
{
    return VFSError::NotSupported;
}

ssize_t VFSFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    return VFSError::NotSupported;
}

bool VFSFile::IsOpened() const
{
    return false;
}

int     VFSFile::Open(int)          { return VFSError::NotSupported; }
int     VFSFile::Close()            { return VFSError::NotSupported; }
off_t   VFSFile::Seek(off_t, int)   { return VFSError::NotSupported; }
ssize_t VFSFile::Pos() const        { return VFSError::NotSupported; }
ssize_t VFSFile::Size() const       { return VFSError::NotSupported; }
bool    VFSFile::Eof() const        { return true; }
std::shared_ptr<VFSFile> VFSFile::Clone() const { return 0; }
