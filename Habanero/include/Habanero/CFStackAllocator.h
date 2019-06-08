// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
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
