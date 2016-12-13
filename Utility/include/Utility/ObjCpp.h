#pragma once

#include <functional>
//#include <

#ifdef __OBJC__

/**
 * Returns a _T_ class object if _from_ can be converted to it.
 * If _from_ can't be converted to _T_ - returns nil.
 * If _from_ is nil - returns nil.
 */
template<typename T>
inline T* objc_cast(id from) noexcept {
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
        if( __strong T *strong_obj = weak_obj )
            [T instanceMethodForSelector:_sel](strong_obj, _sel);
    };
}

#endif
