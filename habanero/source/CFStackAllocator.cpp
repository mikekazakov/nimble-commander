/* Copyright (c) 2016-2017 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
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

void *CFStackAllocator::DoAlloc(CFIndex _alloc_size, CFOptionFlags _hint, void *_info)
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
