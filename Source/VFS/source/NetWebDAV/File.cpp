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
    std::ignore = Close();
}

std::expected<void, Error> File::Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker)
{
    if( _open_flags & VFSFlags::OF_Append )
        return std::unexpected(Error{Error::POSIX, EPERM});

    if( (_open_flags & (VFSFlags::OF_Read | VFSFlags::OF_Write)) == (VFSFlags::OF_Read | VFSFlags::OF_Write) )
        return std::unexpected(Error{Error::POSIX, EPERM});

    if( _open_flags & VFSFlags::OF_Read ) {
        const std::expected<VFSStat, Error> st = m_Host.Stat(Path(), 0, _cancel_checker);
        if( !st )
            return std::unexpected(st.error());

        if( !S_ISREG(st->mode) )
            return std::unexpected(Error{Error::POSIX, EPERM}); // TODO: test for this

        m_Size = st->size;
        m_OpenFlags = _open_flags;
        return {};
    }
    if( _open_flags & VFSFlags::OF_Write ) {
        const std::expected<VFSStat, Error> st = m_Host.Stat(Path(), 0, _cancel_checker);

        // Refuse if the file does exist and OF_NoExist was specified
        if( (_open_flags & VFSFlags::OF_NoExist) && st ) {
            return std::unexpected(Error{Error::POSIX, EEXIST});
        }

        // Refuse if the file does not exist but OF_Create was not specified
        if( (_open_flags & VFSFlags::OF_Create) == 0 && !st ) {
            return std::unexpected(Error{Error::POSIX, ENOENT});
        }

        // If file already exist, but it is actually a directory
        if( st && st->mode_bits.dir ) {
            return std::unexpected(Error{Error::POSIX, EISDIR});
        }

        // If file already exist - remove it
        if( st ) {
            const std::expected<void, Error> unlink_rc = m_Host.Unlink(Path(), _cancel_checker);
            if( !unlink_rc )
                return unlink_rc;
        }

        // Finally verified and ready to go
        m_OpenFlags = _open_flags;
        return {};
    }
    return std::unexpected(Error{Error::POSIX, EINVAL});
}

std::expected<size_t, Error> File::Read(void *_buf, size_t _size)
{
    if( !IsOpened() || !(m_OpenFlags & VFSFlags::OF_Read) )
        return std::unexpected(Error{Error::POSIX, EINVAL});
    if( _size == 0 || Eof() )
        return 0;

    SpawnDownloadConnectionIfNeeded();

    const std::expected<void, Error> read_rc = m_Conn->ReadBodyUpToSize(_size);
    if( !read_rc )
        return std::unexpected(read_rc.error());

    auto &read_buffer = m_Conn->ResponseBody();
    const auto has_read = read_buffer.Read(_buf, _size);
    m_Pos += has_read;

    return has_read;
}

std::expected<size_t, Error> File::Write(const void *_buf, size_t _size)
{
    if( !IsOpened() || !(m_OpenFlags & VFSFlags::OF_Write) || m_Size < 0 )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    SpawnUploadConnectionIfNeeded();

    auto &write_buffer = m_Conn->RequestBody();

    // assuming it should be empty at this point?
    assert(write_buffer.Empty());

    write_buffer.Write(_buf, _size);

    const std::expected<void, Error> write_rc = m_Conn->WriteBodyUpToSize(_size);
    if( !write_rc )
        return std::unexpected(write_rc.error());

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
    std::ignore = m_Conn->SetURL(url);                  // TODO: why is rc ignored?
    std::ignore = m_Conn->SetNonBlockingUpload(m_Size); // TODO: why is rc ignored?
    m_Conn->MakeNonBlocking();
}

void File::SpawnDownloadConnectionIfNeeded()
{
    if( m_Conn )
        return;

    m_Conn = m_Host.ConnectionsPool().GetRaw();
    assert(m_Conn);
    const auto url = URIForPath(m_Host.Config(), Path());
    std::ignore = m_Conn->SetURL(url);             // TODO: why is rc ignored?
    std::ignore = m_Conn->SetCustomRequest("GET"); // TODO: why is rc ignored?
    m_Conn->MakeNonBlocking();
}

bool File::IsOpened() const
{
    return m_OpenFlags != 0;
}

std::expected<void, Error> File::Close()
{
    if( !IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    std::expected<void, Error> result;

    if( m_OpenFlags & VFSFlags::OF_Read ) {
        if( m_Conn ) {
            std::ignore = m_Conn->ReadBodyUpToSize(Connection::AbortBodyRead); // TODO: why is rc ignored?
            m_Host.ConnectionsPool().Return(std::move(m_Conn));
        }
    }
    else if( m_OpenFlags & VFSFlags::OF_Write ) {
        if( m_Size >= 0 ) {
            if( m_Conn == nullptr ) {
                // TODO: why the result code is ignored?
                std::ignore = Write("", 0); // force a connection to appear, needed for zero-byte uploads
            }

            assert(m_Conn);

            if( m_Pos < m_Size ) {
                result = m_Conn->WriteBodyUpToSize(Connection::AbortBodyWrite);
                if( !result && result.error() == Error{Error::POSIX, ECANCELED} )
                    result = {}; // explicitly eat ECANCELED as we do cancel the upload
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

    return result;
}

File::ReadParadigm File::GetReadParadigm() const
{
    return ReadParadigm::Sequential;
}

File::WriteParadigm File::GetWriteParadigm() const
{
    return WriteParadigm::Upload;
}

std::expected<uint64_t, Error> File::Pos() const
{
    return m_Pos;
}

std::expected<uint64_t, Error> File::Size() const
{
    return m_Size;
}

bool File::Eof() const
{
    if( !IsOpened() )
        return true;
    return m_Pos == m_Size;
}

std::expected<void, Error> File::SetUploadSize(size_t _size)
{
    if( !IsOpened() || m_Size >= 0 )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    m_Size = _size;

    return {};
}

} // namespace nc::vfs::webdav
