// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
// #define CATCH_CONFIG_ENABLE_BENCHMARKING
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/ArcLA.h>

#define PREFIX "VFSArchive PT "

using namespace nc::vfs;

TEST_CASE(PREFIX "Open chromium-main.zip", "[!benchmark]")
{
    std::shared_ptr<ArchiveHost> host;
    auto path = "/Users/migun/Devel/chromium-main.zip";
    BENCHMARK("Open")
    {
        REQUIRE_NOTHROW(host = std::make_shared<ArchiveHost>(path, TestEnv().vfs_native));
    };
}
