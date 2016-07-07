#pragma once

#include <CoreFoundation/CoreFoundation.h>

template<int _size = 4096>
struct CFStackAllocator
{
    CFStackAllocator() noexcept:
        left(_size),
        alloc(__Construct())
    {}
    
    char buffer[_size];
    // these members should be last to keep cache happy:
    int left;
    const CFAllocatorRef alloc;
    
private:
    CFAllocatorRef __Construct() noexcept
    {
        CFAllocatorContext context = {
            0,
            this,
            nullptr,
            nullptr,
            nullptr,
            __DoAlloc,
            nullptr,
            __DoDealloc,
            nullptr
        };
        return CFAllocatorCreate(kCFAllocatorUseContext, &context);
    }
    
    static void *__DoAlloc(CFIndex allocSize, CFOptionFlags hint, void *info)
    {
        CFStackAllocator *me = (CFStackAllocator *)info;
        if( allocSize <= me->left ) {
            void *v = me->buffer + _size - me->left;
            me->left -= allocSize;
            return v;
        }
        else
            return malloc(allocSize);
    }
    
    static void __DoDealloc(void *ptr, void *info)
    {
        CFStackAllocator *me = (CFStackAllocator *)info;
        if( ptr < me->buffer || ptr >= me->buffer + _size )
            free(ptr);
    }
};
