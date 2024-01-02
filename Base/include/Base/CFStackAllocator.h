// Copyright (C) 2016-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <CoreFoundation/CoreFoundation.h>

namespace nc::base {

struct alignas(16) CFStackAllocator {
    CFStackAllocator() noexcept;
    ~CFStackAllocator() noexcept;

    operator CFAllocatorRef() const noexcept { return m_Alloc; }

private:
    CFStackAllocator(const CFStackAllocator &) = delete;
    void operator=(const CFStackAllocator &) = delete;
    CFAllocatorRef Construct() noexcept;
    static void *DoAlloc(CFIndex _alloc_size, CFOptionFlags _hint, void *_info) noexcept;
    static void DoDealloc(void *_ptr, void *_info) noexcept;

    static constexpr int m_Size = 4096 - 16;
    char m_Buffer[m_Size];
    int m_Left;
    short m_StackObjects;
    short m_HeapObjects;
    const CFAllocatorRef m_Alloc;
};

} // namespace nc::base
