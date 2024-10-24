// Copyright (C) 2016-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/CFStackAllocator.h>
#include <fmt/core.h>

namespace nc::base {

CFStackAllocator::CFStackAllocator() noexcept
    : m_Left(m_Size), m_StackObjects(0), m_HeapObjects(0), m_Alloc(Construct())
{
    static_assert(sizeof(CFStackAllocator) == m_Size + 16);
}

CFStackAllocator::~CFStackAllocator() noexcept
{
    CFRelease(m_Alloc);
    if( m_StackObjects || m_HeapObjects )
        fmt::print(stderr,
                   "CFStackAllocator was deallocated with leaked objects:\n"
                   "  alive stack objects: {}\n"
                   "  alive heap objects:  {}\n",
                   m_StackObjects,
                   m_HeapObjects);
}

CFAllocatorRef CFStackAllocator::Construct() noexcept
{
    CFAllocatorContext context = {0, this, nullptr, nullptr, nullptr, DoAlloc, nullptr, DoDealloc, nullptr};
    return CFAllocatorCreate(kCFAllocatorUseContext, &context);
}

void *CFStackAllocator::DoAlloc(CFIndex _alloc_size, CFOptionFlags /*_hint*/, void *_info) noexcept
{
    assert(_alloc_size >= 0);
    constexpr long alignment = 16;
    constexpr long align_bm = alignment - 1;
    const long aligned_size = (_alloc_size + align_bm) & ~align_bm;

    auto me = static_cast<CFStackAllocator *>(_info);
    if( aligned_size <= me->m_Left ) {
        void *v = me->m_Buffer + m_Size - me->m_Left;
        me->m_Left -= aligned_size;
        me->m_StackObjects++;
        return v;
    }
    else {
        me->m_HeapObjects++;
        return malloc(aligned_size);
    }
}

void CFStackAllocator::DoDealloc(void *_ptr, void *_info) noexcept
{
    auto me = static_cast<CFStackAllocator *>(_info);
    if( _ptr < me->m_Buffer || _ptr >= me->m_Buffer + m_Size ) {
        free(_ptr);
        me->m_HeapObjects--;
    }
    else {
        me->m_StackObjects--;
    }
}

} // namespace nc::base
