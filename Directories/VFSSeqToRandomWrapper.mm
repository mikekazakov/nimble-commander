//
//  VFSSeqToSeekWrapper.cpp
//  Files
//
//  Created by Michael G. Kazakov on 28.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFSSeqToRandomWrapper.h"
#import "VFSError.h"

VFSSeqToRandomROWrapperFile::VFSSeqToRandomROWrapperFile(std::shared_ptr<VFSFile> _file_to_wrap):
    VFSFile(_file_to_wrap->RelativePath(), _file_to_wrap->Host()),
    m_SeqFile(_file_to_wrap),
    m_Ready(false),
    m_FD(-1),
    m_DataBuf(0)
{
}

VFSSeqToRandomROWrapperFile::~VFSSeqToRandomROWrapperFile()
{
    Close();
}

int VFSSeqToRandomROWrapperFile::Open(int _flags)
{
    if(m_SeqFile.get() == 0)
        return VFSError::InvalidCall;
    if(m_SeqFile->GetReadParadigm() < VFSFile::ReadParadigm::Sequential)
        return VFSError::InvalidCall;
    
    if(!m_SeqFile->IsOpened())
    {
        int res = m_SeqFile->Open(VFSFile::OF_Read);
        if(res < 0)
            return res;
    }
    else
    {
        if(m_SeqFile->Pos() > 0)
            return VFSError::InvalidCall;
    }
    
    if(m_SeqFile->Size() <= MaxCachedInMem)
    {
        // we just read a whole file into a memory buffer
        m_Pos = 0;
        m_Size = m_SeqFile->Size();
        if(m_DataBuf != 0)
            free(m_DataBuf);
        m_DataBuf = (uint8_t*)malloc(m_Size);
        
        uint8_t *d = &m_DataBuf[0];
        uint8_t *e = d + m_Size;
        ssize_t res;
        while( ( res = m_SeqFile->Read(d, e-d) ) > 0)
            d += res;
        
        if(res < 0)
            return (int)res;
        
        if(res == 0 && d != e)
            return VFSError::UnexpectedEOF;
        
        m_SeqFile.reset();
        m_Ready = true; // here we ready to go
    }
    else
    {
        // we need to write it into a temp dir and delete it upon finish
        NSString *temp_dir = NSTemporaryDirectory();
        assert(temp_dir);
        char pattern_buf[MAXPATHLEN];
        sprintf(pattern_buf, "%sinfo.filesmanager.vfs.XXXXXX", [temp_dir fileSystemRepresentation]);
        
        int fd = mkstemp(pattern_buf);
        
        if(fd < 0)
            return VFSError::FromErrno(errno);

        m_FD = fd;

        m_Size = m_SeqFile->Size();
        
        size_t bufsz = 256*1024;

        char buf[bufsz];
        uint64_t left_read = m_Size;
        ssize_t res_read;
        ssize_t total_wrote = 0 ;
        
        while ( (res_read = m_SeqFile->Read(buf, MIN(bufsz, left_read))) > 0 )
        {
            ssize_t res_write;
            while(res_read > 0)
            {
                res_write = write(m_FD, buf, res_read);
                if(res_write >= 0)
                {
                    res_read -= res_write;
                    total_wrote += res_write;
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

        unlink(pattern_buf); // preemtive unlink - OS will remove inode upon last descriptor closing
        
        m_SeqFile.reset();
        m_Ready = true; // here we ready to go
    }
    
    return VFSError::Ok;
}

int VFSSeqToRandomROWrapperFile::Close()
{
    m_SeqFile.reset();
    if(m_DataBuf)
    {
        free(m_DataBuf);
        m_DataBuf = 0;
    }
    if(m_FD >= 0)
    {
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
    
    if(m_DataBuf != 0)
    {
        size_t to_read = MIN(m_Size - m_Pos, _size);
        memcpy(_buf, &m_DataBuf[m_Pos], to_read);
        m_Pos += to_read;
        assert(m_Pos <= m_Size); // just a sanity check

        return to_read;
    }
    else if(m_FD >= 0)
    {
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
    
    if(m_DataBuf != 0)
    {
        ssize_t toread = MIN(m_Size - _pos, _size);
        memcpy(_buf, &m_DataBuf[_pos], toread);
        return toread;
    }
    else if(m_FD >= 0)
    {
//ssize_t pread(int fildes, void *buf, size_t nbyte, off_t offset);
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
