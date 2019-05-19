// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CFPtr.h"
#include "UnitTests_main.h"

using nc::base::CFPtr;

#define PREFIX "nc::base::CFPtr "
//TEST_CASE(PREFIX"Default constructor makes both unicode and modifiers zero")
//{
//    ActionShortcut as;
//    CHECK( as.unicode == 0 );
//    CHECK( as.modifiers.is_empty() );
//}

TEST_CASE(PREFIX"Is empty by default")
{
    CFPtr<CFArrayRef> p;
    CHECK( p.get() == nullptr );
    CHECK( (bool)p == false );    
}

TEST_CASE(PREFIX"Constructor with existing CoreFoundation object")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    CHECK( CFGetRetainCount(array) == 1 );
    
    {
        CFPtr<CFMutableArrayRef> p{array};
        CHECK( CFGetRetainCount(array) == 2 );
        CHECK( p.get() == array );
        CHECK( (bool)p == true );
    }
    CHECK( CFGetRetainCount(array) == 1 );
    CFRelease(array);
}

TEST_CASE(PREFIX"Adoption of existing CoreFoundation object")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    CHECK( CFGetRetainCount(array) == 1 );
    {
        auto p = CFPtr<CFMutableArrayRef>::adopt(array);
        CHECK( CFGetRetainCount(array) == 1 );
        CHECK( p.get() == array );
        CHECK( (bool)p == true );
    }
}

TEST_CASE(PREFIX"Copy constructor")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK( CFGetRetainCount(array) == 1 );
    auto p2 = p1;
    CHECK( CFGetRetainCount(array) == 2 );
}

TEST_CASE(PREFIX"Move constructor")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK( CFGetRetainCount(array) == 1 );
    auto p2 = std::move(p1);
    CHECK( CFGetRetainCount(array) == 1 );
    CHECK( p1.get() == nullptr );
}

TEST_CASE(PREFIX"Assignment operator")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK( CFGetRetainCount(array) == 1 );
    CFPtr<CFMutableArrayRef> p2;
    p2 = p1;
    CHECK( CFGetRetainCount(array) == 2 );
    CHECK( p2.get() == array );
    p2 = p2;
    CHECK( CFGetRetainCount(array) == 2 );
    CHECK( p2.get() == array );
}

TEST_CASE(PREFIX"Move assignment operator")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK( CFGetRetainCount(array) == 1 );
    CFPtr<CFMutableArrayRef> p2;
    p2 = std::move(p1);
    CHECK( CFGetRetainCount(array) == 1 );
    CHECK( p1.get() == nullptr );
    CHECK( p2.get() == array );
    p2 = p2;
    CHECK( CFGetRetainCount(array) == 1 );
    CHECK( p2.get() == array );
}

TEST_CASE(PREFIX"swap")
{
    CFMutableArrayRef array1 = CFArrayCreateMutable(nullptr, 0, nullptr);
    CFMutableArrayRef array2 = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array1);
    auto p2 = CFPtr<CFMutableArrayRef>::adopt(array2);
    
    p1.swap(p2);
    CHECK( p1.get() == array2 );
    CHECK( p2.get() == array1 );
    
    std::swap(p1, p2);
    CHECK( p1.get() == array1 );
    CHECK( p2.get() == array2 );    
}

TEST_CASE(PREFIX"reset")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    auto p2 = p1;
    CHECK( CFGetRetainCount(array) == 2 );
    
    p1.reset();
    CHECK( CFGetRetainCount(array) == 1 );    
    
    p1.reset(array);
    CHECK( CFGetRetainCount(array) == 2 );

    p1.reset(array);
    CHECK( CFGetRetainCount(array) == 2 );    
}
