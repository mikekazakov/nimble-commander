//
//  VFSNativeFile.mm
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <sys/xattr.h>
#import <sys/attr.h>
#import <unistd.h>
#import <stdlib.h>
#import "VFSNativeFile.h"
#import "VFSNativeHost.h"
#import "NativeFSManager.h"

VFSNativeFile::VFSNativeFile(const char* _relative_path, shared_ptr<VFSNativeHost> _host):
    VFSFile(_relative_path, _host),
    m_FD(-1),
    m_Position(0),
    m_OpenFlags(0)
{
}

VFSNativeFile::~VFSNativeFile()
{
    Close();
}

int VFSNativeFile::Open(int _open_flags, bool (^_cancel_checker)())
{
    auto fs_info = NativeFSManager::Instance().VolumeFromPath(RelativePath());
    
    int openflags = O_NONBLOCK;
    
    if(fs_info && fs_info->interfaces.file_lock)
        openflags |= O_SHLOCK;
    if( (_open_flags & (VFSFile::OF_Read | VFSFile::OF_Write)) == (VFSFile::OF_Read | VFSFile::OF_Write) )
        openflags |= O_RDWR;
    else if((_open_flags & VFSFile::OF_Read) != 0) openflags |= O_RDONLY;
    else if((_open_flags & VFSFile::OF_Write) != 0) openflags |= O_WRONLY;
    
    if(_open_flags & VFSFile::OF_Create) openflags |= O_CREAT;
    if(_open_flags & VFSFile::OF_NoExist) openflags |= O_EXCL;
    
    m_FD = open(RelativePath(), openflags, 0640);
    if(m_FD < 0)
    {
        return SetLastError(VFSError::FromErrno(errno));
    }
    
    fcntl(m_FD, F_SETFL, fcntl(m_FD, F_GETFL) & ~O_NONBLOCK);
    
    m_Position = 0;
    m_OpenFlags = _open_flags;
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
        m_OpenFlags = 0;
        m_Size = 0;
        m_Position = 0;
    }
    return VFSError::Ok;
}

ssize_t VFSNativeFile::Read(void *_buf, size_t _size)
{
    if(m_FD < 0) return SetLastError(VFSError::InvalidCall);
    if(Eof())    return 0;
    
    ssize_t ret = read(m_FD, _buf, _size);
    if(ret >= 0)
    {
        m_Position += ret;
        return ret;
    }
    return SetLastError(VFSError::FromErrno(errno));
}

ssize_t VFSNativeFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if(m_FD < 0)
        return SetLastError(VFSError::InvalidCall);
    ssize_t ret = pread(m_FD, _buf, _size, _pos);
    if(ret < 0)
        return SetLastError(VFSError::FromErrno(errno));
    return ret;
}

off_t VFSNativeFile::Seek(off_t _off, int _basis)
{
    if(m_FD < 0)
        return SetLastError(VFSError::InvalidCall);
//    printf("seek:%lld/%d \n", _off, _basis);
//    assert(m_FD >= 0);
    
    off_t ret = lseek(m_FD, _off, _basis);
    if(ret >= 0)
    {
        m_Position = ret;
        return ret;
    }
    return SetLastError(VFSError::FromErrno(errno));
}

ssize_t VFSNativeFile::Write(const void *_buf, size_t _size)
{
    if(m_FD < 0)
        return SetLastError(VFSError::InvalidCall);

    ssize_t ret = write(m_FD, _buf, _size);
    if(ret >= 0)
    {
        if(m_Position + ret > m_Size)
            m_Size = m_Position + ret;
        m_Position += ret;
        return ret;
    }
    return SetLastError(VFSError::FromErrno(errno));
}

VFSFile::ReadParadigm VFSNativeFile::GetReadParadigm() const
{
    if(m_FD < 0) // on not-opened files we return maximum possible value
        return VFSFile::ReadParadigm::Random;
    
    if(m_OpenFlags & VFSFile::OF_Read)
        return VFSFile::ReadParadigm::Random; // does ANY native filesystem in fact supports random read/write?
    return VFSFile::ReadParadigm::NoRead;
}

VFSFile::WriteParadigm VFSNativeFile::GetWriteParadigm() const
{
    if(m_FD < 0) // on not-opened files we return maximum possible value
        return VFSFile::WriteParadigm::Random;
        
    if(m_OpenFlags & VFSFile::OF_Write)
        return VFSFile::WriteParadigm::Random; // does ANY native filesystem in fact supports random read/write?
    return VFSFile::WriteParadigm::NoWrite;
}

ssize_t VFSNativeFile::Pos() const
{
    if(m_FD < 0)
        return SetLastError(VFSError::InvalidCall);
    return m_Position;
}

ssize_t VFSNativeFile::Size() const
{
    if(m_FD < 0)
        return SetLastError(VFSError::InvalidCall);
    return m_Size;
}

bool VFSNativeFile::Eof() const
{
    if(m_FD < 0)
        return true;
    return m_Position >= m_Size;
}

shared_ptr<VFSFile> VFSNativeFile::Clone() const
{
    return make_shared<VFSNativeFile>(
                                           RelativePath(),
                                           dynamic_pointer_cast<VFSNativeHost>(Host()));
}

unsigned VFSNativeFile::XAttrCount() const
{
    if(m_FD < 0)
        return 0;

    ssize_t bf_sz = flistxattr(m_FD, 0, 0, 0);
    if(bf_sz <= 0) // on error or if there're no xattrs available for this file
        return 0;

    char *buf = (char*)alloca(bf_sz);
    assert(buf != 0);
    
    ssize_t ret = flistxattr(m_FD, buf, bf_sz, 0);
    if(ret < 0)
        return 0;
  
    char *s = buf, *e = buf + ret;
    unsigned count = 0;
    while(s < e) {
        ++count;
        s += strlen(s)+1;
    }
    return count;
}

void VFSNativeFile::XAttrIterateNames( bool (^_handler)(const char* _xattr_name) ) const
{
    if(m_FD < 0 || !_handler)
        return;
    
    ssize_t bf_sz = flistxattr(m_FD, 0, 0, 0);
    if(bf_sz <= 0) // on error or if there're no xattrs available for this file
        return;
    
    char *buf = (char*)alloca(bf_sz);
    assert(buf != 0);
    
    ssize_t ret = flistxattr(m_FD, buf, bf_sz, 0);
    if(ret < 0)
        return;
    
    char *s = buf, *e = buf + ret;
    while(s < e) {
        if(!_handler(s))
            break;
        
        s += strlen(s)+1;
    }
}

ssize_t VFSNativeFile::XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const
{
    if(m_FD < 0)
        return SetLastError(VFSError::InvalidCall);

    ssize_t ret = fgetxattr(m_FD, _xattr_name, _buffer, _buf_size, 0, 0);
    if(ret < 0)
        return SetLastError(VFSError::FromErrno(errno));
    
    return ret;
}

