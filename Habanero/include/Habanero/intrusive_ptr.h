// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <utility>
#include <type_traits>
#include <atomic>

// this is an almost straight copy of boost::intrusive_ptr, mainly because I don't want
// to have all that legacy support and preprocessor spaghetti.

namespace nc::hbn {
    
template <typename T>
class intrusive_ptr
{
public:
    using element_type = T;
    using pointer = T*;

    static_assert( std::is_same_v<decltype(intrusive_ptr_add_refcount((const T*)nullptr)), void> );
    static_assert( std::is_same_v<decltype(intrusive_ptr_dec_refcount((const T*)nullptr)), void> );
    
    constexpr intrusive_ptr() noexcept : p(nullptr)
    {} 
    
    constexpr intrusive_ptr(std::nullptr_t) noexcept : p(nullptr)
    {}
    
    explicit intrusive_ptr(T *_p) noexcept : p(_p)
    {
        if(p) intrusive_ptr_add_refcount( p );
    }

    intrusive_ptr(const intrusive_ptr &_rhs) noexcept : p(_rhs.p)
    {
        if(p) intrusive_ptr_add_refcount( p );
    }
    
    template <typename U>
    intrusive_ptr(const intrusive_ptr<U> &_rhs,
                  std::enable_if_t<std::is_convertible_v<U*, T*>>* = nullptr) noexcept :
        p(_rhs.get())
    {
        if(p) intrusive_ptr_add_refcount( p );
    }

    intrusive_ptr(intrusive_ptr &&_rhs) noexcept : p(_rhs.p)
    {
        _rhs.p = nullptr;
    }    
    
    template <typename U>
    intrusive_ptr(intrusive_ptr<U> &&_rhs,
                  std::enable_if_t<std::is_convertible_v<U*, T*>>* = nullptr) noexcept :
        p(_rhs.get())
    {
        _rhs.release();
    }    
    
    ~intrusive_ptr() noexcept
    {
        if( p != nullptr )
            intrusive_ptr_dec_refcount( p );
    }    
    
    intrusive_ptr &operator=(const intrusive_ptr &_rhs) noexcept
    {
        intrusive_ptr( _rhs ).swap( *this );
        return *this;
    }    
    
    intrusive_ptr& operator=(intrusive_ptr &&_rhs) noexcept
    {
        intrusive_ptr( std::move(_rhs) ).swap( *this );
        return *this;
    }    
    
    intrusive_ptr& operator=( std::nullptr_t ) noexcept
    {
        reset();
        return *this;        
    }    
    
    void reset() noexcept
    {
        intrusive_ptr().swap( *this );
    }    

    template <typename U>
    std::enable_if_t<std::is_convertible_v<U*, T*>, void> reset(U* _p) noexcept
    {
        intrusive_ptr(_p).swap( *this );
    }
    
    T *get() const noexcept
    {
        return p;
    }
    
    T *release() noexcept
    {
        auto tmp = p;
        p = nullptr;
        return tmp;
    }
    
    T &operator*() const noexcept
    {
        return *p;
    }
    
    T *operator->() const noexcept
    {
        return p;
    }    

    explicit operator bool() const noexcept
    {
        return p != nullptr;
    }

    void swap(intrusive_ptr &_rhs) noexcept
    {
        std::swap(p, _rhs.p);
    }
    
private:
    T *p;
};    
    
template<class T, class U>
inline bool operator==(const intrusive_ptr<T> &_lhs, const intrusive_ptr<U> &_rhs) noexcept
{
    return _lhs.get() == _rhs.get();
}

template<class T, class U>
inline bool operator!=(const intrusive_ptr<T> &_lhs, const intrusive_ptr<U> &_rhs) noexcept
{
    return _lhs.get() != _rhs.get();
}

template<class T, class U>
inline bool operator<(const intrusive_ptr<T> &_lhs, const intrusive_ptr<U> &_rhs) noexcept
{
    return _lhs.get() < _rhs.get();
}

template<class T, class U>
inline bool operator<=(const intrusive_ptr<T> &_lhs, const intrusive_ptr<U> &_rhs) noexcept
{
    return _lhs.get() <= _rhs.get();
}

template<class T, class U>
inline bool operator>(const intrusive_ptr<T> &_lhs, const intrusive_ptr<U> &_rhs) noexcept
{
    return _lhs.get() > _rhs.get();
}

template<class T, class U>
inline bool operator>=(const intrusive_ptr<T> &_lhs, const intrusive_ptr<U> &_rhs) noexcept
{
    return _lhs.get() >= _rhs.get();
}
    
template<class T>
inline bool operator==(const intrusive_ptr<T> &_p, std::nullptr_t) noexcept
{
    return !(bool)_p;
}

template<class T>
inline bool operator==(std::nullptr_t, const intrusive_ptr<T> &_p) noexcept
{
    return !(bool)_p;
}

template<class T>
inline bool operator!=(const intrusive_ptr<T> &_p, std::nullptr_t) noexcept
{
    return (bool)_p;
}

template<class T>
inline bool operator!=(std::nullptr_t, const intrusive_ptr<T> &_p) noexcept
{
    return (bool)_p;
}

template<typename T>
class intrusive_ref_counter;
    
template <typename T>
void intrusive_ptr_add_refcount(const intrusive_ref_counter<T> *p) noexcept;
template <typename T>    
void intrusive_ptr_dec_refcount(const intrusive_ref_counter<T> *p) noexcept;    

template <typename T>
class intrusive_ref_counter
{
public:
    intrusive_ref_counter() noexcept : c{0}
    {
    }       

    intrusive_ref_counter(const intrusive_ref_counter&) noexcept : c{0}
    {
    }
    
    intrusive_ref_counter& operator=(const intrusive_ref_counter&) noexcept
    {
        return *this;
    }    

protected:
    ~intrusive_ref_counter() = default;
    
private:
    mutable std::atomic<int> c;    
    friend void intrusive_ptr_add_refcount<T>(const intrusive_ref_counter<T> *p) noexcept;
    friend void intrusive_ptr_dec_refcount<T>(const intrusive_ref_counter<T> *p) noexcept;    
};
    
template <typename T>
inline void intrusive_ptr_add_refcount(const intrusive_ref_counter<T> *p) noexcept
{
    p->c.fetch_add( 1, std::memory_order_relaxed );
}
    
template <typename T>
inline void intrusive_ptr_dec_refcount(const intrusive_ref_counter<T> *p) noexcept
{
    if( p->c.fetch_sub(1, std::memory_order_acq_rel) == 1 )
        delete static_cast<const T*>( p );        
}
    
}

namespace std {

template <typename T>
inline void swap( nc::hbn::intrusive_ptr<T> &lhs, nc::hbn::intrusive_ptr<T> &rhs ) noexcept
{
    lhs.swap(rhs);
}

template <typename T>
struct hash< nc::hbn::intrusive_ptr<T> >
{
    using argument_type = nc::hbn::intrusive_ptr<T>; 
    using result_type = size_t; 
    result_type operator()(const argument_type& _p) const
    {
        return hash<typename argument_type::pointer>()(_p.get());
    }
};
    
}
