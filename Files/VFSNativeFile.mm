//
//  VFSNativeFile.mm
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFSNativeFile.h"
#import "VFSNativeHost.h"
#import <unistd.h>
#import <stdlib.h>

VFSNativeFile::VFSNativeFile(const char* _relative_path, std::shared_ptr<VFSNativeHost> _host):
    VFSFile(_relative_path, _host),
    m_FD(-1),
    m_Position(0)
{
}

VFSNativeFile::~VFSNativeFile()
{
    Close();
}

int VFSNativeFile::Open(int _open_flags)
{
    int openflags = O_SHLOCK|O_NONBLOCK;
    if( (_open_flags & (VFSFile::OF_Read | VFSFile::OF_Write)) == (VFSFile::OF_Read | VFSFile::OF_Write) )
        openflags |= O_RDWR;
    else if((_open_flags & VFSFile::OF_Read) != 0) openflags |= O_RDONLY;
    else if((_open_flags & VFSFile::OF_Write) != 0) openflags |= O_WRONLY;
    
    m_FD = open(RelativePath(), openflags);
    if(m_FD < 0)
    {
        return VFSError::FromErrno(errno);
    }
    
    fcntl(m_FD, F_SETFL, fcntl(m_FD, F_GETFL) & ~O_NONBLOCK);
    
    m_Position = 0;
    
    m_Size = lseek(m_FD, 0, SEEK_END);
    lseek(m_FD, 0, SEEK_SET);
    
    return VFSError::Ok;
}

bool VFSNativeFile::IsOpened() const
{
    return m_FD >= 0;
}

int VFSNativeFile::Close()
{
    if(m_FD >= 0)
    {
        close(m_FD);
        m_FD = -1;
    }
    return VFSError::Ok;
}

ssize_t VFSNativeFile::Read(void *_buf, size_t _size)
{
    if(m_FD < 0) return VFSError::InvalidCall;
    if(Eof())    return 0;
    
    ssize_t ret = read(m_FD, _buf, _size);
    if(ret >= 0)
    {
        m_Position += ret;
        return ret;
    }
    return VFSError::FromErrno(errno);
}

ssize_t VFSNativeFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if(m_FD < 0)
        return VFSError::InvalidCall;
    ssize_t ret = pread(m_FD, _buf, _size, _pos);
    if(ret < 0)
        return VFSError::FromErrno(errno);
    return ret;
}

off_t VFSNativeFile::Seek(off_t _off, int _basis)
{
    if(m_FD < 0)
        return VFSError::InvalidCall;
//    printf("seek:%lld/%d \n", _off, _basis);
//    assert(m_FD >= 0);
    
    off_t ret = lseek(m_FD, _off, _basis);
    if(ret >= 0)
    {
        m_Position = ret;
        return ret;
    }
    return VFSError::FromErrno(errno);
}

VFSFile::ReadParadigm VFSNativeFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Random;
}

ssize_t VFSNativeFile::Pos() const
{
    if(m_FD < 0)
        return VFSError::InvalidCall;
    return m_Position;
}

ssize_t VFSNativeFile::Size() const
{
    if(m_FD < 0)
        return VFSError::InvalidCall;
    return m_Size;
}

bool VFSNativeFile::Eof() const
{
    if(m_FD < 0)
        return true;
    return m_Position == m_Size;
}

std::shared_ptr<VFSFile> VFSNativeFile::Clone() const
{
    return std::make_shared<VFSNativeFile>(
                                           RelativePath(),
                                           std::dynamic_pointer_cast<VFSNativeHost>(Host()));
}