// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreFoundation/CoreFoundation.h>

#include <utility>
#include <type_traits>

namespace nc::base {

template <typename T>
class CFPtr
{
public:
    using ValueType = std::remove_pointer_t<T>;
    using PointerType = ValueType*;
    
    CFPtr() noexcept : m_Ptr(nullptr) {
    }
    
    explicit CFPtr( PointerType _ptr ) noexcept : m_Ptr(_ptr) {
        if( m_Ptr ) CFRetain(m_Ptr);
    }
    
    CFPtr( const CFPtr &_rhs ) noexcept : m_Ptr(_rhs.m_Ptr) {
        if( m_Ptr ) CFRetain(m_Ptr);
    }
    
    CFPtr( CFPtr &&_rhs ) noexcept : m_Ptr(_rhs.m_Ptr) {
        _rhs.m_Ptr = nullptr;
    }
    
    ~CFPtr() noexcept {
        reset();
    }
    
    CFPtr &operator=( const CFPtr &_rhs ) noexcept {
        CFPtr tmp{_rhs};
        swap(tmp);
        return *this;
    }
    
    CFPtr &operator=( CFPtr &&_rhs ) noexcept {
        CFPtr tmp{std::move(_rhs)};
        swap(tmp);
        return *this;
    }
    
    PointerType get() const noexcept {
        return m_Ptr;
    }
    
    explicit operator PointerType() const noexcept {
        return m_Ptr;
    }
    
    explicit operator bool() const noexcept {
        return m_Ptr != nullptr;
    }
    
    void reset( PointerType _ptr = nullptr ) noexcept {
        if ( m_Ptr ) CFRelease(m_Ptr);
        m_Ptr = _ptr;
        if( m_Ptr ) CFRetain(m_Ptr);
    }
    
    void swap(CFPtr &_rhs) noexcept {
        std::swap( m_Ptr, _rhs.m_Ptr );
    }
    
    static CFPtr adopt(PointerType _ptr) noexcept {
        CFPtr p;
        p.m_Ptr = _ptr;
        return p;
    }
    
private:
    PointerType m_Ptr;
};

template<typename T>
inline void swap(CFPtr<T> &_lhs, CFPtr<T> &_rhs) noexcept
{
    _lhs.swap(_rhs);
}

template<typename T, typename U>
inline bool operator==(const CFPtr<T> &_lhs, const CFPtr<U> &_rhs) noexcept
{
    return _lhs.get() == _rhs.get();
}
    
template<typename T, typename U>
inline bool operator==(const CFPtr<T> &_lhs, U* _rhs) noexcept
{
    return _lhs.get() == _rhs;
}
    
template<typename T, typename U>
inline bool operator==(T* _lhs, const CFPtr<U> &_rhs) noexcept
{
    return _lhs == _rhs.get();
}

template<typename T, typename U>
inline bool operator!=(const CFPtr<T> &_lhs, const CFPtr<U> &_rhs) noexcept
{
    return _lhs.get() != _rhs.get();
}
    
template<typename T, typename U>
inline bool operator!=(const CFPtr<T> &_lhs, U* _rhs) noexcept
{
    return _lhs.get() != _rhs;
}
    
template<typename T, typename U>
inline bool operator!=(T* _lhs, const CFPtr<U> &_rhs) noexcept
{
    return _lhs != _rhs.get();
}
    
}
