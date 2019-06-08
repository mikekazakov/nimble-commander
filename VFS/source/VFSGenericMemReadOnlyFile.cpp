// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "VFSGenericMemReadOnlyFile.h"
#include <algorithm>

namespace nc::vfs {

GenericMemReadOnlyFile::GenericMemReadOnlyFile(const char* _relative_path,
                                               const std::shared_ptr<VFSHost> &_host,
                                               const void *_memory,
                                               uint64_t _mem_size):
    VFSFile(_relative_path, _host),
    m_Mem(_memory),
    m_Size(_mem_size)
{
    if( m_Mem == nullptr )
        throw std::invalid_argument("GenericMemReadOnlyFile expects a valid memory pointer");
}
    
GenericMemReadOnlyFile::GenericMemReadOnlyFile(const char* _relative_path,
                                               const std::shared_ptr<VFSHost> &_host,
                                               std::string_view _memory):
    VFSFile(_relative_path, _host),
    m_Mem((const void *)_memory.data()),
    m_Size(_memory.size())
{
    if( m_Mem == nullptr )
        throw std::invalid_argument("GenericMemReadOnlyFile expects a valid memory pointer");
}

ssize_t GenericMemReadOnlyFile::Read(void *_buf, size_t _size)
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
    
    size_t to_read = std::min((size_t)(m_Size - m_Pos), _size);
    memcpy(_buf, (char*)m_Mem + m_Pos, to_read);
    m_Pos += to_read;
    assert(m_Pos <= (long)m_Size); // just a sanity check
        
    return to_read;
}

ssize_t GenericMemReadOnlyFile::ReadAt(off_t _pos, void *_buf, size_t _size)
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    
    // we can only deal with cache buffer now, need another branch later
    if(_pos < 0 || _pos > (long)m_Size)
        return VFSError::InvalidCall;
    
    ssize_t toread = std::min((size_t)(m_Size - _pos), _size);
    memcpy(_buf, (char*)m_Mem + _pos, toread);
    return toread;
}

off_t GenericMemReadOnlyFile::Seek(off_t _off, int _basis)
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

VFSFile::ReadParadigm GenericMemReadOnlyFile::GetReadParadigm() const
{
    return VFSFile::ReadParadigm::Random;
}

ssize_t GenericMemReadOnlyFile::Pos() const
{
    if(!IsOpened())
        return VFSError::InvalidCall;
    return m_Pos;
}

ssize_t GenericMemReadOnlyFile::Size() const
{
    return m_Size;    
}

bool GenericMemReadOnlyFile::Eof() const
{
    if(!IsOpened())
        return true;
    return m_Pos == (long)m_Size;
}

int GenericMemReadOnlyFile::Open([[maybe_unused]] unsigned long _open_flags,
                                 [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    m_Opened = true;
    return 0;
}

bool GenericMemReadOnlyFile::IsOpened() const
{
    return m_Opened;
}

int GenericMemReadOnlyFile::Close()
{
    m_Opened = false;
    return 0;
}

}
