//
//  VFSNetFTPFile.mm
//  Files
//
//  Created by Michael G. Kazakov on 19.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "VFSNetFTPFile.h"
#import "VFSNetFTPHost.h"
#import "VFSNetFTPInternals.h"

// implementation highly inspired by curlftpfs.

//CURLOPT_VERBOSE
#if 0
static size_t ftpfs_read_chunk(const char* full_path, char* rbuf,
                               size_t size, off_t offset,
                               struct fuse_file_info* fi,
                               int update_offset) {
    int running_handles = 0;
    int err = 0;
    struct ftpfs_file* fh = get_ftpfs_file(fi);
    
    DEBUG(2, "ftpfs_read_chunk: %s %p %zu %lld %p %p\n",
          full_path, rbuf, size, offset, fi, fh);
    
    pthread_mutex_lock(&ftpfs.lock);
    
    DEBUG(2, "buffer size: %zu %lld\n", fh->buf.len, fh->buf.begin_offset);
    
    if ((fh->buf.len < size + offset - fh->buf.begin_offset) ||
        offset < fh->buf.begin_offset ||
        offset > fh->buf.begin_offset + fh->buf.len) {
        // We can't answer this from cache
        if (ftpfs.current_fh != fh ||
            offset < fh->buf.begin_offset ||
            offset > fh->buf.begin_offset + fh->buf.len ||
            !check_running()) {
            DEBUG(1, "We need to restart the connection %p\n", ftpfs.connection);
            DEBUG(2, "current_fh=%p fh=%p\n", ftpfs.current_fh, fh);
            DEBUG(2, "buf.begin_offset=%lld offset=%lld\n", fh->buf.begin_offset, offset);
            
            buf_clear(&fh->buf);
            fh->buf.begin_offset = offset;
            ftpfs.current_fh = fh;
            
            cancel_previous_multi();
            
            curl_easy_setopt_or_die(ftpfs.connection, CURLOPT_URL, full_path);
            curl_easy_setopt_or_die(ftpfs.connection, CURLOPT_WRITEDATA, &fh->buf);
            if (offset) {
                char range[15];
                snprintf(range, 15, "%lld-", (long long) offset);
                curl_easy_setopt_or_die(ftpfs.connection, CURLOPT_RANGE, range);
            }
            
            CURLMcode curlMCode =  curl_multi_add_handle(ftpfs.multi, ftpfs.connection);
            if (curlMCode != CURLE_OK)
            {
                fprintf(stderr, "curl_multi_add_handle problem: %d\n", curlMCode);
                exit(1);
            }
            ftpfs.attached_to_multi = 1;
        }
        
        while(CURLM_CALL_MULTI_PERFORM ==
              curl_multi_perform(ftpfs.multi, &running_handles));
        
        curl_easy_setopt_or_die(ftpfs.connection, CURLOPT_RANGE, NULL);
        
        while ((fh->buf.len < size + offset - fh->buf.begin_offset) &&
               running_handles) {
            struct timeval timeout;
            int rc; /* select() return code */
            
            fd_set fdread;
            fd_set fdwrite;
            fd_set fdexcep;
            int maxfd;
            
            FD_ZERO(&fdread);
            FD_ZERO(&fdwrite);
            FD_ZERO(&fdexcep);
            
            /* set a suitable timeout to play around with */
            timeout.tv_sec = 1;
            timeout.tv_usec = 0;
            
            /* get file descriptors from the transfers */
            curl_multi_fdset(ftpfs.multi, &fdread, &fdwrite, &fdexcep, &maxfd);
            
            rc = select(maxfd+1, &fdread, &fdwrite, &fdexcep, &timeout);
            if (rc == -1) {
                err = 1;
                break;
            }
            while(CURLM_CALL_MULTI_PERFORM ==
                  curl_multi_perform(ftpfs.multi, &running_handles));
        }
        
        if (running_handles == 0) {
            int msgs_left = 1;
            while (msgs_left) {
                CURLMsg* msg = curl_multi_info_read(ftpfs.multi, &msgs_left);
                if (msg == NULL ||
                    msg->msg != CURLMSG_DONE ||
                    msg->data.result != CURLE_OK) {
                    DEBUG(1, "error: curl_multi_info %d\n", msg->msg);
                    err = 1;
                }
            }
        }
    }
    
    size_t to_copy = fh->buf.len + fh->buf.begin_offset - offset;
    size = size > to_copy ? to_copy : size;
    if (rbuf) {
        memcpy(rbuf, fh->buf.p + offset - fh->buf.begin_offset, size);
    }
    
    // Check if the buffer is growing and we can delete a part of it
    if (fh->can_shrink && fh->buf.len > MAX_BUFFER_LEN) {
        DEBUG(2, "Shrinking buffer from %zu to %zu bytes\n",
              fh->buf.len, to_copy - size);
        memmove(fh->buf.p,
                fh->buf.p + offset - fh->buf.begin_offset + size,
                to_copy - size);
        fh->buf.len = to_copy - size;
        fh->buf.begin_offset = offset + size;
    }
    
    pthread_mutex_unlock(&ftpfs.lock);
    
    if (err) return CURLFTPFS_BAD_READ;
    return size;
}
#endif

using namespace VFSNetFTP;

VFSNetFTPFile::VFSNetFTPFile(const char* _relative_path,
                             shared_ptr<VFSNetFTPHost> _host):
    VFSFile(_relative_path, _host),
    m_Buf(make_unique<Buffer>())
{
}

VFSNetFTPFile::~VFSNetFTPFile()
{
    if(m_CURLM)
    {
        if(m_CURL)
            curl_multi_remove_handle(m_CURLM->curlm, m_CURL->curl);
    }
}

int VFSNetFTPFile::Open(int _open_flags, bool (^_cancel_checker)())
{
    auto ftp_host = dynamic_pointer_cast<VFSNetFTPHost>(Host());
    VFSStat stat;
    int stat_ret = ftp_host->Stat(RelativePath(), stat, 0, _cancel_checker);
    
    if( stat_ret == 0 &&
       ((stat.mode & S_IFMT) == S_IFREG) &&
       (_open_flags & VFSFile::OF_Read) != 0 &&
       (_open_flags & VFSFile::OF_Write) == 0 )
    {
        char request[MAXPATHLEN*2];
        ftp_host->BuildFullURL(RelativePath(), request);
        m_URLRequest = request;

        m_CURL  = ftp_host->InstanceForIO();
        m_CURLM = make_unique<CURLMInstance>();
        m_FileSize = stat.size;
        
        
        if(m_FileSize > 0)
        {
            if(ReadChunk(nullptr, 1, 0, _cancel_checker) == 1)
                return 0;
        }
        

//        curl_multi_perform
        return VFSError::GenericError;
    }
    return VFSError::NotSupported;
}

ssize_t VFSNetFTPFile::ReadChunk(
                                 void *_read_to,
                                 uint64_t _read_size,
                                 uint64_t _file_offset,
                                 bool (^_cancel_checker)()
                                 )
{
    // TODO: mutex lock
    bool error = false;
    
    if ((m_Buf->size < _read_size + _file_offset - m_Buf->file_offset) ||
        _file_offset < m_Buf->file_offset ||
        _file_offset > m_Buf->file_offset + m_Buf->size)
    {
        // can't satisfy request from memory buffer, need to perform I/O

        // check for big offset changes so we need to restart connection
        if(_file_offset < m_Buf->file_offset ||
           _file_offset > m_Buf->file_offset + m_Buf->size ||
           m_CURLM->RunningHandles() == 0)

        { // (re)connect
            m_Buf->clear();
            curl_multi_remove_handle(m_CURLM->curlm, m_CURL->curl);
            curl_easy_setopt(m_CURL->curl, CURLOPT_URL, m_URLRequest.c_str());
            curl_easy_setopt(m_CURL->curl, CURLOPT_WRITEFUNCTION, Buffer::write_here_function);
            curl_easy_setopt(m_CURL->curl, CURLOPT_WRITEDATA, m_Buf.get());
            curl_easy_setopt(m_CURL->curl, CURLOPT_LOW_SPEED_LIMIT, 1);
            curl_easy_setopt(m_CURL->curl, CURLOPT_LOW_SPEED_TIME, 60);
            
            // set offsets
            if (_file_offset) {
                char range[16];
                snprintf(range, 16, "%lld-", _file_offset);
                curl_easy_setopt(m_CURL->curl, CURLOPT_RANGE, range);
            }
        
            CURLMcode curlMCode =  curl_multi_add_handle(m_CURLM->curlm, m_CURL->curl);
            assert(curlMCode == CURLM_OK);
        }
    
        int running_handles = 0;
        
        while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(m_CURLM->curlm, &running_handles)); // ???

        curl_easy_setopt(m_CURL->curl, CURLOPT_RANGE, NULL);
        
        while( (m_Buf->size < _read_size + _file_offset - m_Buf->file_offset) && running_handles)
        {
            struct timeval timeout = {1, 0};
            
            fd_set fdread, fdwrite, fdexcep;
            int maxfd;
        
            FD_ZERO(&fdread);
            FD_ZERO(&fdwrite);
            FD_ZERO(&fdexcep);
            curl_multi_fdset(m_CURLM->curlm, &fdread, &fdwrite, &fdexcep, &maxfd);
        
            if (select(maxfd+1, &fdread, &fdwrite, &fdexcep, &timeout) == -1) {
                NSLog(@"!!");
                error = true;
                break;
            }
        
            while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(m_CURLM->curlm, &running_handles))
                if(_cancel_checker && _cancel_checker())
                    return VFSError::Cancelled;
        }
        
        // check for error codes here
        if (running_handles == 0) {
            int msgs_left = 1;
            while (msgs_left)
            {
                CURLMsg* msg = curl_multi_info_read(m_CURLM->curlm, &msgs_left);
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

    assert(m_Buf->file_offset >= _file_offset);
    size_t to_copy = m_Buf->size + m_Buf->file_offset - _file_offset;
    size_t size = _read_size > to_copy ? to_copy : _read_size;
  
    if(_read_to != nullptr)
    {
        memcpy(_read_to, m_Buf->buf + _file_offset - m_Buf->file_offset, size);
        m_Buf->discard( _file_offset - m_Buf->file_offset + size );
        m_Buf->file_offset = _file_offset + size;
    }
    
    return size;
}

ssize_t VFSNetFTPFile::Read(void *_buf, size_t _size)
{
    if(Eof())
        return 0;
    
    ssize_t ret = ReadChunk(_buf, _size, m_FilePos, 0);
    if(ret < 0)
        return ret;

    m_FilePos += ret;
    return ret;
}

VFSFile::ReadParadigm VFSNetFTPFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Sequential;
}

ssize_t VFSNetFTPFile::Pos() const
{
    return m_FilePos;
}

ssize_t VFSNetFTPFile::Size() const
{
    return m_FileSize;
}

bool VFSNetFTPFile::Eof() const
{
//    if(!m_Archive)
//        return true;
    return m_FilePos >= m_FileSize;
}


