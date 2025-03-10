// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <libarchive/archive.h>
#include <libarchive/archive_entry.h>

#include "File.h"
#include "Internal.h"
#include <VFS/AppleDoubleEA.h>
#include <Base/StackAllocator.h>
#include <fmt/format.h>
#include <sys/param.h>

namespace nc::vfs::arc {

File::File(std::string_view _relative_path, const std::shared_ptr<ArchiveHost> &_host) : VFSFile(_relative_path, _host)
{
}

File::~File()
{
    Close();
}

std::expected<void, Error> File::Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker)
{
    if( strlen(Path()) < 2 || Path()[0] != '/' )
        return SetLastError(Error{Error::POSIX, ENOENT});

    if( _open_flags & VFSFlags::OF_Write )
        return SetLastError(Error{Error::POSIX, ENOTSUP}); // ArchiveFile is Read-Only

    int res;
    auto host = std::dynamic_pointer_cast<ArchiveHost>(Host());

    StackAllocator alloc;
    std::pmr::string file_path(&alloc);
    res = host->ResolvePathIfNeeded(Path(), file_path, _open_flags);
    if( res < 0 )
        return std::unexpected(VFSError::ToError(res));

    if( host->IsDirectory(file_path, _open_flags, _cancel_checker) && !(_open_flags & VFSFlags::OF_Directory) )
        return SetLastError(Error{Error::POSIX, EISDIR});

    std::unique_ptr<State> state;
    res = host->ArchiveStateForItem(file_path.c_str(), state);
    if( res < 0 )
        return std::unexpected(VFSError::ToError(res));

    assert(state->Entry());

    // read and parse metadata(xattrs) if any
    size_t s;
    m_EA = ExtractEAFromAppleDouble(archive_entry_mac_metadata(state->Entry(), &s), s);

    m_Position = 0;
    m_Size = archive_entry_size(state->Entry());
    m_State = std::move(state);

    return {};
}

bool File::IsOpened() const
{
    return m_State != nullptr;
}

int File::Close()
{
    std::dynamic_pointer_cast<ArchiveHost>(Host())->CommitState(std::move(m_State));
    m_State.reset();
    return VFSError::Ok;
}

VFSFile::ReadParadigm File::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Sequential;
}

std::expected<uint64_t, Error> File::Pos() const
{
    if( !IsOpened() )
        return SetLastError(Error{Error::POSIX, EINVAL});
    return m_Position;
}

std::expected<uint64_t, Error> File::Size() const
{
    if( !IsOpened() )
        return SetLastError(Error{Error::POSIX, EINVAL});
    return m_Size;
}

bool File::Eof() const
{
    if( !IsOpened() )
        return true;
    return m_Position == m_Size;
}

std::expected<size_t, Error> File::Read(void *_buf, size_t _size)
{
    if( IsOpened() == 0 )
        return SetLastError(Error{Error::POSIX, EINVAL});
    if( Eof() )
        return 0;

    assert(_buf != nullptr);

    m_State->ConsumeEntry();
    const ssize_t size = archive_read_data(m_State->Archive(), _buf, _size);
    if( size < 0 ) {
        // TODO: libarchive error - convert it into our errors
        fmt::println("libarchive error: {}", archive_error_string(m_State->Archive()));
        return SetLastError(VFSError::ToError(VFSError::FromLibarchive(archive_errno(m_State->Archive()))));
    }

    m_Position += size;

    return size;
}

unsigned File::XAttrCount() const
{
    return static_cast<unsigned>(m_EA.size());
}

void File::XAttrIterateNames(const XAttrIterateNamesCallback &_handler) const
{
    if( !_handler || m_EA.empty() )
        return;

    for( auto &i : m_EA )
        if( !_handler(i.name) )
            break;
}

ssize_t File::XAttrGet(const char *_xattr_name, void *_buffer, size_t _buf_size) const
{
    if( !IsOpened() || !_xattr_name )
        return SetLastError(VFSError::InvalidCall);

    for( auto &i : m_EA )
        if( strcmp(i.name, _xattr_name) == 0 ) {
            if( _buffer == nullptr )
                return i.data_sz;

            const size_t sz = std::min(i.data_sz, static_cast<uint32_t>(_buf_size));
            std::memcpy(_buffer, i.data, sz);
            return sz;
        }

    return SetLastError(VFSError::NotFound);
}

} // namespace nc::vfs::arc
