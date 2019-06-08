// Copyright (C) 2016-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/CFStackAllocator.h>

#include <iostream>

CFStackAllocator::CFStackAllocator() noexcept:
    m_Left(m_Size),
    m_StackObjects(0),
    m_HeapObjects(0),
    m_Alloc(Construct())
{
    static_assert( sizeof(CFStackAllocator) == m_Size + 16 );
}

CFStackAllocator::~CFStackAllocator() noexcept
{
    CFRelease(m_Alloc);
    if( m_StackObjects || m_HeapObjects )
        std::cerr << "CFStackAllocator was deallocated with leaked objects:" << std::endl
                  << "  alive stack objects: " << m_StackObjects << std::endl
                  << "  alive heap objects:  " << m_HeapObjects << std::endl;
}

CFAllocatorRef CFStackAllocator::Construct() noexcept
{
    CFAllocatorContext context = {
        0,
        this,
        nullptr,
        nullptr,
        nullptr,
        DoAlloc,
        nullptr,
        DoDealloc,
        nullptr
    };
    return CFAllocatorCreate(kCFAllocatorUseContext, &context);
}

void *CFStackAllocator::DoAlloc(CFIndex _alloc_size,
                                [[maybe_unused]] CFOptionFlags _hint,
                                void *_info)
{
    
    auto me = (CFStackAllocator *)_info;
    if( _alloc_size <= me->m_Left ) {
        void *v = me->m_Buffer + m_Size - me->m_Left;
        me->m_Left -= _alloc_size;
        me->m_StackObjects++;
        return v;
    }
    else {
        me->m_HeapObjects++;
        return malloc(_alloc_size);
    }
}

void CFStackAllocator::DoDealloc(void *_ptr, void *_info)
{
    auto me = (CFStackAllocator *)_info;
    if( _ptr < me->m_Buffer || _ptr >= me->m_Buffer + m_Size ) {
        free(_ptr);
        me->m_HeapObjects--;
    }
    else {
        me->m_StackObjects--;
    }
}
