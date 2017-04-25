//
//  VFSNetSFTPFile.cpp
//  Files
//
//  Created by Michael G. Kazakov on 29/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <libssh2.h>
#include <libssh2_sftp.h>
#include "VFSNetSFTPFile.h"
#include "VFSNetSFTPHost.h"

VFSNetSFTPFile::VFSNetSFTPFile(const char* _relative_path,
                               shared_ptr<VFSNetSFTPHost> _host):
    VFSFile(_relative_path, _host)
{
}

VFSNetSFTPFile::~VFSNetSFTPFile()
{
    Close();
}

int VFSNetSFTPFile::Open(int _open_flags, VFSCancelChecker _cancel_checker)
{
    if(IsOpened())
        Close();
    
    auto sftp_host = dynamic_pointer_cast<VFSNetSFTPHost>(Host());
    unique_ptr<VFSNetSFTPHost::Connection> conn;
    int rc;
    if( (rc = sftp_host->GetConnection(conn)) != 0 )
        return rc;

    int sftp_flags = 0;
    if( _open_flags & VFSFlags::OF_Read     ) sftp_flags |= LIBSSH2_FXF_READ;
    if( _open_flags & VFSFlags::OF_Write    ) sftp_flags |= LIBSSH2_FXF_WRITE;
    if( _open_flags & VFSFlags::OF_Append   ) sftp_flags |= LIBSSH2_FXF_APPEND;
    if( _open_flags & VFSFlags::OF_Create   ) sftp_flags |= LIBSSH2_FXF_CREAT;
    if( _open_flags & VFSFlags::OF_Truncate ) sftp_flags |= LIBSSH2_FXF_TRUNC;
    if( _open_flags & VFSFlags::OF_NoExist  ) sftp_flags |= LIBSSH2_FXF_EXCL;
    
    int mode = _open_flags & (S_IRWXU | S_IRWXG | S_IRWXO);
    
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_open_ex(conn->sftp,
                                                       RelativePath(),
                                                       (unsigned)strlen(RelativePath()),
                                                       sftp_flags,
                                                       mode,
                                                       LIBSSH2_SFTP_OPENFILE);
    if(handle == nullptr) {
        rc = sftp_host->VFSErrorForConnection(*conn);
        sftp_host->ReturnConnection(move(conn));
        return rc;
    }
    
    LIBSSH2_SFTP_ATTRIBUTES attrs;
    if((rc = libssh2_sftp_fstat_ex(handle, &attrs, 0)) < 0) {
        rc = sftp_host->VFSErrorForConnection(*conn);
        return rc;
    }
    
    m_Connection = move(conn);
    m_Handle = handle;
    m_Position = 0;
    m_Size = attrs.filesize;
    
    return 0;
}

bool VFSNetSFTPFile::IsOpened() const
{
    return m_Connection && m_Handle;
}

int VFSNetSFTPFile::Close()
{
    if( m_Handle ) {
        libssh2_sftp_close(m_Handle);
        m_Handle = nullptr;
    }
    
    if( m_Connection )
        dynamic_pointer_cast<VFSNetSFTPHost>(Host())->ReturnConnection(move(m_Connection));

    m_Position = 0;
    m_Size     = 0;
    return 0;
}

VFSFile::ReadParadigm VFSNetSFTPFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Seek;
}

VFSFile::WriteParadigm VFSNetSFTPFile::GetWriteParadigm() const
{
    return VFSFile::WriteParadigm::Seek;
}

off_t VFSNetSFTPFile::Seek(off_t _off, int _basis)
{
    uint64_t req = 0;
    if( _basis == VFSFile::Seek_Set )
        req = _off;
    else if( _basis == VFSFile::Seek_Cur )
        req = m_Position + _off;
    else if( _basis == VFSFile::Seek_End )
        req = m_Size + _off;

    libssh2_sftp_seek64(m_Handle, req);
    libssh2_uint64_t pos = libssh2_sftp_tell64(m_Handle);
    m_Position = pos;
    
    return pos;
}

ssize_t VFSNetSFTPFile::Read(void *_buf, size_t _size)
{
    if(!IsOpened())
        return SetLastError(VFSError::InvalidCall);
    
    ssize_t rc = libssh2_sftp_read(m_Handle, (char*)_buf, _size);
    
    if(rc >= 0) {
        m_Position += rc;
        return rc;
    }
    else
        return SetLastError(dynamic_pointer_cast<VFSNetSFTPHost>(Host())->VFSErrorForConnection(*m_Connection));
}

ssize_t VFSNetSFTPFile::Write(const void *_buf, size_t _size)
{
    if(!IsOpened())
        return SetLastError(VFSError::InvalidCall);

    ssize_t rc = libssh2_sftp_write(m_Handle, (char*)_buf, _size);
    
    if(rc >= 0) {
        if(m_Position + rc > m_Size)
            m_Size = m_Position + rc;
        m_Position += rc;
        return rc;
    }
    else
        return SetLastError(dynamic_pointer_cast<VFSNetSFTPHost>(Host())->VFSErrorForConnection(*m_Connection));
}

ssize_t VFSNetSFTPFile::Pos() const
{
    if(!IsOpened())
        return SetLastError(VFSError::InvalidCall);
    
    return m_Position;
}

ssize_t VFSNetSFTPFile::Size() const
{
    if(!IsOpened())
        return SetLastError(VFSError::InvalidCall);
    
    return m_Size;
}

bool VFSNetSFTPFile::Eof() const
{
    if(!IsOpened()) {
        SetLastError(VFSError::InvalidCall);        
        return true;
    }
    
    return m_Position >= m_Size;
}
