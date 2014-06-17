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
#import "VFSNetFTPCache.h"
#import "path_manip.h"

// implementation highly inspired by curlftpfs.

//CURLOPT_VERBOSE
#if 0

static int ftpfs_write(const char *path, const char *wbuf, size_t size,
                       off_t offset, struct fuse_file_info *fi) {
    (void) path;
    struct ftpfs_file *fh = get_ftpfs_file(fi);
    
    DEBUG(1, "ftpfs_write: %s size=%zu offset=%lld has_write_conn=%d pos=%lld\n", path, size, (long long) offset, fh->write_conn!=0, fh->pos);
    
    if (fh->write_fail_cause != CURLE_OK)
    {
        DEBUG(1, "previous write failed. cause=%d\n", fh->write_fail_cause);
        return -EIO;
    }
    
    if (!fh->write_conn && fh->pos == 0 && offset == 0)
    {
        DEBUG(1, "ftpfs_write: starting a streaming write at pos=%lld\n", fh->pos);
        
        /* check if the file has been truncated to zero or has been newly created */
        if (!fh->write_may_start)
        {
            long long size = (long long int)test_size(path);
            if (size != 0)
            {
                fprintf(stderr, "ftpfs_write: start writing with no previous truncate not allowed! size check rval=%lld\n", size);
                return op_return(-EIO, "ftpfs_write");
            }
        }
        
        int success = start_write_thread(fh);
        if (!success)
        {
            return op_return(-EIO, "ftpfs_write");
        }
        sem_wait(&fh->ready);
        sem_post(&fh->data_need);
    }
    
    if (!fh->write_conn && fh->pos >0 && offset == fh->pos)
    {
        /* resume a streaming write */
        DEBUG(1, "ftpfs_write: resuming a streaming write at pos=%lld\n", fh->pos);
        
        int success = start_write_thread(fh);
        if (!success)
        {
            return op_return(-EIO, "ftpfs_write");
        }
        sem_wait(&fh->ready);
        sem_post(&fh->data_need);
    }
    
    if (fh->write_conn) {
        sem_wait(&fh->data_need);
        
        if (offset != fh->pos) {
            DEBUG(1, "non-sequential write detected -> fail\n");
            
            sem_post(&fh->data_avail);
            finish_write_thread(fh);
            return op_return(-EIO, "ftpfs_write");
            
            
        } else {
            if (buf_add_mem(&fh->stream_buf, wbuf, size) == -1) {
                sem_post(&fh->data_need);
                return op_return(-ENOMEM, "ftpfs_write");
            }
            fh->pos += size;
            /* wake up write_data_bg */
            sem_post(&fh->data_avail);
            /* wait until libcurl has completely written the current chunk or finished/failed */
            sem_wait(&fh->data_written);
            fh->written_flag = 0;
            
            if (fh->write_fail_cause != CURLE_OK)
            {
                /* TODO: on error we should problably unlink the target file  */ 
                DEBUG(1, "writing failed. cause=%d\n", fh->write_fail_cause);
                return op_return(-EIO, "ftpfs_write");
            }    
        }
    }
    return size;
}

static size_t write_data_bg(void *ptr, size_t size, size_t nmemb, void *data) {
  struct ftpfs_file *fh = data;
  unsigned to_copy = size * nmemb;

  if (!fh->isready) {
    sem_post(&fh->ready);
    fh->isready = 1;
  }

  if (fh->stream_buf.len == 0 && fh->written_flag) {
    sem_post(&fh->data_written); /* ftpfs_write can return */
  }
  
  sem_wait(&fh->data_avail); 
  
  DEBUG(2, "write_data_bg: data_avail eof=%d\n", fh->eof);
  
  if (fh->eof)
    return 0;

  DEBUG(2, "write_data_bg: %d %zd\n", to_copy, fh->stream_buf.len);
  if (to_copy > fh->stream_buf.len)
    to_copy = fh->stream_buf.len;

  memcpy(ptr, fh->stream_buf.p, to_copy);
  if (fh->stream_buf.len > to_copy) {
    size_t newlen = fh->stream_buf.len - to_copy;
    memmove(fh->stream_buf.p, fh->stream_buf.p + to_copy, newlen);
    fh->stream_buf.len = newlen;
    sem_post(&fh->data_avail);
    DEBUG(2, "write_data_bg: data_avail\n");    
    
  } else {
    fh->stream_buf.len = 0;
    fh->written_flag = 1;
    sem_post(&fh->data_need);
    DEBUG(2, "write_data_bg: data_need\n");
  }

  return to_copy;
}

static void *ftpfs_write_thread(void *data) {
  struct ftpfs_file *fh = data;
  char range[15];
  
  DEBUG(2, "enter streaming write thread #%d path=%s pos=%lld\n", ++write_thread_ctr, fh->full_path, fh->pos);
  
  
  curl_easy_setopt_or_die(fh->write_conn, CURLOPT_URL, fh->full_path);
  curl_easy_setopt_or_die(fh->write_conn, CURLOPT_UPLOAD, 1);
  curl_easy_setopt_or_die(fh->write_conn, CURLOPT_INFILESIZE, -1);
  curl_easy_setopt_or_die(fh->write_conn, CURLOPT_READFUNCTION, write_data_bg);
  curl_easy_setopt_or_die(fh->write_conn, CURLOPT_READDATA, fh);
  curl_easy_setopt_or_die(fh->write_conn, CURLOPT_LOW_SPEED_LIMIT, 1);
  curl_easy_setopt_or_die(fh->write_conn, CURLOPT_LOW_SPEED_TIME, 60);
  
  fh->curl_error_buffer[0] = '\0';
  curl_easy_setopt_or_die(fh->write_conn, CURLOPT_ERRORBUFFER, fh->curl_error_buffer);

  if (fh->pos > 0) {
    /* resuming a streaming write */
    //snprintf(range, 15, "%lld-", (long long) fh->pos);
    //curl_easy_setopt_or_die(fh->write_conn, CURLOPT_RANGE, range);
	  
	curl_easy_setopt_or_die(fh->write_conn, CURLOPT_APPEND, 1);
	  
	//curl_easy_setopt_or_die(fh->write_conn, CURLOPT_RESUME_FROM_LARGE, (curl_off_t)fh->pos);
  }   
  
  CURLcode curl_res = curl_easy_perform(fh->write_conn);
  
  curl_easy_setopt_or_die(fh->write_conn, CURLOPT_UPLOAD, 0);

  if (!fh->isready)
    sem_post(&fh->ready);

  if (curl_res != CURLE_OK)
  {  
	  DEBUG(1, "write problem: %d(%s) text=%s\n", curl_res, curl_easy_strerror(curl_res), fh->curl_error_buffer);
	  fh->write_fail_cause = curl_res;
	  /* problem - let ftpfs_write continue to avoid hang */ 
	  sem_post(&fh->data_need);
  }
  
  DEBUG(2, "leaving streaming write thread #%d curl_res=%d\n", write_thread_ctr--, curl_res);
  
  sem_post(&fh->data_written); /* ftpfs_write may return */

  return NULL;
}

static int start_write_thread(struct ftpfs_file *fh)
{
	if (fh->write_conn != NULL)
	{
		fprintf(stderr, "assert fh->write_conn == NULL failed!\n");
		exit(1);
	}
	
	fh->written_flag=0;
	fh->isready=0;
	fh->eof=0;
	sem_init(&fh->data_avail, 0, 0);
	sem_init(&fh->data_need, 0, 0);
	sem_init(&fh->data_written, 0, 0);
	sem_init(&fh->ready, 0, 0);	
	
    fh->write_conn = curl_easy_init();
    if (fh->write_conn == NULL) {
      fprintf(stderr, "Error initializing libcurl\n");
      return 0;
    } else {
      int err;
      set_common_curl_stuff(fh->write_conn);
      err = pthread_create(&fh->thread_id, NULL, ftpfs_write_thread, fh);
      if (err) {
        fprintf(stderr, "failed to create thread: %s\n", strerror(err));
        /* FIXME: destroy curl_easy */
        return 0;	
      }
    }
	return 1;
}

static int finish_write_thread(struct ftpfs_file *fh)
{
    if (fh->write_fail_cause == CURLE_OK)
    {
      sem_wait(&fh->data_need);  /* only wait when there has been no error */
    }
    sem_post(&fh->data_avail);
    fh->eof = 1;
    
    pthread_join(fh->thread_id, NULL);
    DEBUG(2, "finish_write_thread after pthread_join. write_fail_cause=%d\n", fh->write_fail_cause);

    curl_easy_cleanup(fh->write_conn);    
    fh->write_conn = NULL;
    
    sem_destroy(&fh->data_avail);
    sem_destroy(&fh->data_need);
    sem_destroy(&fh->data_written);
    sem_destroy(&fh->ready);    
    
    if (fh->write_fail_cause != CURLE_OK)
    {
      return -EIO;
    }	
    return 0;
}

static int buffer_file(struct ftpfs_file *fh) {
  // If we want to write to the file, we have to load it all at once,
  // modify it in memory and then upload it as a whole as most FTP servers
  // don't support resume for uploads.
  pthread_mutex_lock(&ftpfs.lock);
  cancel_previous_multi();
  curl_easy_setopt_or_die(ftpfs.connection, CURLOPT_URL, fh->full_path);
  curl_easy_setopt_or_die(ftpfs.connection, CURLOPT_WRITEDATA, &fh->buf);
  CURLcode curl_res = curl_easy_perform(ftpfs.connection);
  pthread_mutex_unlock(&ftpfs.lock);

  if (curl_res != 0) {
    return -EACCES;
  }

  return 0;
}

#endif

using namespace VFSNetFTP;

VFSNetFTPFile::VFSNetFTPFile(const char* _relative_path,
                             shared_ptr<VFSNetFTPHost> _host):
    VFSFile(_relative_path, _host),
    m_Buf(make_unique<Buffer>()),
    m_WriteBuf(make_unique<WriteBuffer>())
{
}

VFSNetFTPFile::~VFSNetFTPFile()
{
    Close();
}

bool VFSNetFTPFile::IsOpened() const
{
    return m_Mode != Mode::Closed;
}

int VFSNetFTPFile::Close()
{
    if(m_CURL && m_Mode == Mode::Write)
    {
        // if we're still writing - finish it and tell cache about changes
        FinishWriting();
        dynamic_pointer_cast<VFSNetFTPHost>(Host())->Cache().CommitNewFile(RelativePath());
    }
    if(m_CURL && m_Mode == Mode::Read)
    {
        // if we're still reading something - cancel it and wait
        FinishReading();
    }
    
    if(m_CURL)
    {
        auto host = dynamic_pointer_cast<VFSNetFTPHost>(Host());
        host->CommitIOInstanceAtDir(DirName().c_str(), move(m_CURL));
    }

    m_FilePos = 0;
    m_FileSize = 0;
    m_Mode = Mode::Closed;
    m_Buf->clear();
    m_BufFileOffset = 0;
    m_CURL.reset();
    m_URLRequest.clear();
    return 0;
}

path VFSNetFTPFile::DirName() const
{
    return path(RelativePath()).parent_path();
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
        m_URLRequest = ftp_host->BuildFullURLString(RelativePath());
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
            (!(_open_flags & OF_NoExist) || stat_ret != 0) &&
            (_open_flags & VFSFile::OF_Read)  == 0 &&
            (_open_flags & VFSFile::OF_Write) != 0 )
    {
//        if()
/*
        manual truncate:
        pthread_mutex_lock(&ftpfs.lock);
        cancel_previous_multi();
        curl_easy_setopt_or_die(ftpfs.connection, CURLOPT_URL, full_path);
        curl_easy_setopt_or_die(ftpfs.connection, CURLOPT_INFILESIZE, 0);
        curl_easy_setopt_or_die(ftpfs.connection, CURLOPT_UPLOAD, 1);
        curl_easy_setopt_or_die(ftpfs.connection, CURLOPT_READDATA, NULL);
        CURLcode curl_res = curl_easy_perform(ftpfs.connection);
        curl_easy_setopt_or_die(ftpfs.connection, CURLOPT_UPLOAD, 0);
        pthread_mutex_unlock(&ftpfs.lock);
        */
        
        
        m_URLRequest = ftp_host->BuildFullURLString(RelativePath());
        
        m_CURL  = ftp_host->InstanceForIOAtDir(DirName().c_str());
        curl_multi_remove_handle(m_CURL->curlm, m_CURL->curl);        
        m_CURL->EasySetOpt(CURLOPT_URL, m_URLRequest.c_str());
        m_CURL->EasySetOpt(CURLOPT_UPLOAD, 1);
        m_CURL->EasySetOpt(CURLOPT_INFILESIZE, -1);
        m_CURL->EasySetOpt(CURLOPT_READFUNCTION, WriteBuffer::read_from_function);
        m_CURL->EasySetOpt(CURLOPT_READDATA, m_WriteBuf.get());

        m_FilePos = 0;
        m_FileSize = 0;
        if(_open_flags & VFSFile::OF_Append)
        {
            curl_easy_setopt(m_CURL->curl, CURLOPT_APPEND, 1);
  
            if(stat_ret == 0)
            {
                m_FilePos = stat.size;
                m_FileSize = stat.size;
            }
        }

        curl_multi_add_handle(m_CURL->curlm, m_CURL->curl);
        
        m_Mode = Mode::Write;
        return 0;
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
    
    if ( (m_Buf->size < _read_size + _file_offset - m_BufFileOffset ||
          _file_offset < m_BufFileOffset ||
          _file_offset > m_BufFileOffset + m_Buf->size) &&
         (m_Buf->size < m_FileSize)
        )
    {
        // can't satisfy request from memory buffer, need to perform I/O

        // check for dead connection
        // check for big offset changes so we need to restart connection
        if(_file_offset < m_BufFileOffset ||
           _file_offset > m_BufFileOffset + m_Buf->size ||
           m_CURL->RunningHandles() == 0)
        { // (re)connect
            
            // create a brand new ftp request (possibly reusing exiting network connection)
            m_Buf->clear();
            m_BufFileOffset = _file_offset;
            
            curl_multi_remove_handle(m_CURL->curlm, m_CURL->curl);
            curl_easy_setopt(m_CURL->curl, CURLOPT_URL, m_URLRequest.c_str());
            curl_easy_setopt(m_CURL->curl, CURLOPT_WRITEFUNCTION, Buffer::write_here_function);
            curl_easy_setopt(m_CURL->curl, CURLOPT_WRITEDATA, m_Buf.get());
            curl_easy_setopt(m_CURL->curl, CURLOPT_UPLOAD, 0);
            curl_easy_setopt(m_CURL->curl, CURLOPT_INFILESIZE, -1);
            curl_easy_setopt(m_CURL->curl, CURLOPT_READFUNCTION, 0);
            curl_easy_setopt(m_CURL->curl, CURLOPT_READDATA, 0);
            curl_easy_setopt(m_CURL->curl, CURLOPT_LOW_SPEED_LIMIT, 1);
            curl_easy_setopt(m_CURL->curl, CURLOPT_LOW_SPEED_TIME, 60);
            m_CURL->EasySetupProgFunc();
            
            // set offsets
            if (_file_offset) {
                char range[16];
                snprintf(range, 16, "%lld-", _file_offset);
                curl_easy_setopt(m_CURL->curl, CURLOPT_RANGE, range);
            }

            CURLMcode curlMCode =  curl_multi_add_handle(m_CURL->curlm, m_CURL->curl);
            assert(curlMCode == CURLM_OK);
        }
    
        int running_handles = 0;
        
        while(CURLM_CALL_MULTI_PERFORM == curl_multi_perform(m_CURL->curlm, &running_handles));

        curl_easy_setopt(m_CURL->curl, CURLOPT_RANGE, NULL);
        
        while( (m_Buf->size < _read_size + _file_offset - m_BufFileOffset) && running_handles)
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
    size_t to_copy = m_Buf->size + m_BufFileOffset - _file_offset;
    size_t size = _read_size > to_copy ? to_copy : _read_size;
  
    if(_read_to != nullptr)
    {
        memcpy(_read_to, m_Buf->buf + _file_offset - m_BufFileOffset, size);
        m_Buf->discard( _file_offset - m_BufFileOffset + size );
        m_BufFileOffset = _file_offset + size;
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

ssize_t VFSNetFTPFile::Write(const void *_buf, size_t _size)
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

VFSFile::ReadParadigm VFSNetFTPFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Seek;
}

VFSFile::WriteParadigm VFSNetFTPFile::GetWriteParadigm() const
{
    return VFSFile::WriteParadigm::Sequential;
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
    if(!IsOpened())
        return true;
    return m_FilePos >= m_FileSize;
}

off_t VFSNetFTPFile::Seek(off_t _off, int _basis)
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
    if(req_pos > m_FileSize)
        req_pos = m_FileSize;

    m_FilePos = req_pos;
    
    return m_FilePos;
}

void VFSNetFTPFile::FinishWriting()
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

void VFSNetFTPFile::FinishReading()
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
