// Copyright (C) 2016-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <functional>
#include <Base/dispatch_cpp.h>

#ifdef __OBJC__
#include <objc/runtime.h>

namespace nc {

// a compile-time lookup of Objective-C classes
template <typename T>
struct objc_class_lookup {
    inline static Class const class_meta = [T class];
};

/**
 * Returns a _T_ class object if _from_ can be converted to it.
 * If _from_ can't be converted to _T_ - returns nil.
 * If _from_ is nil - returns nil.
 * NB! must not be used in initialization of global objects, i.e. before main().
 */
template <typename T>
T *objc_cast(id from) noexcept
{
    // This assert ensures that 'objc_cast' wasn't called before initialization of objc_class_lookup::class_meta, i.e.
    // not before 'main()'.
    assert(objc_class_lookup<T>::class_meta != nullptr && class_getName(objc_class_lookup<T>::class_meta) != nullptr);
    if( [from isKindOfClass:objc_class_lookup<T>::class_meta] )
        return static_cast<T *>(from);
    return nil;
}

template <typename T, typename U>
T *objc_bridge_cast(U *from) noexcept
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wold-style-cast"
    return (__bridge T *)from;
#pragma clang diagnostic pop
}

// Returns a C string with a name of a concrete class that _object has.
const char *objc_class_c_str(id _object) noexcept;

template <typename T>
std::function<void()> objc_callback(T *_obj, SEL _sel) noexcept
{
    __weak id weak_obj = _obj;
    return [weak_obj, _sel] {
        if( __strong T *strong_obj = weak_obj ) {
            typedef void (*func_type)(id, SEL);
            func_type func = reinterpret_cast<func_type>([T instanceMethodForSelector:_sel]);
            func(strong_obj, _sel);
        }
    };
}

template <typename T>
std::function<void()> objc_callback_to_main_queue(T *_obj, SEL _sel) noexcept
{
    typedef void (*func_type)(id, SEL);
    __weak id weak_obj = _obj;
    return [weak_obj, _sel] {
        if( __strong T *strong_obj_test = weak_obj ) {
            if( dispatch_is_main_queue() ) {
                // already in the main queue - execute immediately
                func_type func = reinterpret_cast<func_type>([T instanceMethodForSelector:_sel]);
                func(strong_obj_test, _sel);
            }
            else {
                // in a background thread - dispatch
                dispatch_to_main_queue([weak_obj, _sel] {
                    if( __strong T *strong_obj = weak_obj ) {
                        func_type func = reinterpret_cast<func_type>([T instanceMethodForSelector:_sel]);
                        func(strong_obj, _sel);
                    }
                });
            }
        }
    };
}

template <typename T>
size_t objc_sizeof() noexcept
{
    return class_getInstanceSize([T class]);
}

} // namespace nc

#endif
