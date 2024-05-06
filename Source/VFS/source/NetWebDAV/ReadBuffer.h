// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stddef.h>
#include <stdint.h>
#include <string>

namespace nc::vfs::webdav {

class ReadBuffer
{
public:
    ReadBuffer();
    ~ReadBuffer();

    bool Empty() const noexcept;
    size_t Size() const noexcept;

    void Clear();
    size_t Read(void *_buffer, size_t _bytes) noexcept;
    std::string ReadAllAsString();
    size_t Discard(size_t _bytes) noexcept;
    static size_t Write(void *_buffer, size_t _size, size_t _nmemb, void *_userp);

private:
    ReadBuffer(const ReadBuffer &) = delete;
    void operator=(const ReadBuffer &) = delete;
    void Grow(int _new_size) noexcept;
    void PushBack(const void *_data, int _size) noexcept;
    void PopFront(int _size) noexcept;

    uint8_t *m_Bytes = nullptr;
    int m_Size = 0;
    int m_Capacity = 0;
};

} // namespace nc::vfs::webdav
