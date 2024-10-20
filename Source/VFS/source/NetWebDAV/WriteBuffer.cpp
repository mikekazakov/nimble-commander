// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WriteBuffer.h"
#include <cstdlib>
#include <algorithm>
#include <cassert>

namespace nc::vfs::webdav {

static const size_t g_DefaultCapacity = 32768;

WriteBuffer::WriteBuffer() = default;

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

void WriteBuffer::Grow(size_t _new_size) noexcept
{
    _new_size = std::max(_new_size, g_DefaultCapacity);
    assert(m_Size < _new_size);
    m_Capacity = _new_size;
    m_Bytes = static_cast<uint8_t *>(std::realloc(m_Bytes, m_Capacity));
}

void WriteBuffer::PushBack(const void *_data, size_t _size) noexcept
{
    if( m_Capacity < m_Size + _size )
        Grow(m_Size + _size);

    std::memcpy(m_Bytes + m_Size, _data, _size);
    m_Size += _size;
}

void WriteBuffer::PopFront(size_t _size) noexcept
{
    if( _size == 0 )
        return;
    assert(_size <= m_Size);
    std::memmove(m_Bytes, m_Bytes + _size, m_Size - _size);
    m_Size = m_Size - _size;
}

void WriteBuffer::Clear() noexcept
{
    m_Size = 0;
}

void WriteBuffer::Write(const void *_buffer, size_t _bytes) noexcept
{
    assert(_buffer != nullptr);
    PushBack(_buffer, static_cast<int>(_bytes));
}

size_t WriteBuffer::Discard(size_t _bytes) noexcept
{
    const auto to_discard = std::min(size_t(m_Size), _bytes);
    PopFront(static_cast<int>(to_discard));
    return to_discard;
}

size_t WriteBuffer::ReadCURL(void *_ptr, size_t _elements, size_t _nmemb, void *_data) noexcept
{
    WriteBuffer &buffer = *static_cast<WriteBuffer *>(_data);

    const auto total_bytes = _elements * _nmemb;

    return buffer.Read(_ptr, total_bytes);
}

size_t WriteBuffer::Read(void *_ptr, size_t _size_bytes) noexcept
{
    const auto to_read = std::min(size_t(m_Size), _size_bytes);
    if( to_read == 0 )
        return 0;

    std::memcpy(_ptr, m_Bytes, to_read);
    PopFront(static_cast<int>(to_read));

    return to_read;
}

} // namespace nc::vfs::webdav
