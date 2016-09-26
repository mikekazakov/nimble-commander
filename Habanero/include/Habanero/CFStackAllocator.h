#pragma once

#include <CoreFoundation/CoreFoundation.h>

struct CFStackAllocator
{
    CFStackAllocator() noexcept;

    inline CFAllocatorRef Alloc() const noexcept { return m_Alloc; }
    
private:
    static const int        m_Size = 4096;
    char                    m_Buffer[m_Size];
    // these members should be last to keep cache happy:
    int                     m_Left;
    const CFAllocatorRef    m_Alloc;
    
    CFAllocatorRef __Construct() noexcept;
    static void *__DoAlloc(CFIndex allocSize, CFOptionFlags hint, void *info);
    static void  __DoDealloc(void *ptr, void *info);
};
