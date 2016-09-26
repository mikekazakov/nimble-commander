#include "../include/Habanero/CFStackAllocator.h"

CFStackAllocator::CFStackAllocator() noexcept:
    m_Left(m_Size),
    m_Alloc(__Construct())
{}

CFAllocatorRef CFStackAllocator::__Construct() noexcept
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

void *CFStackAllocator::__DoAlloc(CFIndex allocSize, CFOptionFlags hint, void *info)
{
    CFStackAllocator *me = (CFStackAllocator *)info;
    if( allocSize <= me->m_Left ) {
        void *v = me->m_Buffer + m_Size - me->m_Left;
        me->m_Left -= allocSize;
        return v;
    }
    else
        return malloc(allocSize);
}

void CFStackAllocator::__DoDealloc(void *ptr, void *info)
{
    CFStackAllocator *me = (CFStackAllocator *)info;
    if( ptr < me->m_Buffer || ptr >= me->m_Buffer + m_Size )
        free(ptr);
}
