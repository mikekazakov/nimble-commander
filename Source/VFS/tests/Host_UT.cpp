// Copyright (C) 2024-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>

#define PREFIX "nc::vfs::Host "

using namespace nc;
using namespace nc::vfs;
using ::testing::_;

TEST_CASE(PREFIX "FetchSingleItemListing")
{
    struct MockHost : Host {
        MockHost() : Host("/", nullptr, "mock") {}
        MOCK_METHOD(int, Stat, (std::string_view, VFSStat &, unsigned long, const VFSCancelChecker &), (override));
    };

    auto host = std::make_shared<MockHost>();

    VFSListingPtr listing;
    SECTION("Not absolute path")
    {
        REQUIRE(host->FetchSingleItemListing("not absolute path", listing, VFSFlags::None) != VFSError::Ok);
    }
    SECTION("Single reg-file listing")
    {
        EXPECT_CALL(*host, Stat(_, _, _, _))
            .WillRepeatedly([](std::string_view _path, VFSStat &st, unsigned long, const VFSCancelChecker &) {
                REQUIRE(_path == "/my/file.txt");
                memset(&st, 0, sizeof(st));
                st.size = 42;
                st.mode_bits.reg = true;
                return 0;
            });
        REQUIRE(host->FetchSingleItemListing("/my/file.txt", listing, VFSFlags::None) == VFSError::Ok);
        REQUIRE(listing);
        REQUIRE(listing->Host() == host);
        REQUIRE(listing->Count() == 1);
        REQUIRE(listing->HasCommonDirectory());
        REQUIRE(listing->Directory() == "/my/");
        auto item = listing->Item(0);
        REQUIRE(item.Directory() == "/my/");
        REQUIRE(item.Filename() == "file.txt");
        REQUIRE(item.Size() == 42);
        REQUIRE(item.UnixMode() == S_IFREG);
    }
    SECTION("Removes trailing slashes")
    {
        EXPECT_CALL(*host, Stat(_, _, _, _))
            .WillRepeatedly([](std::string_view _path, VFSStat &st, unsigned long, const VFSCancelChecker &) {
                REQUIRE(_path == "/my/file.txt");
                memset(&st, 0, sizeof(st));
                st.size = 42;
                st.mode_bits.reg = true;
                return 0;
            });
        REQUIRE(host->FetchSingleItemListing("/my/file.txt///", listing, VFSFlags::None) == VFSError::Ok);
        REQUIRE(listing);
        REQUIRE(listing->Directory() == "/my/");
        auto item = listing->Item(0);
        REQUIRE(item.Directory() == "/my/");
        REQUIRE(item.Filename() == "file.txt");
    }
}

TEST_CASE(PREFIX "Unsupported methods")
{
    auto host = std::make_shared<Host>("/", nullptr, "dummy");
    const Error enotsup = Error{Error::POSIX, ENOTSUP};
    // ...
    REQUIRE(host->Rename("/some/path1", "/some/path2").error() == enotsup);
    REQUIRE(host->Trash("/some/path").error() == enotsup);
    REQUIRE(host->SetFlags("/some/path", 0, 0).error() == enotsup);
    REQUIRE(host->SetPermissions("/some/path", 42).error() == enotsup);
    REQUIRE(host->SetOwnership("/some/path", 42, 42).error() == enotsup);
    REQUIRE(host->SetTimes("/some/path", std::nullopt, std::nullopt, std::nullopt, std::nullopt).error() == enotsup);
    REQUIRE(host->FetchUsers().error() == enotsup);
    REQUIRE(host->FetchGroups().error() == enotsup);
    // ...
}
