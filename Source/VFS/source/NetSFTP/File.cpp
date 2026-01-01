// Copyright (C) 2014-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "File.h"
#include <libssh2.h>
#include <libssh2_sftp.h>

#include "SFTPHost.h"
#include <algorithm>

namespace nc::vfs::sftp {

File::File(std::string_view _relative_path, std::shared_ptr<SFTPHost> _host) : VFSFile(_relative_path, _host)
{
}

File::~File()
{
    std::ignore = Close();
}

std::expected<void, Error> File::Open(unsigned long _open_flags,
                                      [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( IsOpened() )
        std::ignore = Close();

    auto sftp_host = std::dynamic_pointer_cast<SFTPHost>(Host());
    std::expected<std::unique_ptr<SFTPHost::Connection>, Error> conn = sftp_host->GetConnection();
    if( !conn )
        return std::unexpected(conn.error());

    int sftp_flags = 0;
    if( _open_flags & VFSFlags::OF_Read )
        sftp_flags |= LIBSSH2_FXF_READ;
    if( _open_flags & VFSFlags::OF_Write )
        sftp_flags |= LIBSSH2_FXF_WRITE;
    if( _open_flags & VFSFlags::OF_Append )
        sftp_flags |= LIBSSH2_FXF_APPEND;
    if( _open_flags & VFSFlags::OF_Create )
        sftp_flags |= LIBSSH2_FXF_CREAT;
    if( _open_flags & VFSFlags::OF_Truncate )
        sftp_flags |= LIBSSH2_FXF_TRUNC;
    if( _open_flags & VFSFlags::OF_NoExist )
        sftp_flags |= LIBSSH2_FXF_EXCL;

    const int mode = _open_flags & (S_IRWXU | S_IRWXG | S_IRWXO);

    const char *const path = Path();
    LIBSSH2_SFTP_HANDLE *handle = libssh2_sftp_open_ex((*conn)->sftp,
                                                       path,
                                                       static_cast<unsigned>(std::string_view{path}.length()),
                                                       sftp_flags,
                                                       mode,
                                                       LIBSSH2_SFTP_OPENFILE);
    if( handle == nullptr ) {
        const Error err = SFTPHost::ErrorForConnection(**conn);
        sftp_host->ReturnConnection(std::move(*conn));
        return std::unexpected(err);
    }

    LIBSSH2_SFTP_ATTRIBUTES attrs;
    const int fstat_rc = libssh2_sftp_fstat_ex(handle, &attrs, 0);
    if( fstat_rc < 0 ) {
        const Error err = SFTPHost::ErrorForConnection(**conn);
        sftp_host->ReturnConnection(std::move(*conn));
        return std::unexpected(err);
    }

    m_Connection = std::move(*conn);
    m_Handle = handle;
    m_Position = 0;
    m_Size = attrs.filesize;

    return {};
}

bool File::IsOpened() const
{
    return m_Connection && m_Handle;
}

std::expected<void, Error> File::Close()
{
    if( m_Handle ) {
        libssh2_sftp_close(m_Handle);
        m_Handle = nullptr;
    }

    if( m_Connection )
        std::dynamic_pointer_cast<SFTPHost>(Host())->ReturnConnection(std::move(m_Connection));

    m_Position = 0;
    m_Size = 0;
    return {};
}

VFSFile::ReadParadigm File::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Seek;
}

VFSFile::WriteParadigm File::GetWriteParadigm() const
{
    return VFSFile::WriteParadigm::Seek;
}

std::expected<uint64_t, Error> File::Seek(off_t _off, int _basis)
{
    uint64_t req = 0;
    if( _basis == VFSFile::Seek_Set )
        req = _off;
    else if( _basis == VFSFile::Seek_Cur )
        req = m_Position + _off;
    else if( _basis == VFSFile::Seek_End )
        req = m_Size + _off;

    // TODO: why errors are not handled?
    libssh2_sftp_seek64(m_Handle, req);
    const libssh2_uint64_t pos = libssh2_sftp_tell64(m_Handle);
    m_Position = pos;

    return pos;
}

std::expected<size_t, Error> File::Read(void *_buf, size_t _size)
{
    if( !IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    const ssize_t rc = libssh2_sftp_read(m_Handle, static_cast<char *>(_buf), _size);

    if( rc >= 0 ) {
        m_Position += rc;
        return rc;
    }
    else
        return std::unexpected(SFTPHost::ErrorForConnection(*m_Connection));
}

std::expected<size_t, Error> File::Write(const void *_buf, size_t _size)
{
    if( !IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    const ssize_t rc = libssh2_sftp_write(m_Handle, static_cast<const char *>(_buf), _size);

    if( rc >= 0 ) {
        m_Size = std::max(m_Position + rc, m_Size);
        m_Position += rc;
        return rc;
    }
    else
        return std::unexpected(SFTPHost::ErrorForConnection(*m_Connection));
}

std::expected<uint64_t, Error> File::Pos() const
{
    if( !IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    return m_Position;
}

std::expected<uint64_t, Error> File::Size() const
{
    if( !IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    return m_Size;
}

bool File::Eof() const
{
    if( !IsOpened() ) {
        return true;
    }

    return m_Position >= m_Size;
}
} // namespace nc::vfs::sftp
