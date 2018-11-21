// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "File.h"
#include <libssh2.h>
#include <libssh2_sftp.h>
#include "SFTPHost.h"

namespace nc::vfs::sftp {

File::File(const char* _relative_path, std::shared_ptr<SFTPHost> _host):
    VFSFile(_relative_path, _host)
{
}

File::~File()
{
    Close();
}

int File::Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker)
{
    if(IsOpened())
        Close();
    
    auto sftp_host = std::dynamic_pointer_cast<SFTPHost>(Host());
    std::unique_ptr<SFTPHost::Connection> conn;
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
                                                       Path(),
                                                       (unsigned)strlen(Path()),
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

bool File::IsOpened() const
{
    return m_Connection && m_Handle;
}

int File::Close()
{
    if( m_Handle ) {
        libssh2_sftp_close(m_Handle);
        m_Handle = nullptr;
    }
    
    if( m_Connection )
        std::dynamic_pointer_cast<SFTPHost>(Host())->ReturnConnection(std::move(m_Connection));

    m_Position = 0;
    m_Size     = 0;
    return 0;
}

VFSFile::ReadParadigm File::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Seek;
}

VFSFile::WriteParadigm File::GetWriteParadigm() const
{
    return VFSFile::WriteParadigm::Seek;
}

off_t File::Seek(off_t _off, int _basis)
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

ssize_t File::Read(void *_buf, size_t _size)
{
    if(!IsOpened())
        return SetLastError(VFSError::InvalidCall);
    
    ssize_t rc = libssh2_sftp_read(m_Handle, (char*)_buf, _size);
    
    if(rc >= 0) {
        m_Position += rc;
        return rc;
    }
    else
        return SetLastError(std::dynamic_pointer_cast<SFTPHost>(Host())->VFSErrorForConnection(*m_Connection));
}

ssize_t File::Write(const void *_buf, size_t _size)
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
        return SetLastError(std::dynamic_pointer_cast<SFTPHost>(Host())->VFSErrorForConnection(*m_Connection));
}

ssize_t File::Pos() const
{
    if(!IsOpened())
        return SetLastError(VFSError::InvalidCall);
    
    return m_Position;
}

ssize_t File::Size() const
{
    if(!IsOpened())
        return SetLastError(VFSError::InvalidCall);
    
    return m_Size;
}

bool File::Eof() const
{
    if(!IsOpened()) {
        SetLastError(VFSError::InvalidCall);        
        return true;
    }
    
    return m_Position >= m_Size;
}

}
