// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/VFS/VFSGenericMemReadOnlyFile.h"

VFSGenericMemReadOnlyFile::VFSGenericMemReadOnlyFile(const char* _relative_path,
                                                     shared_ptr<VFSHost> _host,
                                                     const void *_memory,
                                                     uint64_t _mem_size):
    VFSFile(_relative_path, _host),
    m_Mem(_memory),
    m_Size(_mem_size)
{
}

ssize_t VFSGenericMemReadOnlyFile::Read(void *_buf, size_t _size)
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    
    if(_buf == 0)
        return VFSError::InvalidCall;
    
    if(_size == 0)
        return 0;
    
    // we can only deal with cache buffer now, need another branch later
    if(m_Pos == (long)m_Size)
        return 0;
    
    size_t to_read = MIN(m_Size - m_Pos, _size);
    memcpy(_buf, (char*)m_Mem + m_Pos, to_read);
    m_Pos += to_read;
    assert(m_Pos <= (long)m_Size); // just a sanity check
        
    return to_read;
}

ssize_t VFSGenericMemReadOnlyFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    
    // we can only deal with cache buffer now, need another branch later
    if(_pos < 0 || _pos > (long)m_Size)
        return VFSError::InvalidCall;
    
    ssize_t toread = MIN(m_Size - _pos, _size);
    memcpy(_buf, (char*)m_Mem + _pos, toread);
    return toread;
}

off_t VFSGenericMemReadOnlyFile::Seek(off_t _off, int _basis)
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    
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
    if(req_pos > (long)m_Size)
        req_pos = m_Size;
    m_Pos = req_pos;
    
    return m_Pos;
}

VFSFile::ReadParadigm VFSGenericMemReadOnlyFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Random;
}

ssize_t VFSGenericMemReadOnlyFile::Pos() const
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    return m_Pos;
}

ssize_t VFSGenericMemReadOnlyFile::Size() const
{
    return m_Size;    
}

bool VFSGenericMemReadOnlyFile::Eof() const
{
    if(!IsOpened())
        return true;
    return m_Pos == (long)m_Size;
}

int VFSGenericMemReadOnlyFile::Open(unsigned long _open_flags, const VFSCancelChecker &_cancel_checker)
{
    m_Opened = true;
    return 0;
}

bool VFSGenericMemReadOnlyFile::IsOpened() const
{
    return m_Opened;
}

int VFSGenericMemReadOnlyFile::Close()
{
    m_Opened = false;
    return 0;
}
