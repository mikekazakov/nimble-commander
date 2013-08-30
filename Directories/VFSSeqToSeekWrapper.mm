//
//  VFSSeqToSeekWrapper.cpp
//  Files
//
//  Created by Michael G. Kazakov on 28.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFSSeqToSeekWrapper.h"
#import "VFSError.h"

VFSSeqToSeekROWrapperFile::VFSSeqToSeekROWrapperFile(std::shared_ptr<VFSFile> _file_to_wrap):
    VFSFile(_file_to_wrap->RelativePath(), _file_to_wrap->Host()),
    m_SeqFile(_file_to_wrap),
    m_Ready(false)
{
    
    
    
}

int VFSSeqToSeekROWrapperFile::Open(int _flags)
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
        m_DataBuf.resize(m_Size);
        
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
        assert(0);
    }
    
    return VFSError::Ok;
}

int VFSSeqToSeekROWrapperFile::Close()
{
    m_SeqFile.reset();
    m_DataBuf.clear();
    m_Ready = false;
    return VFSError::Ok;
}

VFSFile::ReadParadigm VFSSeqToSeekROWrapperFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Random;
}

ssize_t VFSSeqToSeekROWrapperFile::Pos() const
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    return m_Pos;
}

ssize_t VFSSeqToSeekROWrapperFile::Size() const
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    return m_Size;
}

bool VFSSeqToSeekROWrapperFile::Eof() const
{
    if(!IsOpened())
        return true;
    return m_Pos == m_Size;
}

bool VFSSeqToSeekROWrapperFile::IsOpened() const
{
    return m_Ready;
}

ssize_t VFSSeqToSeekROWrapperFile::Read(void *_buf, size_t _size)
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
    
    size_t to_read = MIN(m_Size - m_Pos, _size);
    memcpy(_buf, &m_DataBuf[m_Pos], to_read);
    m_Pos += to_read;
    assert(m_Pos <= m_Size);

    return to_read;
}

ssize_t VFSSeqToSeekROWrapperFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if(!IsOpened())
        return VFSError::InvalidCall;

    // we can only deal with cache buffer now, need another branch later
    if(_pos < 0 || _pos > m_Size)
        return VFSError::InvalidCall;
    
    ssize_t toread = MIN(m_Size - _pos, _size);
    memcpy(_buf, &m_DataBuf[_pos], toread);
    return toread;
}

off_t VFSSeqToSeekROWrapperFile::Seek(off_t _off, int _basis)
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
    
    return m_Pos;
}
