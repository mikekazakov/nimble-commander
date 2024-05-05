// Copyright (C) 2017-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ReadBuffer.h"
#include <algorithm>
#include <cassert>
#include <cstdlib>

namespace nc::vfs::webdav {

static const auto g_DefaultCapacity = 32768;

ReadBuffer::ReadBuffer() = default;

ReadBuffer::~ReadBuffer()
{
    free(m_Bytes);
}

bool ReadBuffer::Empty() const noexcept
{
    return m_Size == 0;
}

size_t ReadBuffer::Size() const noexcept
{
    return m_Size;
}

void ReadBuffer::Grow(int _new_size) noexcept
{
    _new_size = std::max(_new_size, g_DefaultCapacity);
    assert(m_Size < _new_size);
    m_Capacity = _new_size;
    m_Bytes = static_cast<uint8_t *>(realloc(m_Bytes, m_Capacity));
}

void ReadBuffer::PushBack(const void *_data, int _size) noexcept
{
    if( m_Capacity < m_Size + _size )
        Grow(m_Size + _size);

    memcpy(m_Bytes + m_Size, _data, _size);
    m_Size += _size;
}

size_t ReadBuffer::Write(void *_buffer, size_t _size, size_t _nmemb, void *_userp)
{
    ReadBuffer &buffer = *static_cast<ReadBuffer *>(_userp);
    const auto total_bytes = _size * _nmemb;
    buffer.PushBack(_buffer, static_cast<int>(total_bytes));
    return total_bytes;
}

size_t ReadBuffer::Read(void *_buffer, size_t _bytes) noexcept
{
    const auto to_read = std::min(size_t(m_Size), _bytes);
    if( to_read == 0 )
        return 0;
    memcpy(_buffer, m_Bytes, to_read);
    PopFront(static_cast<int>(to_read));
    return to_read;
}

std::string ReadBuffer::ReadAllAsString()
{
    std::string output(reinterpret_cast<const char *>(m_Bytes), m_Size);
    Clear();
    return output;
}

void ReadBuffer::PopFront(int _size) noexcept
{
    assert(_size <= m_Size);
    std::memmove(m_Bytes, m_Bytes + _size, m_Size - _size);
    m_Size = m_Size - _size;
}

size_t ReadBuffer::Discard(size_t _bytes) noexcept
{
    const auto to_discard = std::min(size_t(m_Size), _bytes);
    PopFront(static_cast<int>(to_discard));
    return to_discard;
}

void ReadBuffer::Clear()
{
    m_Size = 0;
}
} // namespace nc::vfs::webdav
