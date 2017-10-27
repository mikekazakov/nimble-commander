// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WriteBuffer.h"

namespace nc::vfs::webdav {

static const auto g_DefaultCapacity = 32768;

WriteBuffer::WriteBuffer()
{
}

WriteBuffer::~WriteBuffer()
{
    free(m_Bytes);
}

bool WriteBuffer::Empty() const noexcept
{
    return m_Size == 0;
}

size_t WriteBuffer::Size() const noexcept
{
    return m_Size;
}

void WriteBuffer::Grow(int _new_size) noexcept
{
    _new_size = max(_new_size, g_DefaultCapacity);
    assert( m_Size < _new_size );
    m_Capacity = _new_size;
    m_Bytes = (uint8_t*)realloc(m_Bytes, m_Capacity);
}

void WriteBuffer::PushBack(const void *_data, int _size) noexcept
{
    if( m_Capacity < m_Size + _size)
        Grow( m_Size + _size );
    
    memcpy( m_Bytes + m_Size, _data, _size);
    m_Size += _size;
}

void WriteBuffer::PopFront(int _size) noexcept
{
    if( _size == 0 )
        return;
    assert(_size  <= m_Size );
    memmove(m_Bytes, m_Bytes + _size, m_Size - _size);
    m_Size = m_Size - _size;
}

void WriteBuffer::Clear()
{
    m_Size = 0;
}

void WriteBuffer::Write(const void* _buffer, size_t _bytes) noexcept
{
    assert(_buffer != nullptr);
    PushBack(_buffer, (int)_bytes);
}

size_t WriteBuffer::Discard(size_t _bytes) noexcept
{
    const auto to_discard = min( size_t(m_Size), _bytes );
    PopFront((int)to_discard);
    return to_discard;
}

size_t WriteBuffer::Read(void *_ptr, size_t _size, size_t _nmemb, void *_userp)
{
    WriteBuffer &buffer = *(WriteBuffer*)_userp;

    const auto total_bytes = _size * _nmemb;
    const auto to_read = min( size_t(buffer.m_Size), total_bytes );
    if( to_read == 0 )
        return 0;
    
    memcpy( _ptr, buffer.m_Bytes, to_read );
    buffer.PopFront((int)to_read);
    
    return to_read;
}
    


}
