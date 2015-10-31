//
//  VFSSeqToSeekWrapper.cpp
//  Files
//
//  Created by Michael G. Kazakov on 28.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Habanero/algo.h>
#import "VFSSeqToRandomWrapper.h"
#import "VFSError.h"
#import "Common.h"

VFSSeqToRandomROWrapperFile::VFSSeqToRandomROWrapperFile(const VFSFilePtr &_file_to_wrap):
    VFSFile(_file_to_wrap->RelativePath(), _file_to_wrap->Host()),
    m_SeqFile(_file_to_wrap)
{
}

VFSSeqToRandomROWrapperFile::~VFSSeqToRandomROWrapperFile()
{
    Close();
}

int VFSSeqToRandomROWrapperFile::Open(int _flags,
                                      VFSCancelChecker _cancel_checker,
                                      function<void(uint64_t _bytes_proc, uint64_t _bytes_total)> _progress)
{
    auto ggg = at_scope_end( [=]{ m_SeqFile.reset(); } ); // ony any result wrapper won't hold any reference to VFSFile after this function ends
    if(!m_SeqFile)
        return VFSError::InvalidCall;
    if(m_SeqFile->GetReadParadigm() < VFSFile::ReadParadigm::Sequential)
        return VFSError::InvalidCall;
    
    if(!m_SeqFile->IsOpened()) {
        int res = m_SeqFile->Open(_flags);
        if(res < 0)
            return res;
    }
    else if(m_SeqFile->Pos() > 0)
        return VFSError::InvalidCall;
    
    if(m_SeqFile->Size() <= MaxCachedInMem) {
        // we just read a whole file into a memory buffer
        m_Pos = 0;
        m_Size = m_SeqFile->Size();
        m_DataBuf = make_unique<uint8_t[]>(m_Size);
        
        const size_t max_io = 256*1024;
        uint8_t *d = &m_DataBuf[0];
        uint8_t *e = d + m_Size;
        ssize_t res;
        while( ( res = m_SeqFile->Read(d, MIN(e-d, max_io)) ) > 0) {
            d += res;

            if(_cancel_checker && _cancel_checker())
                return VFSError::Cancelled;

            if(_progress)
                _progress(d - &m_DataBuf[0], m_Size);
        }
        
        if(_cancel_checker && _cancel_checker())
            return VFSError::Cancelled;
        
        if(res < 0)
            return (int)res;
        
        if(res == 0 && d != e)
            return VFSError::UnexpectedEOF;
        
        m_Ready = true; // here we ready to go
    }
    else {
        // we need to write it into a temp dir and delete it upon finish
        char pattern_buf[MAXPATHLEN];
        sprintf(pattern_buf, "%s" __FILES_IDENTIFIER__ ".vfs.XXXXXX", AppTemporaryDirectory().c_str());
        
        int fd = mkstemp(pattern_buf);
        
        if(fd < 0)
            return VFSError::FromErrno(errno);

        unlink(pattern_buf); // preemtive unlink - OS will remove inode upon last descriptor closing
        
        fcntl(fd, F_NOCACHE, 1); // don't need to cache this temporaral stuff
        
        m_FD = fd;

        m_Size = m_SeqFile->Size();
        
        size_t bufsz = 256*1024;

        char buf[bufsz];
        uint64_t left_read = m_Size;
        ssize_t res_read;
        ssize_t total_wrote = 0 ;
        
        while ( (res_read = m_SeqFile->Read(buf, MIN(bufsz, left_read))) > 0 ) {
            if(_cancel_checker && _cancel_checker())
                return VFSError::Cancelled;
            
            ssize_t res_write;
            while(res_read > 0) {
                res_write = write(m_FD, buf, res_read);
                if(res_write >= 0) {
                    res_read -= res_write;
                    total_wrote += res_write;
                    
                    if(_progress)
                        _progress(total_wrote, m_Size);
                }
                else
                    return VFSError::FromErrno(errno);
            }
        }
        
        if(res_read < 0)
            return (int)res_read;
        
        if(res_read == 0 && total_wrote != m_Size)
            return VFSError::UnexpectedEOF;
        
        lseek(m_FD, 0, SEEK_SET);
        
        m_Ready = true; // here we ready to go
    }
    
    return VFSError::Ok;
}

int VFSSeqToRandomROWrapperFile::Open(int _flags, VFSCancelChecker _cancel_checker)
{
    return Open(_flags, _cancel_checker, nil);
}

int VFSSeqToRandomROWrapperFile::Close()
{
    m_SeqFile.reset();
    m_DataBuf.reset();
    if(m_FD >= 0) {
        close(m_FD);
        m_FD = -1;
    }
    m_Ready = false;
    return VFSError::Ok;
}

VFSFile::ReadParadigm VFSSeqToRandomROWrapperFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Random;
}

ssize_t VFSSeqToRandomROWrapperFile::Pos() const
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    return m_Pos;
}

ssize_t VFSSeqToRandomROWrapperFile::Size() const
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    return m_Size;
}

bool VFSSeqToRandomROWrapperFile::Eof() const
{
    if(!IsOpened())
        return true;
    return m_Pos == m_Size;
}

bool VFSSeqToRandomROWrapperFile::IsOpened() const
{
    return m_Ready;
}

ssize_t VFSSeqToRandomROWrapperFile::Read(void *_buf, size_t _size)
{
    if(!IsOpened())
        return VFSError::InvalidCall;

    if(_buf == 0)
        return VFSError::InvalidCall;

    if(_size == 0)
        return 0;
    
    // we can only deal with cache buffer now, need another branch later
    if(m_Pos == m_Size)
        return 0;
    
    if(m_DataBuf) {
        size_t to_read = MIN(m_Size - m_Pos, _size);
        memcpy(_buf, &m_DataBuf[m_Pos], to_read);
        m_Pos += to_read;
        assert(m_Pos <= m_Size); // just a sanity check

        return to_read;
    }
    else if(m_FD >= 0) {
        size_t to_read = MIN(m_Size - m_Pos, _size);
        ssize_t res = read(m_FD, _buf, to_read);
        
        if(res < 0)
            return VFSError::FromErrno(errno);
        
        m_Pos += res;
        return res;
    }
    assert(0);
    return VFSError::GenericError;
}

ssize_t VFSSeqToRandomROWrapperFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if(!IsOpened())
        return VFSError::InvalidCall;

    // we can only deal with cache buffer now, need another branch later
    if(_pos < 0 || _pos > m_Size)
        return VFSError::InvalidCall;
    
    if(m_DataBuf) {
        ssize_t toread = MIN(m_Size - _pos, _size);
        memcpy(_buf, &m_DataBuf[_pos], toread);
        return toread;
    }
    else if(m_FD >= 0) {
        ssize_t toread = MIN(m_Size - _pos, _size);
        ssize_t res = pread(m_FD, _buf, toread, _pos);
        if(res >= 0)
            return res;
        else
            return VFSError::FromErrno(errno);
    }
    assert(0);
}

off_t VFSSeqToRandomROWrapperFile::Seek(off_t _off, int _basis)
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    
    // we can only deal with cache buffer now, need another branch later
    off_t req_pos = 0;
    if(_basis == VFSFile::Seek_Set)
        req_pos = _off;
    else if(_basis == VFSFile::Seek_End)
        req_pos = m_Size + _off;
    else if(_basis == VFSFile::Seek_Cur)
        req_pos = m_Pos + _off;
    else
        return VFSError::InvalidCall;
    
    if(req_pos < 0)
        return VFSError::InvalidCall;
    if(req_pos > m_Size)
        req_pos = m_Size;
    m_Pos = req_pos;
    
    if(m_FD >= 0)
        lseek(m_FD, m_Pos, SEEK_SET); // any error-handling here?
    
    return m_Pos;
}
