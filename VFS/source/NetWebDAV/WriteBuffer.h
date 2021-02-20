// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>
#include <stddef.h>

namespace nc::vfs::webdav {

class WriteBuffer
{
public:
    WriteBuffer();
    ~WriteBuffer();

    bool Empty() const noexcept;
    size_t Size() const noexcept;

    void Clear() noexcept;
    void Write(const void *_buffer, size_t _bytes) noexcept;
    size_t Discard(size_t _bytes) noexcept;
    size_t Read(void *_ptr, size_t _size_bytes) noexcept;
    static size_t ReadCURL(void *_ptr, size_t _elements, size_t _nmemb, void *_data) noexcept;

private:
    WriteBuffer(const WriteBuffer &) = delete;
    void operator=(const WriteBuffer &) = delete;
    void Grow(size_t _new_size) noexcept;
    void PushBack(const void *_data, size_t _size) noexcept;
    void PopFront(size_t _size) noexcept;

    uint8_t *m_Bytes = nullptr;
    size_t m_Size = 0;
    size_t m_Capacity = 0;
};

} // namespace nc::vfs::webdav
