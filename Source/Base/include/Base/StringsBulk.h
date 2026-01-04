// Copyright (C) 2017-2026 Michael Kazakov. Subject to GNU General Public License version 3.
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
    StringsBulk(const StringsBulk & /*_rhs*/);
    StringsBulk(StringsBulk && /*_rhs*/) noexcept;
    ~StringsBulk();

    StringsBulk &operator=(const StringsBulk &_rhs);
    StringsBulk &operator=(StringsBulk &&_rhs) noexcept;

    [[nodiscard]] bool empty() const noexcept;
    [[nodiscard]] size_t size() const noexcept;

    [[nodiscard]] const char *at(size_t _index) const;
    const char *operator[](size_t _index) const;
    [[nodiscard]] size_t string_length(size_t _index) const;
    [[nodiscard]] const char *front() const noexcept;
    [[nodiscard]] const char *back() const noexcept;

    [[nodiscard]] Iterator begin() const noexcept;
    [[nodiscard]] Iterator end() const noexcept;

private:
    struct Ctrl;
    friend Iterator;
    friend Builder;
    friend NonOwningBuilder;

    StringsBulk(size_t _strings_amount, Ctrl *_data) noexcept;
    static Ctrl *Allocate(size_t _number_of_strings, size_t total_chars);

    size_t m_Count;
    Ctrl *m_Ctrl;
};

bool operator==(const StringsBulk &_lhs, const StringsBulk &_rhs) noexcept;
bool operator!=(const StringsBulk &_lhs, const StringsBulk &_rhs) noexcept;
bool operator<(const StringsBulk &_lhs, const StringsBulk &_rhs) noexcept;
bool operator<=(const StringsBulk &_lhs, const StringsBulk &_rhs) noexcept;
bool operator>(const StringsBulk &_lhs, const StringsBulk &_rhs) noexcept;
bool operator>=(const StringsBulk &_lhs, const StringsBulk &_rhs) noexcept;

class StringsBulk::Iterator
{
public:
    using difference_type = long;
    using reference = const char *;
    using value_type = const char *;

    Iterator() = default;
    Iterator(const Iterator &) = default;

    Iterator &operator=(const Iterator &) = default;
    Iterator &operator++() noexcept;
    Iterator operator++(int) noexcept;
    Iterator &operator--() noexcept;
    Iterator operator--(int) noexcept;
    Iterator &operator+=(long /*_d*/) noexcept;
    Iterator &operator-=(long /*_d*/) noexcept;
    long operator-(const Iterator & /*_rhs*/) const noexcept;

    bool operator==(const Iterator & /*_rhs*/) const noexcept;
    bool operator!=(const Iterator & /*_rhs*/) const noexcept;
    bool operator<(const Iterator & /*_rhs*/) const noexcept;
    bool operator<=(const Iterator & /*_rhs*/) const noexcept;
    bool operator>(const Iterator & /*_rhs*/) const noexcept;
    bool operator>=(const Iterator & /*_rhs*/) const noexcept;

    const char *operator*() const noexcept;
    const char *operator[](long _index) const noexcept;

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
    [[nodiscard]] size_t Size() const noexcept;
    [[nodiscard]] bool Empty() const noexcept;
    void Add(std::string _s);
    [[nodiscard]] StringsBulk Build() const;

private:
    [[nodiscard]] size_t TotalBytesForChars() const noexcept;
    std::vector<std::string> m_Strings;
};

class StringsBulk::NonOwningBuilder
{
public:
    [[nodiscard]] size_t Size() const noexcept;
    [[nodiscard]] bool Empty() const noexcept;
    void Add(std::string_view _s);
    [[nodiscard]] StringsBulk Build() const;

private:
    [[nodiscard]] size_t TotalBytesForChars() const noexcept;
    std::vector<std::string_view> m_Strings;
};

} // namespace nc::base

namespace std {

// NOLINTBEGIN(readability-inconsistent-declaration-parameter-name)
template <>
inline void swap(nc::base::StringsBulk::Iterator &_lhs, nc::base::StringsBulk::Iterator &_rhs) noexcept
{
    _lhs.swap(_rhs);
}
// NOLINTEND(readability-inconsistent-declaration-parameter-name)

} // namespace std
