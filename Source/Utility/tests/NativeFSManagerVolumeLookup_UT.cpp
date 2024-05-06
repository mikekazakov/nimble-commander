// Copyright (C) 2019-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NativeFSManagerVolumeLookup.h>
#include "UnitTests_main.h"

using VolumeLookup = nc::utility::NativeFSManagerVolumeLookup;
using nc::utility::NativeFileSystemInfo;
#define PREFIX "nc::utility::NativeFSManager::VolumeLookup "

TEST_CASE(PREFIX "insert() throws on invalid inputs")
{
    auto l = VolumeLookup{};
    CHECK_THROWS(l.Insert(nullptr, "/some/path"));
    CHECK_THROWS(l.Insert(std::make_shared<NativeFileSystemInfo>(), ""));
    CHECK_THROWS(l.Insert(std::make_shared<NativeFileSystemInfo>(), "some/path"));
    CHECK_THROWS(l.Insert(std::make_shared<NativeFileSystemInfo>(), "/some/path"));
    CHECK_NOTHROW(l.Insert(std::make_shared<NativeFileSystemInfo>(), "/some/path/"));
}

TEST_CASE(PREFIX "finds right volumes")
{
    auto l = VolumeLookup{};
    const auto a = std::make_shared<NativeFileSystemInfo>();
    const auto b = std::make_shared<NativeFileSystemInfo>();
    const auto c = std::make_shared<NativeFileSystemInfo>();

    SECTION("")
    {
        l.Insert(a, "/");
        l.Insert(b, "/some/path/");
        l.Insert(c, "/another_path/");
    }
    SECTION("")
    {
        l.Insert(c, "/another_path/");
        l.Insert(b, "/some/path/");
        l.Insert(a, "/");
    }

    CHECK(l.FindVolumeForLocation("") == nullptr);
    CHECK(l.FindVolumeForLocation("/") == a);
    CHECK(l.FindVolumeForLocation("/some/path") == a);
    CHECK(l.FindVolumeForLocation("/some/path/") == b);
    CHECK(l.FindVolumeForLocation("/some/path/something_else") == b);
    CHECK(l.FindVolumeForLocation("/another_path") == a);
    CHECK(l.FindVolumeForLocation("/another_path/") == c);
    CHECK(l.FindVolumeForLocation("/another_path/something_else") == c);
}

TEST_CASE(PREFIX "can overwrite")
{
    auto l = VolumeLookup{};
    const auto a = std::make_shared<NativeFileSystemInfo>();
    const auto b = std::make_shared<NativeFileSystemInfo>();
    const auto c = std::make_shared<NativeFileSystemInfo>();
    l.Insert(a, "/");
    l.Insert(b, "/dir/");
    l.Insert(c, "/dir/");
    CHECK(l.FindVolumeForLocation("/") == a);
    CHECK(l.FindVolumeForLocation("/dir/") == c);
}

TEST_CASE(PREFIX "can remove")
{
    auto l = VolumeLookup{};
    const auto a = std::make_shared<NativeFileSystemInfo>();
    const auto b = std::make_shared<NativeFileSystemInfo>();
    const auto c = std::make_shared<NativeFileSystemInfo>();

    l.Insert(a, "/");
    l.Insert(b, "/dir1/");
    l.Insert(c, "/dir2/");
    CHECK(l.FindVolumeForLocation("/blahblah") == a);
    CHECK(l.FindVolumeForLocation("/dir1/blahblah") == b);
    CHECK(l.FindVolumeForLocation("/dir2/blahblah") == c);

    l.Remove("/dir2/");
    CHECK(l.FindVolumeForLocation("/blahblah") == a);
    CHECK(l.FindVolumeForLocation("/dir1/blahblah") == b);
    CHECK(l.FindVolumeForLocation("/dir2/blahblah") == a);

    l.Remove("/dir1/");
    CHECK(l.FindVolumeForLocation("/blahblah") == a);
    CHECK(l.FindVolumeForLocation("/dir1/blahblah") == a);
    CHECK(l.FindVolumeForLocation("/dir2/blahblah") == a);

    l.Remove("/");
    CHECK(l.FindVolumeForLocation("/blahblah") == nullptr);
    CHECK(l.FindVolumeForLocation("/dir1/blahblah") == nullptr);
    CHECK(l.FindVolumeForLocation("/dir2/blahblah") == nullptr);
}

TEST_CASE(PREFIX "works when empty")
{
    auto l = VolumeLookup{};
    CHECK(l.FindVolumeForLocation("") == nullptr);
    CHECK(l.FindVolumeForLocation("/") == nullptr);
}
