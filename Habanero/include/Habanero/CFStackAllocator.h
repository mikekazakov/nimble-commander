/* Copyright (c) 2016-17 Michael G. Kazakov
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
#pragma once

#include <CoreFoundation/CoreFoundation.h>

struct CFStackAllocator
{
    CFStackAllocator() noexcept;
    ~CFStackAllocator() noexcept;

    inline CFAllocatorRef Alloc() const noexcept { return m_Alloc; }
    
private:
    CFStackAllocator(const CFStackAllocator&) = delete;
    void operator =(const CFStackAllocator&) = delete;
    CFAllocatorRef Construct() noexcept;
    static void *DoAlloc(CFIndex _alloc_size, CFOptionFlags _hint, void *_info);
    static void DoDealloc(void *_ptr, void *_info);
    
    static const int        m_Size = 4096 - 16;
    char                    m_Buffer[m_Size];
    int                     m_Left;
    short                   m_StackObjects;
    short                   m_HeapObjects;
    const CFAllocatorRef    m_Alloc;
};
