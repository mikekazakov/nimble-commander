// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/VFS/VFSSeqToRandomWrapper.h"
#include "../include/VFS/VFSError.h"
#include <Base/CommonPaths.h>
#include <Base/algo.h>
#include <Utility/SystemInformation.h>
#include <algorithm>
#include <cerrno>
#include <climits>
#include <cstddef>
#include <cstdio>
#include <fmt/core.h>
#include <sys/fcntl.h>
#include <sys/param.h>
#include <unistd.h>

using namespace nc;

VFSSeqToRandomROWrapperFile::Backend::~Backend()
{
    if( m_FD >= 0 )
        close(m_FD);
}

VFSSeqToRandomROWrapperFile::VFSSeqToRandomROWrapperFile(const VFSFilePtr &_file_to_wrap)
    : VFSFile(_file_to_wrap->Path(), _file_to_wrap->Host()), m_SeqFile(_file_to_wrap)
{
}

VFSSeqToRandomROWrapperFile::VFSSeqToRandomROWrapperFile(const char *_relative_path,
                                                         const VFSHostPtr &_host,
                                                         std::shared_ptr<Backend> _backend)
    : VFSFile(_relative_path, _host), m_Backend(_backend)
{
}

VFSSeqToRandomROWrapperFile::~VFSSeqToRandomROWrapperFile()
{
    Close();
}

std::expected<void, Error>
VFSSeqToRandomROWrapperFile::Open(unsigned long _flags,
                                  const VFSCancelChecker &_cancel_checker,
                                  std::function<void(uint64_t _bytes_proc, uint64_t _bytes_total)> _progress)
{
    return OpenBackend(_flags, _cancel_checker, _progress);
}

std::expected<void, nc::Error>
VFSSeqToRandomROWrapperFile::OpenBackend(unsigned long _flags,
                                         VFSCancelChecker _cancel_checker,
                                         std::function<void(uint64_t _bytes_proc, uint64_t _bytes_total)> _progress)
{
    auto ggg = at_scope_end([this] { m_SeqFile.reset(); }); // ony any result wrapper won't hold any reference to
                                                            // VFSFile after this function ends
    if( !m_SeqFile )
        return std::unexpected(Error{Error::POSIX, EINVAL});
    if( m_SeqFile->GetReadParadigm() < VFSFile::ReadParadigm::Sequential )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    if( !m_SeqFile->IsOpened() ) {
        const std::expected<void, Error> res = m_SeqFile->Open(_flags);
        if( !res )
            return res;
    }
    else if( m_SeqFile->Pos().value_or(0) > 0 )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    const std::expected<uint64_t, Error> seq_file_size = m_SeqFile->Size();
    if( !seq_file_size )
        return std::unexpected(seq_file_size.error());

    auto backend = std::make_shared<Backend>();
    m_Pos = 0;

    if( *seq_file_size <= MaxCachedInMem ) {
        // we just read a whole file into a memory buffer

        backend->m_Size = *seq_file_size;
        backend->m_DataBuf = std::make_unique<uint8_t[]>(backend->m_Size);

        const size_t max_io = 256ULL * 1024ULL;
        uint8_t *d = &backend->m_DataBuf[0];
        uint8_t *e = d + backend->m_Size;

        while( d < e ) {
            const std::expected<size_t, nc::Error> res = m_SeqFile->Read(d, std::min(e - d, static_cast<long>(max_io)));
            if( !res )
                return std::unexpected(res.error());

            if( res == 0 )
                return std::unexpected(Error{Error::POSIX, EIO}); // unexpected EOF

            d += *res;

            if( _cancel_checker && _cancel_checker() )
                return std::unexpected(Error{Error::POSIX, ECANCELED});

            if( _progress )
                _progress(d - &backend->m_DataBuf[0], backend->m_Size);
        }
    }
    else {
        // we need to write it into a temp dir and delete it upon finish
        auto pattern_buf =
            fmt::format("{}{}.vfs.XXXXXX", nc::base::CommonPaths::AppTemporaryDirectory(), nc::utility::GetBundleID());

        const int fd = mkstemp(pattern_buf.data());

        if( fd < 0 )
            return std::unexpected(Error{Error::POSIX, errno});

        unlink(pattern_buf.c_str()); // preemtive unlink - OS will remove inode upon last descriptor closing

        fcntl(fd, F_NOCACHE, 1); // don't need to cache this temporaral stuff

        backend->m_FD = fd;
        backend->m_Size = *seq_file_size;

        constexpr uint64_t bufsz = 256ULL * 1024ULL;
        const std::unique_ptr<char[]> buf = std::make_unique<char[]>(bufsz);
        const uint64_t left_read = backend->m_Size;
        ssize_t total_wrote = 0;

        while( true ) {
            const std::expected<size_t, nc::Error> res = m_SeqFile->Read(buf.get(), std::min(bufsz, left_read));
            if( !res )
                return std::unexpected(res.error());

            if( res == 0 ) {
                if( total_wrote == backend->m_Size )
                    break;
                else
                    return std::unexpected(Error{Error::POSIX, EIO}); // unexpected EOF
            }

            if( _cancel_checker && _cancel_checker() )
                return std::unexpected(Error{Error::POSIX, ECANCELED});

            ssize_t res_read = *res;
            ssize_t res_write;
            while( res_read > 0 ) {
                res_write = write(backend->m_FD, buf.get(), res_read);
                if( res_write >= 0 ) {
                    res_read -= res_write;
                    total_wrote += res_write;

                    if( _progress )
                        _progress(total_wrote, backend->m_Size);
                }
                else
                    return std::unexpected(Error{Error::POSIX, errno});
            }
        }
    }

    m_Backend = backend;
    return {};
}

std::expected<void, Error> VFSSeqToRandomROWrapperFile::Open(unsigned long _flags,
                                                             const VFSCancelChecker &_cancel_checker)
{
    return Open(_flags, _cancel_checker, nullptr);
}

int VFSSeqToRandomROWrapperFile::Close()
{
    m_SeqFile.reset();
    m_Backend.reset();
    //    m_DataBuf.reset();
    //    if(m_FD >= 0) {
    //        close(m_FD);
    //        m_FD = -1;
    //    }
    //    m_Ready = false;
    return VFSError::Ok;
}

VFSFile::ReadParadigm VFSSeqToRandomROWrapperFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Random;
}

std::expected<uint64_t, Error> VFSSeqToRandomROWrapperFile::Pos() const
{
    if( !IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});
    return m_Pos;
}

std::expected<uint64_t, Error> VFSSeqToRandomROWrapperFile::Size() const
{
    if( !IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});
    return m_Backend->m_Size;
}

bool VFSSeqToRandomROWrapperFile::Eof() const
{
    if( !IsOpened() )
        return true;
    return m_Pos == m_Backend->m_Size;
}

bool VFSSeqToRandomROWrapperFile::IsOpened() const
{
    return static_cast<bool>(m_Backend);
}

std::expected<size_t, nc::Error> VFSSeqToRandomROWrapperFile::Read(void *_buf, size_t _size)
{
    const std::expected<size_t, nc::Error> result = ReadAt(m_Pos, _buf, _size);
    if( result )
        m_Pos += *result;
    return result;
}

std::expected<size_t, nc::Error> VFSSeqToRandomROWrapperFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if( !IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    if( _pos < 0 || _pos > m_Backend->m_Size )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    if( m_Backend->m_DataBuf ) {
        const ssize_t toread = std::min(m_Backend->m_Size - _pos, static_cast<off_t>(_size));
        memcpy(_buf, &m_Backend->m_DataBuf[_pos], toread);
        return toread;
    }
    else if( m_Backend->m_FD >= 0 ) {
        const ssize_t toread = std::min(m_Backend->m_Size - _pos, static_cast<off_t>(_size));
        const ssize_t res = pread(m_Backend->m_FD, _buf, toread, _pos);
        if( res >= 0 )
            return res;
        else
            return std::unexpected(Error{Error::POSIX, errno});
        ;
    }
    assert(0);
    return std::unexpected(Error{Error::POSIX, EINVAL});
}

std::expected<uint64_t, Error> VFSSeqToRandomROWrapperFile::Seek(off_t _off, int _basis)
{
    if( !IsOpened() )
        return std::unexpected(Error{Error::POSIX, EINVAL});

    // we can only deal with cache buffer now, need another branch later
    off_t req_pos = 0;
    if( _basis == VFSFile::Seek_Set )
        req_pos = _off;
    else if( _basis == VFSFile::Seek_End )
        req_pos = m_Backend->m_Size + _off;
    else if( _basis == VFSFile::Seek_Cur )
        req_pos = m_Pos + _off;
    else
        return std::unexpected(Error{Error::POSIX, EINVAL});

    if( req_pos < 0 )
        return std::unexpected(Error{Error::POSIX, EINVAL});
    req_pos = std::min<off_t>(req_pos, m_Backend->m_Size);
    m_Pos = req_pos;

    return m_Pos;
}

std::shared_ptr<VFSSeqToRandomROWrapperFile> VFSSeqToRandomROWrapperFile::Share()
{
    if( !IsOpened() )
        return nullptr;
    return std::shared_ptr<VFSSeqToRandomROWrapperFile>(new VFSSeqToRandomROWrapperFile(Path(), Host(), m_Backend));
}
