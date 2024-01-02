// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stddef.h>
#include <stdlib.h>
#include <memory>
#include <string>
#include <string_view>
#include <vector>

namespace nc::base {

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
    size_t Size() const noexcept;
    bool Empty() const noexcept;
    void Add(std::string_view _s);
    StringsBulk Build() const;
    
private:
    size_t TotalBytesForChars() const noexcept;
    std::vector<std::string_view> m_Strings;
};

}

namespace std {
    
template<>
inline void swap(nc::base::StringsBulk::Iterator &_lhs,
                 nc::base::StringsBulk::Iterator &_rhs) noexcept
{
    _lhs.swap(_rhs);
}
    
}
