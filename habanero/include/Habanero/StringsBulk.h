/* Copyright (c) 2017 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#pragma once

#include <stddef.h>
#include <stdlib.h>
#include <memory>
#include <string>
#include <experimental/string_view>
#include <vector>

namespace hbn {

class StringsBulk
{
public:
    class Iterator;
    class Builder;
    class NonOwningBuilder;
    
    StringsBulk() noexcept;
    StringsBulk(const StringsBulk&);
    StringsBulk(StringsBulk&&) noexcept;
    ~StringsBulk();
    
    StringsBulk &operator=(const StringsBulk& _rhs);
    StringsBulk &operator=(StringsBulk&& _rhs) noexcept;
    
    bool empty() const noexcept;
    size_t size() const noexcept;

    const char *at(size_t _index) const;
    const char *operator[](size_t _index) const;
    size_t string_length(size_t _index) const;
    const char *front() const noexcept;
    const char *back() const noexcept;    

    Iterator begin() const noexcept;
    Iterator end() const noexcept;
    
private:
    struct Ctrl;
    friend Iterator;
    friend Builder;
    friend NonOwningBuilder;
    
    StringsBulk(size_t _strings_amount, Ctrl *_data) noexcept;
    static Ctrl *Allocate( size_t _number_of_strings, size_t total_chars );
    
    size_t m_Count;
    Ctrl *m_Ctrl;
};
    
bool operator ==(const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept;
bool operator !=(const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept;
bool operator < (const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept;
bool operator <=(const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept;
bool operator > (const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept;
bool operator >=(const StringsBulk &_lhs, const StringsBulk& _rhs) noexcept;
    
class StringsBulk::Iterator
{
public:
    using difference_type = long;
    using reference = const char*;
    using value_type = const char*;
    
    Iterator() = default;
    Iterator(const Iterator&) = default;
    
    Iterator& operator=(const Iterator&) = default;
    Iterator &operator++() noexcept;
    Iterator operator++(int) noexcept;
    Iterator &operator--() noexcept;
    Iterator operator--(int) noexcept;
    Iterator &operator+=(long) noexcept;
    Iterator &operator-=(long) noexcept;
    long operator-(const Iterator&) noexcept;

    bool operator ==(const Iterator&) const noexcept;
    bool operator !=(const Iterator&) const noexcept;
    bool operator < (const Iterator&) const noexcept;
    bool operator <=(const Iterator&) const noexcept;
    bool operator > (const Iterator&) const noexcept;
    bool operator >=(const Iterator&) const noexcept;
    
    const char *operator*()const noexcept;
    const char *operator[](long _index)const noexcept;
    
    void swap(Iterator &_rhs) noexcept;
private:
    friend StringsBulk;
    size_t m_Index;
    const StringsBulk::Ctrl *m_Ctrl;
};
    
StringsBulk::Iterator operator+(StringsBulk::Iterator _i, long _n) noexcept;
StringsBulk::Iterator operator+(long _n, StringsBulk::Iterator _i) noexcept;
StringsBulk::Iterator operator-(StringsBulk::Iterator _i, long _n) noexcept;
    
class StringsBulk::Builder
{
public:
    ~Builder();

    size_t Size() const noexcept;
    bool Empty() const noexcept;
    void Add(std::string _s);
    StringsBulk Build() const;
    
private:
    size_t TotalBytesForChars() const noexcept;
    std::vector<std::string> m_Strings;
};
    
class StringsBulk::NonOwningBuilder
{
public:
    ~NonOwningBuilder();
    
    size_t Size() const noexcept;
    bool Empty() const noexcept;
    void Add(std::experimental::string_view _s);
    StringsBulk Build() const;
    
private:
    size_t TotalBytesForChars() const noexcept;
    std::vector<std::experimental::string_view> m_Strings;
};

}

namespace std {
    
template<>
inline void swap(hbn::StringsBulk::Iterator &_lhs, hbn::StringsBulk::Iterator &_rhs) noexcept
{
    _lhs.swap(_rhs);
}
    
}
