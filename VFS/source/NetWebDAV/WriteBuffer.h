// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
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

    void Clear();
    void Write(const void* _buffer, size_t _bytes) noexcept;
    size_t Discard(size_t _bytes) noexcept;
    static size_t Read(void *_ptr, size_t _size, size_t _nmemb, void *_data);

private:
    WriteBuffer(const WriteBuffer&) = delete;
    void operator=(const WriteBuffer&) = delete;
    void Grow(int _new_size) noexcept;
    void PushBack(const void *_data, int _size) noexcept;
    void PopFront(int _size) noexcept;
    
    uint8_t *m_Bytes = nullptr;
    int      m_Size = 0;
    int      m_Capacity = 0;

};

}
