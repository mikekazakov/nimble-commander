// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/VFS/VFSFile.h"
#include "../include/VFS/VFSError.h"
#include "../include/VFS/Host.h"

using namespace nc;

VFSFile::VFSFile(std::string_view _relative_path, const VFSHostPtr &_host)
    : m_RelativePath(_relative_path), m_Host(_host)
{
}

VFSFile::~VFSFile() = default;

std::shared_ptr<VFSFile> VFSFile::SharedPtr()
{
    return shared_from_this();
}

std::shared_ptr<const VFSFile> VFSFile::SharedPtr() const
{
    return shared_from_this();
}

const char *VFSFile::Path() const noexcept
{
    return m_RelativePath.c_str();
}

const std::shared_ptr<VFSHost> &VFSFile::Host() const
{
    return m_Host;
}

VFSFile::ReadParadigm VFSFile::GetReadParadigm() const
{
    return ReadParadigm::NoRead;
}

VFSFile::WriteParadigm VFSFile::GetWriteParadigm() const
{
    return WriteParadigm::NoWrite;
}

std::expected<size_t, Error> VFSFile::Read([[maybe_unused]] void *_buf, [[maybe_unused]] size_t _size)
{
    return SetLastError(Error{Error::POSIX, ENOTSUP});
}

std::expected<size_t, Error> VFSFile::Write([[maybe_unused]] const void *_buf, [[maybe_unused]] size_t _size)
{
    return SetLastError(Error{Error::POSIX, ENOTSUP});
}

std::expected<size_t, Error>
VFSFile::ReadAt([[maybe_unused]] off_t _pos, [[maybe_unused]] void *_buf, [[maybe_unused]] size_t _size)
{
    return SetLastError(Error{Error::POSIX, ENOTSUP});
}

bool VFSFile::IsOpened() const
{
    return false;
}

int VFSFile::Open(unsigned long /*unused*/, const VFSCancelChecker & /*unused*/)
{
    return SetLastError(VFSError::NotSupported);
}

int VFSFile::Close()
{
    return SetLastError(VFSError::NotSupported);
}

std::expected<uint64_t, Error> VFSFile::Seek(off_t /*unused*/, int /*unused*/)
{
    return SetLastError(Error{Error::POSIX, ENOTSUP});
}

std::expected<uint64_t, Error> VFSFile::Pos() const
{
    return SetLastError(Error{Error::POSIX, ENOTSUP});
}

std::expected<uint64_t, Error> VFSFile::Size() const
{
    return SetLastError(Error{Error::POSIX, ENOTSUP});
}

bool VFSFile::Eof() const
{
    return true;
}

std::shared_ptr<VFSFile> VFSFile::Clone() const
{
    return {};
}

std::string VFSFile::ComposeVerbosePath() const
{
    std::array<VFSHost *, 32> hosts;
    int hosts_n = 0;

    VFSHost *cur = m_Host.get();
    while( cur ) {
        hosts[hosts_n++] = cur;
        cur = cur->Parent().get();
    }

    std::string s;
    while( hosts_n > 0 )
        s += hosts[--hosts_n]->Configuration().VerboseJunction();
    s += m_RelativePath;
    return s;
}

unsigned VFSFile::XAttrCount() const
{
    return 0;
}

void VFSFile::XAttrIterateNames([[maybe_unused]] const std::function<bool(const char *_xattr_name)> &_handler) const
{
}

std::expected<std::vector<uint8_t>, Error> VFSFile::ReadFile()
{
    if( !IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    if( GetReadParadigm() < ReadParadigm::Seek && Pos() != 0 )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    if( Pos() != 0 ) {
        const std::expected<uint64_t, Error> seek_rc = Seek(Seek_Set, 0);
        if( !seek_rc ) {
            return std::unexpected(seek_rc.error()); // can't rewind the file
        }
    }

    const std::expected<uint64_t, Error> sz = Size();
    if( !sz )
        return std::unexpected(sz.error());

    auto buf = std::vector<uint8_t>(*sz);

    uint8_t *buftmp = buf.data();
    uint64_t szleft = *sz;
    while( szleft ) {
        const std::expected<size_t, Error> r = Read(buftmp, szleft);
        if( !r ) {
            return std::unexpected(r.error());
        }
        szleft -= *r;
        buftmp += *r;
    }

    return std::move(buf);
}

std::expected<void, Error> VFSFile::WriteFile(const void *_d, size_t _sz)
{
    if( !IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    const uint8_t *d = static_cast<const uint8_t *>(_d);
    while( _sz > 0 ) {
        if( const std::expected<size_t, Error> r = Write(d, _sz); r ) {
            d += *r;
            _sz -= *r;
        }
        else {
            return std::unexpected(r.error());
        }
    }
    return {};
}

ssize_t VFSFile::XAttrGet([[maybe_unused]] const char *_xattr_name,
                          [[maybe_unused]] void *_buffer,
                          [[maybe_unused]] size_t _buf_size) const
{
    return SetLastError(VFSError::NotSupported);
}

std::expected<void, Error> VFSFile::Skip(size_t _size)
{
    const size_t trash_size = 32768;
    static char trash[trash_size];

    while( _size > 0 ) {
        const std::expected<size_t, Error> r = Read(trash, std::min(_size, trash_size));
        if( !r )
            return std::unexpected(r.error());
        if( *r == 0 )
            return std::unexpected(Error{Error::POSIX, EIO});
        _size -= *r;
    }
    return {};
}

int VFSFile::SetUploadSize([[maybe_unused]] size_t _size)
{
    return 0;
}

int VFSFile::SetLastError(int _error) const
{
    SetLastError(VFSError::ToError(_error));
    return _error;
}

std::unexpected<Error> VFSFile::SetLastError(Error _error) const
{
    m_LastError = _error;
    return std::unexpected<Error>(_error);
}

void VFSFile::ClearLastError() const
{
    m_LastError.reset();
}

std::optional<Error> VFSFile::LastError() const
{
    return m_LastError;
}

int VFSFile::PreferredIOSize() const
{
    return VFSError::NotSupported;
}
