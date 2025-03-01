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

int VFSSeqToRandomROWrapperFile::Open(unsigned long _flags,
                                      const VFSCancelChecker &_cancel_checker,
                                      std::function<void(uint64_t _bytes_proc, uint64_t _bytes_total)> _progress)
{
    const int ret = OpenBackend(_flags, _cancel_checker, _progress);
    return ret;
}

int VFSSeqToRandomROWrapperFile::OpenBackend(unsigned long _flags,
                                             VFSCancelChecker _cancel_checker,
                                             std::function<void(uint64_t _bytes_proc, uint64_t _bytes_total)> _progress)
{
    auto ggg = at_scope_end([this] { m_SeqFile.reset(); }); // ony any result wrapper won't hold any reference to
                                                            // VFSFile after this function ends
    if( !m_SeqFile )
        return VFSError::InvalidCall;
    if( m_SeqFile->GetReadParadigm() < VFSFile::ReadParadigm::Sequential )
        return VFSError::InvalidCall;

    if( !m_SeqFile->IsOpened() ) {
        const int res = m_SeqFile->Open(_flags);
        if( res < 0 )
            return res;
    }
    else if( m_SeqFile->Pos() > 0 )
        return VFSError::InvalidCall;

    auto backend = std::make_shared<Backend>();
    m_Pos = 0;

    if( m_SeqFile->Size() <= MaxCachedInMem ) {
        // we just read a whole file into a memory buffer

        backend->m_Size = m_SeqFile->Size();
        backend->m_DataBuf = std::make_unique<uint8_t[]>(backend->m_Size);

        const size_t max_io = 256ULL * 1024ULL;
        uint8_t *d = &backend->m_DataBuf[0];
        uint8_t *e = d + backend->m_Size;
        ssize_t res = 0;
        while( d < e && (res = m_SeqFile->Read(d, std::min(e - d, static_cast<long>(max_io)))) > 0 ) {
            d += res;

            if( _cancel_checker && _cancel_checker() )
                return VFSError::Cancelled;

            if( _progress )
                _progress(d - &backend->m_DataBuf[0], backend->m_Size);
        }

        if( _cancel_checker && _cancel_checker() )
            return VFSError::Cancelled;

        if( res < 0 )
            return static_cast<int>(res);

        if( res == 0 && d != e )
            return VFSError::UnexpectedEOF;
    }
    else {
        // we need to write it into a temp dir and delete it upon finish
        auto pattern_buf =
            fmt::format("{}{}.vfs.XXXXXX", nc::base::CommonPaths::AppTemporaryDirectory(), nc::utility::GetBundleID());

        const int fd = mkstemp(pattern_buf.data());

        if( fd < 0 )
            return VFSError::FromErrno(errno);

        unlink(pattern_buf.c_str()); // preemtive unlink - OS will remove inode upon last descriptor closing

        fcntl(fd, F_NOCACHE, 1); // don't need to cache this temporaral stuff

        backend->m_FD = fd;
        backend->m_Size = m_SeqFile->Size();

        constexpr uint64_t bufsz = 256ULL * 1024ULL;
        const std::unique_ptr<char[]> buf = std::make_unique<char[]>(bufsz);
        const uint64_t left_read = backend->m_Size;
        ssize_t res_read;
        ssize_t total_wrote = 0;

        while( (res_read = m_SeqFile->Read(buf.get(), std::min(bufsz, left_read))) > 0 ) {
            if( _cancel_checker && _cancel_checker() )
                return VFSError::Cancelled;

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
                    return VFSError::FromErrno(errno);
            }
        }

        if( res_read < 0 )
            return static_cast<int>(res_read);

        if( res_read == 0 && total_wrote != backend->m_Size )
            return VFSError::UnexpectedEOF;
    }

    m_Backend = backend;
    return VFSError::Ok;
}

int VFSSeqToRandomROWrapperFile::Open(unsigned long _flags, const VFSCancelChecker &_cancel_checker)
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

ssize_t VFSSeqToRandomROWrapperFile::Pos() const
{
    if( !IsOpened() )
        return VFSError::InvalidCall;
    return m_Pos;
}

ssize_t VFSSeqToRandomROWrapperFile::Size() const
{
    if( !IsOpened() )
        return VFSError::InvalidCall;
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

ssize_t VFSSeqToRandomROWrapperFile::Read(void *_buf, size_t _size)
{
    const std::expected<size_t, nc::Error> result = ReadAt(m_Pos, _buf, _size);
    if( result )
        m_Pos += *result;
    return /*result*/ -1; // TODO: return result
}

std::expected<size_t, nc::Error> VFSSeqToRandomROWrapperFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if( !IsOpened() )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

    if( _pos < 0 || _pos > m_Backend->m_Size )
        return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});

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
            return std::unexpected(nc::Error{nc::Error::POSIX, errno});
        ;
    }
    assert(0);
    return std::unexpected(nc::Error{nc::Error::POSIX, EINVAL});
}

off_t VFSSeqToRandomROWrapperFile::Seek(off_t _off, int _basis)
{
    if( !IsOpened() )
        return VFSError::InvalidCall;

    // we can only deal with cache buffer now, need another branch later
    off_t req_pos = 0;
    if( _basis == VFSFile::Seek_Set )
        req_pos = _off;
    else if( _basis == VFSFile::Seek_End )
        req_pos = m_Backend->m_Size + _off;
    else if( _basis == VFSFile::Seek_Cur )
        req_pos = m_Pos + _off;
    else
        return VFSError::InvalidCall;

    if( req_pos < 0 )
        return VFSError::InvalidCall;
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
