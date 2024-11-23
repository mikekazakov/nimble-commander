// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CFPtr.h"
#include "UnitTests_main.h"

using nc::base::CFPtr;

#define PREFIX "nc::base::CFPtr "

TEST_CASE(PREFIX "Is empty by default")
{
    const CFPtr<CFArrayRef> p;
    CHECK(p.get() == nullptr);
    CHECK(static_cast<bool>(p) == false);
}

TEST_CASE(PREFIX "Constructor with existing CoreFoundation object")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    CHECK(CFGetRetainCount(array) == 1);

    {
        const CFPtr<CFMutableArrayRef> p{array};
        CHECK(CFGetRetainCount(array) == 2);
        CHECK(p.get() == array);
        CHECK(static_cast<bool>(p) == true);
    }
    CHECK(CFGetRetainCount(array) == 1);
    CFRelease(array);
}

TEST_CASE(PREFIX "Adoption of existing CoreFoundation object")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    CHECK(CFGetRetainCount(array) == 1);
    {
        auto p = CFPtr<CFMutableArrayRef>::adopt(array);
        CHECK(CFGetRetainCount(array) == 1);
        CHECK(p.get() == array);
        CHECK(static_cast<bool>(p) == true);
    }
}

TEST_CASE(PREFIX "Copy constructor")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK(CFGetRetainCount(array) == 1);
    CFPtr<CFMutableArrayRef> p2(p1); // NOLINT
    CHECK(CFGetRetainCount(array) == 2);
    CHECK(p2.get() == array);
}

TEST_CASE(PREFIX "Converting copy constructor")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK(CFGetRetainCount(array) == 1);
    const CFPtr<CFArrayRef> p2(p1);
    CHECK(CFGetRetainCount(array) == 2);
    CHECK(p2.get() == array);
}

TEST_CASE(PREFIX "Move constructor")
{
    // NOLINTBEGIN(bugprone-use-after-move)
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK(CFGetRetainCount(array) == 1);
    auto p2 = std::move(p1);
    CHECK(CFGetRetainCount(array) == 1);
    CHECK(p1.get() == nullptr);
    // NOLINTEND(bugprone-use-after-move)
}

TEST_CASE(PREFIX "Converting move constructor")
{
    // NOLINTBEGIN(bugprone-use-after-move)
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK(CFGetRetainCount(array) == 1);
    const CFPtr<CFMutableArrayRef> p2(std::move(p1));
    CHECK(CFGetRetainCount(array) == 1);
    CHECK(p1.get() == nullptr);
    // NOLINTEND(bugprone-use-after-move)
}

TEST_CASE(PREFIX "Assignment operator")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK(CFGetRetainCount(array) == 1);
    CFPtr<CFMutableArrayRef> p2;
    p2 = p1;
    CHECK(CFGetRetainCount(array) == 2);
    CHECK(p2.get() == array);
    p2.operator=(p2);
    CHECK(CFGetRetainCount(array) == 2);
    CHECK(p2.get() == array);
}

TEST_CASE(PREFIX "Converting assignment operator")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK(CFGetRetainCount(array) == 1);
    CFPtr<CFArrayRef> p2;
    p2 = p1;
    CHECK(CFGetRetainCount(array) == 2);
    CHECK(p2.get() == array);
}

TEST_CASE(PREFIX "Move assignment operator")
{
    // NOLINTBEGIN(bugprone-use-after-move)
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK(CFGetRetainCount(array) == 1);
    CFPtr<CFMutableArrayRef> p2;
    p2 = std::move(p1);
    CHECK(CFGetRetainCount(array) == 1);
    CHECK(p1.get() == nullptr);
    CHECK(p2.get() == array);
    p2.operator=(p2);
    CHECK(CFGetRetainCount(array) == 1);
    CHECK(p2.get() == array);
    // NOLINTEND(bugprone-use-after-move)
}

TEST_CASE(PREFIX "Converting move assignment operator")
{
    // NOLINTBEGIN(bugprone-use-after-move)
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    CHECK(CFGetRetainCount(array) == 1);
    CFPtr<CFArrayRef> p2;
    p2 = std::move(p1);
    CHECK(CFGetRetainCount(array) == 1);
    CHECK(p1.get() == nullptr);
    CHECK(p2.get() == array);
    p2.operator=(p2);
    CHECK(CFGetRetainCount(array) == 1);
    CHECK(p2.get() == array);
    // NOLINTEND(bugprone-use-after-move)
}

TEST_CASE(PREFIX "swap")
{
    CFMutableArrayRef array1 = CFArrayCreateMutable(nullptr, 0, nullptr);
    CFMutableArrayRef array2 = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array1);
    auto p2 = CFPtr<CFMutableArrayRef>::adopt(array2);

    p1.swap(p2);
    CHECK(p1.get() == array2);
    CHECK(p2.get() == array1);

    std::swap(p1, p2);
    CHECK(p1.get() == array1);
    CHECK(p2.get() == array2);
}

TEST_CASE(PREFIX "reset")
{
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 0, nullptr);
    auto p1 = CFPtr<CFMutableArrayRef>::adopt(array);
    auto p2 = p1;
    CHECK(CFGetRetainCount(array) == 2);

    p1.reset();
    CHECK(CFGetRetainCount(array) == 1);

    p1.reset(array);
    CHECK(CFGetRetainCount(array) == 2);

    p1.reset(array);
    CHECK(CFGetRetainCount(array) == 2);
}
