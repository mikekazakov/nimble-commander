// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "File.h"
#include "Host.h"
#include "Internals.h"
#include "Cache.h"

namespace nc::vfs::ftp {

File::File(const char* _relative_path, shared_ptr<FTPHost> _host):
    VFSFile(_relative_path, _host),
    m_ReadBuf(make_unique<ReadBuffer>()),
    m_WriteBuf(make_unique<WriteBuffer>())
{
}

File::~File()
{
    Close();
}

bool File::IsOpened() const
{
    return m_Mode != Mode::Closed;
}

int File::Close()
{
    if(m_CURL && m_Mode == Mode::Write)
    {
        // if we're still writing - finish it and tell cache about changes
        FinishWriting();
        dynamic_pointer_cast<FTPHost>(Host())->Cache().CommitNewFile(Path());
    }
    if(m_CURL && m_Mode == Mode::Read)
    {
        // if we're still reading something - cancel it and wait
        FinishReading();
    }
    
    if(m_CURL)
    {
        auto host = dynamic_pointer_cast<FTPHost>(Host());
        host->CommitIOInstanceAtDir(DirName().c_str(), move(m_CURL));
    }

    m_FilePos = 0;
    m_FileSize = 0;
    m_Mode = Mode::Closed;
    m_ReadBuf->clear();
    m_BufFileOffset = 0;
    m_CURL.reset();
    m_URLRequest.clear();
    return 0;
}

path File::DirName() const
{
    return path(Path()).parent_path();
}

int File::Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker)
{
    auto ftp_host = dynamic_pointer_cast<FTPHost>(Host());
    VFSStat stat;
    int stat_ret = ftp_host->Stat(Path(), stat, 0, _cancel_checker);
    
    if( stat_ret == 0 &&
       ((stat.mode & S_IFMT) == S_IFREG) &&
       (_open_flags & VFSFlags::OF_Read) != 0 &&
       (_open_flags & VFSFlags::OF_Write) == 0 )
    {
        m_URLRequest = ftp_host->BuildFullURLString(Path());
        m_CURL  = ftp_host->InstanceForIOAtDir(DirName().c_str());
        m_FileSize = stat.size;
        
        if(m_FileSize == 0)
        {
            m_Mode = Mode::Read;
            return 0;
        }
        
        if(ReadChunk(nullptr, 1, 0, _cancel_checker) == 1)
        {
            m_Mode = Mode::Read;
            return 0;
        }
        
        Close();
        
        return VFSError::GenericError;
    }
    else if(
            (!(_open_flags & VFSFlags::OF_NoExist) || stat_ret != 0) &&
            (_open_flags & VFSFlags::OF_Read)  == 0 &&
            (_open_flags & VFSFlags::OF_Write) != 0 )
    {        
        m_URLRequest = ftp_host->BuildFullURLString(Path());
        m_CURL = ftp_host->InstanceForIOAtDir(DirName().c_str());
        
        if(m_CURL->IsAttached())
            m_CURL->Detach();
        m_CURL->EasySetOpt(CURLOPT_URL, m_URLRequest.c_str());
        m_CURL->EasySetOpt(CURLOPT_UPLOAD, 1);
        m_CURL->EasySetOpt(CURLOPT_INFILESIZE, -1);
        m_CURL->EasySetOpt(CURLOPT_READFUNCTION, WriteBuffer::read_from_function);
        m_CURL->EasySetOpt(CURLOPT_READDATA, m_WriteBuf.get());

        m_FilePos = 0;
        m_FileSize = 0;
        if(_open_flags & VFSFlags::OF_Append)
        {
            m_CURL->EasySetOpt(CURLOPT_APPEND, 1);
  
            if(stat_ret == 0)
            {
                m_FilePos = stat.size;
                m_FileSize = stat.size;
            }
        }

        m_CURL->Attach();
        
        m_Mode = Mode::Write;
        return 0;
    }
    
    return VFSError::NotSupported;
}

ssize_t File::ReadChunk(
                                 void *_read_to,
                                 uint64_t _read_size,
                                 uint64_t _file_offset,
                                 VFSCancelChecker _cancel_checker
                                 )
{
    // TODO: mutex lock
    bool error = false;
    
    if ( (m_ReadBuf->size < _read_size + _file_offset - m_BufFileOffset ||
          _file_offset < m_BufFileOffset ||
          _file_offset > m_BufFileOffset + m_ReadBuf->size) &&
         (m_ReadBuf->size < m_FileSize)
        )
    {
        // can't satisfy request from memory buffer, need to perform I/O

        // check for dead connection
        // check for big offset changes so we need to restart connection
        if(_file_offset < m_BufFileOffset ||
           _file_offset > m_BufFileOffset + m_ReadBuf->size ||
           m_CURL->RunningHandles() == 0)
        { // (re)connect
            
            // create a brand new ftp request (possibly reusing exiting network connection)
            m_ReadBuf->clear();
            m_BufFileOffset = _file_offset;
            
            if(m_CURL->IsAttached())
                m_CURL->Detach();
            
            m_CURL->EasySetOpt(CURLOPT_URL, m_URLRequest.c_str());
            m_CURL->EasySetOpt(CURLOPT_WRITEFUNCTION, ReadBuffer::write_here_function);
            m_CURL->EasySetOpt(CURLOPT_WRITEDATA, m_ReadBuf.get());
            m_CURL->EasySetOpt(CURLOPT_UPLOAD, 0);
            m_CURL->EasySetOpt(CURLOPT_INFILESIZE, -1);
            m_CURL->EasySetOpt(CURLOPT_READFUNCTION, 0);
            m_CURL->EasySetOpt(CURLOPT_READDATA, 0);
            m_CURL->EasySetOpt(CURLOPT_LOW_SPEED_LIMIT, 1);
            m_CURL->EasySetOpt(CURLOPT_LOW_SPEED_TIME, 60);
            m_CURL->EasySetupProgFunc();
            
            if (_file_offset) { // set offsets
                char range[16];
                snprintf(range, 16, "%lld-", _file_offset);
                m_CURL->EasySetOpt(CURLOPT_RANGE, range);
            }

            m_CURL->Attach();
        }
    
        int running_handles = 0;

        while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(m_CURL->curlm, &running_handles));

        curl_easy_setopt(m_CURL->curl, CURLOPT_RANGE, NULL);
        
        while( (m_ReadBuf->size < _read_size + _file_offset - m_BufFileOffset) && running_handles)
        {
            struct timeval timeout = m_SelectTimeout;
            
            fd_set fdread, fdwrite, fdexcep;
            int maxfd;
        
            FD_ZERO(&fdread);
            FD_ZERO(&fdwrite);
            FD_ZERO(&fdexcep);
            curl_multi_fdset(m_CURL->curlm, &fdread, &fdwrite, &fdexcep, &maxfd);
        
            if (select(maxfd+1, &fdread, &fdwrite, &fdexcep, &timeout) == -1) {
                NSLog(@"!!");
                error = true;
                break;
            }
        
            while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(m_CURL->curlm, &running_handles))
                if(_cancel_checker && _cancel_checker())
                    return VFSError::Cancelled;
        }

        // check for error codes here
        if (running_handles == 0) {
            int msgs_left = 1;
            while (msgs_left)
            {
                CURLMsg* msg = curl_multi_info_read(m_CURL->curlm, &msgs_left);
                if (msg == NULL ||
                    msg->msg != CURLMSG_DONE ||
                    msg->data.result != CURLE_OK) {
//                    DEBUG(1, "error: curl_multi_info %d\n", msg->msg);
//                    err = 1;
                    NSLog(@"!!!");
                    error = true;
                }
            }
        }
    }
    
    if(error)
        return VFSError::FromErrno(EIO);

    assert(m_BufFileOffset >= _file_offset);
    size_t to_copy = m_ReadBuf->size + m_BufFileOffset - _file_offset;
    size_t size = _read_size > to_copy ? to_copy : _read_size;
  
    if(_read_to != nullptr)
    {
        memcpy(_read_to, m_ReadBuf->buf + _file_offset - m_BufFileOffset, size);
        m_ReadBuf->discard( _file_offset - m_BufFileOffset + size );
        m_BufFileOffset = _file_offset + size;
    }
    
    return size;
}

ssize_t File::Read(void *_buf, size_t _size)
{
    if(Eof())
        return 0;
    
    ssize_t ret = ReadChunk(_buf, _size, m_FilePos, 0);
    if(ret < 0)
        return ret;

    m_FilePos += ret;
    return ret;
}

ssize_t File::Write(const void *_buf, size_t _size)
{
    // TODO: reconnecting support
    
    if(!IsOpened())
        return VFSError::InvalidCall;
    
    assert(m_WriteBuf->feed_size == 0);
    m_WriteBuf->add(_buf, _size);
    
    bool error = false;
    
    int running_handles = 0;
    while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(m_CURL->curlm, &running_handles));
    
    while( m_WriteBuf->feed_size < m_WriteBuf->size && running_handles )
    {
        struct timeval timeout = m_SelectTimeout;
        
        fd_set fdread, fdwrite, fdexcep;
        int maxfd;
        
        FD_ZERO(&fdread);
        FD_ZERO(&fdwrite);
        FD_ZERO(&fdexcep);
        curl_multi_fdset(m_CURL->curlm, &fdread, &fdwrite, &fdexcep, &maxfd);
        
        if (select(maxfd+1, &fdread, &fdwrite, &fdexcep, &timeout) == -1) {
            NSLog(@"!!");
            error = true;
            break;
        }
        
        while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(m_CURL->curlm, &running_handles));
    }
    
    // check for error codes here
    if (running_handles == 0) {
        NSLog(@"running_handles == 0");
        int msgs_left = 1;
        while (msgs_left)
        {
            CURLMsg* msg = curl_multi_info_read(m_CURL->curlm, &msgs_left);
            if (msg == NULL ||
                msg->msg != CURLMSG_DONE ||
                msg->data.result != CURLE_OK) {
                NSLog(@"!!!");
                error = true;
            }
        }
    }

    if(error == true)
        return VFSError::FromErrno(EIO);

    m_FilePos += m_WriteBuf->feed_size;
    m_FileSize += m_WriteBuf->feed_size;
    
    m_WriteBuf->discard(m_WriteBuf->feed_size);
    m_WriteBuf->feed_size = 0;

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
    if(!IsOpened())
        return true;
    return m_FilePos >= m_FileSize;
}

off_t File::Seek(off_t _off, int _basis)
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    
    if(m_Mode != Mode::Read)
        return VFSError::InvalidCall;;
    
    // we can only deal with cache buffer now, need another branch later
    off_t req_pos = 0;
    if(_basis == VFSFile::Seek_Set)
        req_pos = _off;
    else if(_basis == VFSFile::Seek_End)
        req_pos = m_FileSize + _off;
    else if(_basis == VFSFile::Seek_Cur)
        req_pos = m_FileSize + _off;
    else
        return VFSError::InvalidCall;
    
    if(req_pos < 0)
        return VFSError::InvalidCall;
    if(req_pos > (off_t)m_FileSize)
        req_pos = (off_t)m_FileSize;

    m_FilePos = req_pos;
    
    return m_FilePos;
}

void File::FinishWriting()
{
    assert(m_Mode == Mode::Write);
    
    if(m_CURL->RunningHandles() <= 0)
        return;
    
    // tell curl that data is over
    m_WriteBuf->discard(m_WriteBuf->size);
    int running_handles = 0;
    while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(m_CURL->curlm, &running_handles));
    while(running_handles)
    {
        struct timeval timeout = m_SelectTimeout;
        
        fd_set fdread, fdwrite, fdexcep;
        int maxfd;
        
        FD_ZERO(&fdread);
        FD_ZERO(&fdwrite);
        FD_ZERO(&fdexcep);
        curl_multi_fdset(m_CURL->curlm, &fdread, &fdwrite, &fdexcep, &maxfd);
        
        if (select(maxfd+1, &fdread, &fdwrite, &fdexcep, &timeout) == -1)
            break;
        
        while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(m_CURL->curlm, &running_handles));
    }
}

void File::FinishReading()
{
    assert(m_Mode == Mode::Read);
    
    // tell curl to cancel any going reading if any
    m_CURL->prog_func = ^(double, double, double, double) {
        return 1;
    };

    int running_handles = 0;
    do {
        while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(m_CURL->curlm, &running_handles));
    } while(running_handles);
}

}
