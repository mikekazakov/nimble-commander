// Copyright (C) 2020-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once 

#include <string_view>
#include <string>
#include <stdexcept>
#include <cstdint>

namespace nc::base {

template <size_t Size>
class StringViewZBuf
{
public:
    StringViewZBuf(std::string_view string);
    ~StringViewZBuf();
    const char *c_str() const noexcept;
    bool empty() const noexcept;

private:
    StringViewZBuf(const StringViewZBuf &) = delete;
    StringViewZBuf &operator=(const StringViewZBuf &) = delete;

    const char *m_DynamicBuffer;
    char m_FixedBuffer[Size];
};

template <size_t Size>
StringViewZBuf<Size>::StringViewZBuf(std::string_view string)
{
    static_assert(Size > 0);
    const size_t size = string.length();
    if( size + 1 <= Size ) {
        m_DynamicBuffer = nullptr;
        memcpy(m_FixedBuffer, string.data(), size);
        m_FixedBuffer[size] = 0;
    }
    else {
        char *const buffer = static_cast<char *>(malloc(size + 1));
        if( buffer == nullptr ) {
            throw std::bad_alloc();
        }
        memcpy(buffer, string.data(), size);
        buffer[size] = 0;
        m_DynamicBuffer = buffer;
    }
}

template <size_t Size>
StringViewZBuf<Size>::~StringViewZBuf()
{
    if( m_DynamicBuffer != nullptr ) {
        free(reinterpret_cast<void *>(const_cast<char *>(m_DynamicBuffer)));
    }
}

template <size_t Size>
const char *StringViewZBuf<Size>::c_str() const noexcept
{
    if( m_DynamicBuffer != nullptr ) {
        return m_DynamicBuffer;
    }
    else {
        return &m_FixedBuffer[0];
    }
}

template <size_t Size>
bool StringViewZBuf<Size>::empty() const noexcept
{
    return c_str()[0] == 0;
}

} // namespace nc::base
