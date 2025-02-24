// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "File.h"
#include "Internal.h"
#include "Cache.h"
#include "PathRoutines.h"
#include "ConnectionsPool.h"

namespace nc::vfs::webdav {

File::File(std::string_view _relative_path, const std::shared_ptr<WebDAVHost> &_host)
    : VFSFile(_relative_path, _host), m_Host(*_host)
{
}

File::~File()
{
    Close();
}

int File::Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker)
{
    if( _open_flags & VFSFlags::OF_Append )
        return VFSError::FromErrno(EPERM);

    if( (_open_flags & (VFSFlags::OF_Read | VFSFlags::OF_Write)) == (VFSFlags::OF_Read | VFSFlags::OF_Write) )
        return VFSError::FromErrno(EPERM);

    if( _open_flags & VFSFlags::OF_Read ) {
        const std::expected<VFSStat, Error> st = m_Host.Stat(Path(), 0, _cancel_checker);
        if( !st )
            return VFSError::FromErrno(EINVAL); // TODO: return 'st'

        if( !S_ISREG(st->mode) )
            return VFSError::FromErrno(EPERM); // TODO: test for this

        m_Size = st->size;
        m_OpenFlags = _open_flags;
        return VFSError::Ok;
    }
    if( _open_flags & VFSFlags::OF_Write ) {
        const std::expected<VFSStat, Error> st = m_Host.Stat(Path(), 0, _cancel_checker);

        // Refuse if the file does exist and OF_NoExist was specified
        if( (_open_flags & VFSFlags::OF_NoExist) && st ) {
            return VFSError::FromErrno(EEXIST);
        }

        // Refuse if the file does not exist but OF_Create was not specified
        if( (_open_flags & VFSFlags::OF_Create) == 0 && !st ) {
            return VFSError::FromErrno(ENOENT);
        }

        // If file already exist, but it is actually a directory
        if( st && st->mode_bits.dir ) {
            return VFSError::FromErrno(EISDIR);
        }

        // If file already exist - remove it
        if( st ) {
            const auto unlink_rc = m_Host.Unlink(Path(), _cancel_checker);
            if( !unlink_rc )
                return VFSError::FromErrno(EINVAL); // TODO: return 'unlink_rc'
        }

        // Finally verified and ready to go
        m_OpenFlags = _open_flags;
        return VFSError::Ok;
    }
    return VFSError::FromErrno(EINVAL);
}

ssize_t File::Read(void *_buf, size_t _size)
{
    if( !IsOpened() || !(m_OpenFlags & VFSFlags::OF_Read) )
        return SetLastError(VFSError::FromErrno(EINVAL));
    if( _size == 0 || Eof() )
        return 0;

    SpawnDownloadConnectionIfNeeded();

    const int vfs_error = m_Conn->ReadBodyUpToSize(_size);
    if( vfs_error != VFSError::Ok )
        return SetLastError(vfs_error);

    auto &read_buffer = m_Conn->ResponseBody();
    const auto has_read = read_buffer.Read(_buf, _size);
    m_Pos += has_read;

    return has_read;
}

ssize_t File::Write(const void *_buf, size_t _size)
{
    if( !IsOpened() || !(m_OpenFlags & VFSFlags::OF_Write) || m_Size < 0 )
        return SetLastError(VFSError::FromErrno(EINVAL));

    SpawnUploadConnectionIfNeeded();

    auto &write_buffer = m_Conn->RequestBody();

    // assuming it should be empty at this point?
    assert(write_buffer.Empty());

    write_buffer.Write(_buf, _size);

    const int vfs_error = m_Conn->WriteBodyUpToSize(_size);
    if( vfs_error != VFSError::Ok )
        return SetLastError(vfs_error);

    //    TODO: clarify what File should return for partially written blocks - error code or number
    //    of bytes written?

    const auto has_written = _size - write_buffer.Size();
    m_Pos += has_written;
    write_buffer.Discard(_size - has_written);

    return has_written;
}

void File::SpawnUploadConnectionIfNeeded()
{
    if( m_Conn )
        return;

    m_Conn = m_Host.ConnectionsPool().GetRaw();
    assert(m_Conn);
    const auto url = URIForPath(m_Host.Config(), Path());
    m_Conn->SetURL(url);
    m_Conn->SetNonBlockingUpload(m_Size);
    m_Conn->MakeNonBlocking();
}

void File::SpawnDownloadConnectionIfNeeded()
{
    if( m_Conn )
        return;

    m_Conn = m_Host.ConnectionsPool().GetRaw();
    assert(m_Conn);
    const auto url = URIForPath(m_Host.Config(), Path());
    m_Conn->SetURL(url);
    m_Conn->SetCustomRequest("GET");
    m_Conn->MakeNonBlocking();
}

bool File::IsOpened() const
{
    return m_OpenFlags != 0;
}

int File::Close()
{
    if( !IsOpened() )
        return VFSError::FromErrno(EINVAL);

    int result = VFSError::Ok;

    if( m_OpenFlags & VFSFlags::OF_Read ) {
        if( m_Conn ) {
            m_Conn->ReadBodyUpToSize(Connection::AbortBodyRead);
            m_Host.ConnectionsPool().Return(std::move(m_Conn));
        }
    }
    else if( m_OpenFlags & VFSFlags::OF_Write ) {
        if( m_Size >= 0 ) {
            if( m_Conn == nullptr )
                Write("", 0); // force a connection to appear, needed for zero-byte uploads

            assert(m_Conn);

            if( m_Pos < m_Size ) {
                result = m_Conn->WriteBodyUpToSize(Connection::AbortBodyWrite);
                if( result == VFSError::FromErrno(ECANCELED) )
                    result = VFSError::Ok; // explicitly eat ECANCELED as we do cancel the upload
            }
            else {
                result = m_Conn->WriteBodyUpToSize(Connection::ConcludeBodyWrite);
                m_Host.Cache().CommitMkFile(Path());
            }

            m_Host.ConnectionsPool().Return(std::move(m_Conn));
        }
    }

    m_OpenFlags = 0;
    m_Pos = 0;
    m_Size = -1;

    return SetLastError(result);
}

File::ReadParadigm File::GetReadParadigm() const
{
    return ReadParadigm::Sequential;
}

File::WriteParadigm File::GetWriteParadigm() const
{
    return WriteParadigm::Upload;
}

ssize_t File::Pos() const
{
    return m_Pos;
}

ssize_t File::Size() const
{
    return m_Size;
}

bool File::Eof() const
{
    if( !IsOpened() )
        return true;
    return m_Pos == m_Size;
}

int File::SetUploadSize(size_t _size)
{
    if( !IsOpened() || m_Size >= 0 )
        return SetLastError(VFSError::FromErrno(EINVAL));

    m_Size = _size;

    return VFSError::Ok;
}

} // namespace nc::vfs::webdav
