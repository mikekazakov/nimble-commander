// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "File.h"
#include "Host.h"
#include "Internals.h"
#include "Cache.h"
#include <Utility/PathManip.h>
#include <fmt/format.h>
#include <VFS/Log.h>

#include <algorithm>

namespace nc::vfs::ftp {

File::File(std::string_view _relative_path, std::shared_ptr<FTPHost> _host) : VFSFile(_relative_path, _host)
{
    Log::Trace("File::File({}, {}) called", _relative_path, static_cast<void *>(_host.get()));
}

File::~File()
{
    Log::Trace("File::~File() called");
    Close();
}

bool File::IsOpened() const
{
    return m_Mode != Mode::Closed;
}

int File::Close()
{
    Log::Trace("File::Close() called");

    if( m_CURL && m_Mode == Mode::Write ) {
        // if we're still writing - finish it and tell cache about changes
        FinishWriting();
        std::dynamic_pointer_cast<FTPHost>(Host())->Cache().CommitNewFile(Path());
    }
    if( m_CURL && m_Mode == Mode::Read ) {
        // if we're still reading something - cancel it and wait
        FinishReading();
    }

    if( m_CURL ) {
        auto host = std::dynamic_pointer_cast<FTPHost>(Host());
        host->CommitIOInstanceAtDir(DirName().c_str(), std::move(m_CURL));
    }

    m_FilePos = 0;
    m_FileSize = 0;
    m_Mode = Mode::Closed;
    m_ReadBuf.Clear();
    m_BufFileOffset = 0;
    m_CURL.reset();
    m_URLRequest.clear();
    return 0;
}

std::filesystem::path File::DirName() const
{
    return utility::PathManip::EnsureTrailingSlash(std::filesystem::path(Path()).parent_path());
}

int File::Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker)
{
    Log::Trace("File::Open({}) called", _open_flags);
    auto ftp_host = std::dynamic_pointer_cast<FTPHost>(Host());
    const std::expected<VFSStat, Error> stat = ftp_host->Stat(Path(), 0, _cancel_checker);
    Log::Trace("stat is {}", stat ? "ok" : "not ok");

    if( stat && ((stat->mode & S_IFMT) == S_IFREG) && (_open_flags & VFSFlags::OF_Read) != 0 &&
        (_open_flags & VFSFlags::OF_Write) == 0 ) {
        m_URLRequest = ftp_host->BuildFullURLString(Path());
        m_CURL = ftp_host->InstanceForIOAtDir(DirName().c_str());
        m_FileSize = stat->size;

        if( m_FileSize == 0 ) {
            m_Mode = Mode::Read;
            return 0;
        }

        if( ReadChunk(nullptr, 1, 0, _cancel_checker) == 1 ) {
            m_Mode = Mode::Read;
            return 0;
        }

        Close();

        return VFSError::GenericError;
    }
    else if( (!(_open_flags & VFSFlags::OF_NoExist) || !stat) && //
             (_open_flags & VFSFlags::OF_Read) == 0 &&           //
             (_open_flags & VFSFlags::OF_Write) != 0 ) {
        m_URLRequest = ftp_host->BuildFullURLString(Path());
        m_CURL = ftp_host->InstanceForIOAtDir(DirName().c_str());

        if( m_CURL->IsAttached() )
            m_CURL->Detach();
        m_CURL->EasySetOpt(CURLOPT_URL, m_URLRequest.c_str());
        m_CURL->EasySetOpt(CURLOPT_UPLOAD, 1l);
        m_CURL->EasySetOpt(CURLOPT_INFILESIZE, -1l);
        m_CURL->EasySetOpt(CURLOPT_READFUNCTION, WriteBuffer::Read);
        m_CURL->EasySetOpt(CURLOPT_READDATA, &m_WriteBuf);

        m_FilePos = 0;
        m_FileSize = 0;
        if( _open_flags & VFSFlags::OF_Append ) {
            m_CURL->EasySetOpt(CURLOPT_APPEND, 1l);

            if( stat ) {
                m_FilePos = stat->size;
                m_FileSize = stat->size;
            }
        }

        m_CURL->Attach();

        m_Mode = Mode::Write;
        return 0;
    }

    return VFSError::NotSupported;
}

ssize_t File::ReadChunk(void *_read_to, uint64_t _read_size, uint64_t _file_offset, VFSCancelChecker _cancel_checker)
{
    Log::Trace("File::ReadChunk({}, {}, {}) called", _read_to, _read_size, _file_offset);

    // TODO: mutex lock
    bool error = false;

    const bool can_fulfill =
        _file_offset >= m_BufFileOffset && _file_offset + _read_size <= m_BufFileOffset + m_ReadBuf.Size();

    if( !can_fulfill ) {
        // can't satisfy request from memory buffer, need to perform I/O

        // check for dead connection
        // check for big offset changes so we need to restart connection
        bool has_range = false;
        if( _file_offset < m_BufFileOffset ||                    //
            _file_offset > m_BufFileOffset + m_ReadBuf.Size() || //
            m_CURL->RunningHandles() == 0 ) {                    // (re)connect

            // create a brand new ftp request (possibly reusing exiting network connection)
            m_ReadBuf.Clear();
            m_BufFileOffset = _file_offset;

            if( m_CURL->IsAttached() )
                m_CURL->Detach();

            m_CURL->EasySetOpt(CURLOPT_URL, m_URLRequest.c_str());
            m_CURL->EasySetOpt(CURLOPT_WRITEFUNCTION, ReadBuffer::Write);
            m_CURL->EasySetOpt(CURLOPT_WRITEDATA, &m_ReadBuf);
            m_CURL->EasySetOpt(CURLOPT_UPLOAD, 0l);
            m_CURL->EasySetOpt(CURLOPT_INFILESIZE, -1l);
            m_CURL->EasySetOpt(CURLOPT_READFUNCTION, nullptr);
            m_CURL->EasySetOpt(CURLOPT_READDATA, nullptr);
            m_CURL->EasySetOpt(CURLOPT_LOW_SPEED_LIMIT, 1l);
            m_CURL->EasySetOpt(CURLOPT_LOW_SPEED_TIME, 60l);
            m_CURL->EasySetupProgFunc();

            if( _file_offset != 0 ) {
                char range[16];
                *fmt::format_to(range, "{}-", _file_offset) = 0;
                m_CURL->EasySetOpt(CURLOPT_RANGE, range); // set offset
                has_range = true;
            }

            m_CURL->Attach();
        }

        int still_running = 0;
        do {
            CURLMcode mc;
            mc = curl_multi_perform(m_CURL->curlm, &still_running);
            if( mc == CURLM_OK ) {
                mc = curl_multi_wait(m_CURL->curlm, nullptr, 0, m_SelectTimeout.tv_usec, nullptr);
            }
            if( mc != CURLM_OK ) {
                Log::Error("curl_multi failed, code {}.", std::to_underlying(mc));
                error = true;
                break;
            }
            if( has_range ) {
                curl_easy_setopt(m_CURL->curl, CURLOPT_RANGE, nullptr);
                has_range = false;
            }
            if( _cancel_checker && _cancel_checker() ) {
                return VFSError::Cancelled;
            }
        } while( still_running && (m_ReadBuf.Size() < _read_size + _file_offset - m_BufFileOffset) );

        // check for error codes here
        if( still_running == 0 ) {
            int msgs_left = 1;
            while( msgs_left ) {
                CURLMsg *msg = curl_multi_info_read(m_CURL->curlm, &msgs_left);
                if( msg == nullptr || msg->msg != CURLMSG_DONE || msg->data.result != CURLE_OK ) {
                    Log::Error("curl_multi_info_read() returned {}.", std::to_underlying(msg->msg));
                    error = true;
                }
            }
        }
    }

    if( error )
        return VFSError::FromErrno(EIO);

    if( m_BufFileOffset < _file_offset ) {
        const uint64_t discard = std::min(m_ReadBuf.Size(), static_cast<size_t>(_file_offset - m_BufFileOffset));
        m_ReadBuf.Discard(discard);
        m_BufFileOffset += discard;
    }

    assert(m_BufFileOffset >= _file_offset);
    const size_t available = m_BufFileOffset >= _file_offset ? m_ReadBuf.Size() + m_BufFileOffset - _file_offset : 0;
    const size_t size = _read_size > available ? available : _read_size;

    if( _read_to != nullptr && size > 0 ) {
        const size_t buf_offset = _file_offset - m_BufFileOffset;
        memcpy(_read_to, static_cast<const uint8_t *>(m_ReadBuf.Data()) + buf_offset, size);
        m_ReadBuf.Discard(buf_offset + size);
        m_BufFileOffset = _file_offset + size;
    }

    return size;
}

ssize_t File::Read(void *_buf, size_t _size)
{
    Log::Trace("File::Read({}, {}) called", _buf, _size);
    if( Eof() )
        return 0;

    const ssize_t ret = ReadChunk(_buf, _size, m_FilePos, nullptr);
    if( ret < 0 )
        return ret;

    m_FilePos += ret;
    return ret;
}

ssize_t File::Write(const void *_buf, size_t _size)
{
    Log::Trace("File::Write({}, {}) called", _buf, _size);
    // TODO: reconnecting support

    if( !IsOpened() )
        return VFSError::InvalidCall;

    assert(m_WriteBuf.Consumed() == 0);
    m_WriteBuf.Write(_buf, _size);

    bool error = false;

    int still_running = 0;
    do {
        CURLMcode mc;
        mc = curl_multi_perform(m_CURL->curlm, &still_running);
        if( mc == CURLM_OK ) {
            mc = curl_multi_wait(m_CURL->curlm, nullptr, 0, m_SelectTimeout.tv_usec, nullptr);
        }
        if( mc != CURLM_OK ) {
            Log::Error("curl_multi failed, code {}.", std::to_underlying(mc));
            break;
        }
    } while( still_running && !m_WriteBuf.Exhausted() );

    // check for error codes here
    if( still_running == 0 ) {
        int msgs_left = 1;
        while( msgs_left ) {
            CURLMsg *msg = curl_multi_info_read(m_CURL->curlm, &msgs_left);
            if( msg == nullptr || msg->msg != CURLMSG_DONE || msg->data.result != CURLE_OK ) {
                Log::Error("curl_multi_info_read() returned {}.", std::to_underlying(msg->msg));
                error = true;
            }
        }
    }

    if( error )
        return VFSError::FromErrno(EIO);

    m_FilePos += m_WriteBuf.Consumed();
    m_FileSize += m_WriteBuf.Consumed();
    m_WriteBuf.DiscardConsumed();

    return _size;
}

VFSFile::ReadParadigm File::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Seek;
}

VFSFile::WriteParadigm File::GetWriteParadigm() const
{
    return VFSFile::WriteParadigm::Sequential;
}

ssize_t File::Pos() const
{
    return m_FilePos;
}

ssize_t File::Size() const
{
    return m_FileSize;
}

bool File::Eof() const
{
    Log::Trace("File::Eof() called");
    if( !IsOpened() )
        return true;
    return m_FilePos >= m_FileSize;
}

off_t File::Seek(off_t _off, int _basis)
{
    Log::Trace("File::Seek({}, {}) called", _off, _basis);
    if( !IsOpened() )
        return VFSError::InvalidCall;

    if( m_Mode != Mode::Read )
        return VFSError::InvalidCall;

    // we can only deal with cache buffer now, need another branch later
    off_t req_pos = 0;
    if( _basis == VFSFile::Seek_Set )
        req_pos = _off;
    else if( _basis == VFSFile::Seek_End )
        req_pos = m_FileSize + _off;
    else if( _basis == VFSFile::Seek_Cur )
        req_pos = m_FilePos + _off;
    else
        return VFSError::InvalidCall;

    if( req_pos < 0 )
        return VFSError::InvalidCall;
    req_pos = std::min(req_pos, static_cast<off_t>(m_FileSize));

    m_FilePos = req_pos;

    return m_FilePos;
}

void File::FinishWriting()
{
    Log::Trace("File::FinishWriting() called");
    assert(m_Mode == Mode::Write);

    int still_running = 0;
    do {
        CURLMcode mc = curl_multi_perform(m_CURL->curlm, &still_running);
        if( mc == CURLM_OK ) {
            mc = curl_multi_wait(m_CURL->curlm, nullptr, 0, m_SelectTimeout.tv_usec, nullptr);
        }
        if( mc != CURLM_OK ) {
            Log::Error("curl_multi failed, code {}.", std::to_underlying(mc));
            break;
        }
    } while( still_running );
}

void File::FinishReading()
{
    Log::Trace("File::FinishReading() called");
    assert(m_Mode == Mode::Read);

    // tell curl to cancel any going reading if any
    m_CURL->prog_func = ^(curl_off_t, curl_off_t, curl_off_t, curl_off_t) {
      return 1;
    };

    int running_handles = 0;
    do {
        while( CURLM_CALL_MULTI_PERFORM == curl_multi_perform(m_CURL->curlm, &running_handles) )
            ;
    } while( running_handles );
}

} // namespace nc::vfs::ftp
