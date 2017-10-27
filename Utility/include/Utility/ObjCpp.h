// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <functional>
#include <Habanero/dispatch_cpp.h>

#ifdef __OBJC__
#include <objc/runtime.h>

/**
 * Returns a _T_ class object if _from_ can be converted to it.
 * If _from_ can't be converted to _T_ - returns nil.
 * If _from_ is nil - returns nil.
 */
template<typename T>
inline T* objc_cast(id from) noexcept
{
    static const auto class_meta = [T class];
    if( [from isKindOfClass:class_meta] )
        return static_cast<T*>(from);
    return nil;
}

template<typename T>
inline std::function<void()> objc_callback(T *_obj, SEL _sel) noexcept
{
    __weak id weak_obj = _obj;
    return [weak_obj, _sel]{
        if( __strong T *strong_obj = weak_obj ) {
            typedef void (*func_type)(id, SEL);
            func_type func = (func_type)[T instanceMethodForSelector:_sel];
            func(strong_obj, _sel);
        }
    };
}

template<typename T>
inline std::function<void()> objc_callback_to_main_queue(T *_obj, SEL _sel) noexcept
{
    __weak id weak_obj = _obj;
    return [weak_obj, _sel]{
        if( __strong T *strong_obj_test = weak_obj )
            dispatch_to_main_queue([weak_obj, _sel]{
                if( __strong T *strong_obj = weak_obj ) {
                    typedef void (*func_type)(id, SEL);
                    func_type func = (func_type)[T instanceMethodForSelector:_sel];
                    func(strong_obj, _sel);
                }
            });
    };
}

template<typename T>
inline size_t objc_sizeof() noexcept
{
    return class_getInstanceSize ([T class]);
}

#endif
