#pragma once

#ifdef __OBJC__

/**
 * Returns a _T_ class object if _from_ can be converted to it.
 * If _from_ can't be converted to _T_ - returns nil.
 * If _from_ is nil - returns nil.
 */
template<typename T>
T* objc_cast(id from) noexcept {
    static const auto class_meta = [T class];
    if( [from isKindOfClass:class_meta] )
        return static_cast<T*>(from);
    return nil;
}

#endif
