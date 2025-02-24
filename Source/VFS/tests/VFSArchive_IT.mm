// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/ArcLA.h>
#include <VFS/Native.h>
#include <sys/stat.h>
#include <thread>
#include <fmt/core.h>

using namespace nc::vfs;

#define PREFIX "VFSArchive "

TEST_CASE(PREFIX "XNUSource - TAR")
{
    const TestDir dir;
    auto url = "https://opensource.apple.com/tarballs/xnu/xnu-3248.20.55.tar.gz";
    auto path = dir.directory / "xnu-3248.20.55.tar.gz";
    auto cmd = fmt::format("/usr/bin/curl -s -L -o {} {}", path.native(), url);
    REQUIRE(system(cmd.c_str()) == 0);

    std::shared_ptr<ArchiveHost> host;
    REQUIRE_NOTHROW(host = std::make_shared<ArchiveHost>(path.c_str(), TestEnv().vfs_native));

    REQUIRE(host->StatTotalDirs() == 245);
    REQUIRE(host->StatTotalRegs() == 3451);
    REQUIRE(host->IsDirectory("/", 0, nullptr) == true);
    REQUIRE(host->IsDirectory("/xnu-xnu-3248.20.55/EXTERNAL_HEADERS/mach-o/x86_64", 0, nullptr) == true);
    REQUIRE(host->IsDirectory("/xnu-xnu-3248.20.55/EXTERNAL_HEADERS/mach-o/x86_64/", 0, nullptr) == true);
    REQUIRE(host->Exists("/xnu-xnu-3248.20.55/2342423/9182391273/x86_64") == false);

    {
        const VFSStat st = host->Stat("/xnu-xnu-3248.20.55/bsd/security/audit/audit_bsm_socket_type.c", 0).value();
        REQUIRE(st.mode_bits.reg);
        REQUIRE(st.size == 3313);
    }

    {
        // symlinks were faulty in <1.1.3
        auto fn = "/xnu-xnu-3248.20.55/libkern/.clang-format";
        REQUIRE(host->IsSymlink(fn, VFSFlags::F_NoFollow));
        const VFSStat st = host->Stat(fn, 0).value();
        REQUIRE(st.mode_bits.reg);
        REQUIRE(st.size == 957);

        const VFSFilePtr file = host->CreateFile(fn).value();
        REQUIRE(file->Open(VFSFlags::OF_Read) == 0);
        auto d = file->ReadFile();
        REQUIRE(d->size() == 957);
        auto ref = "# See top level .clang-format for explanation of options";
        REQUIRE(std::memcmp(d->data(), ref, strlen(ref)) == 0);
    }

    const std::vector<std::string> filenames{"/xnu-xnu-3248.20.55/bsd/bsm/audit_domain.h",
                                             "/xnu-xnu-3248.20.55/bsd/netinet6/scope6_var.h",
                                             "/xnu-xnu-3248.20.55/bsd/vm/vm_unix.c",
                                             "/xnu-xnu-3248.20.55/iokit/bsddev/DINetBootHook.cpp",
                                             "/xnu-xnu-3248.20.55/iokit/Kernel/x86_64/IOAsmSupport.s",
                                             "/xnu-xnu-3248.20.55/iokit/Kernel/IOSubMemoryDescriptor.cpp",
                                             "/xnu-xnu-3248.20.55/bsd/libkern/memchr.c",
                                             "/xnu-xnu-3248.20.55/bsd/miscfs/deadfs/dead_vnops.c",
                                             "/xnu-xnu-3248.20.55/osfmk/x86_64/pmap.c",
                                             "/xnu-xnu-3248.20.55/pexpert/gen/device_tree.c",
                                             "/xnu-xnu-3248.20.55/pexpert/i386/pe_init.c",
                                             "/xnu-xnu-3248.20.55/pexpert/pexpert/i386/efi.h",
                                             "/xnu-xnu-3248.20.55/security/mac_policy.h",
                                             "/xnu-xnu-3248.20.55/tools/lockstat/lockstat.c"};

    const dispatch_group_t dg = dispatch_group_create();

    // massive concurrent access to archive
    for( int i = 0; i < 1000; ++i )
        dispatch_group_async(dg, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          const std::string &fn = filenames[std::rand() % filenames.size()];

          const VFSStat st = host->Stat(fn, 0).value();

          const VFSFilePtr file = host->CreateFile(fn).value();
          REQUIRE(file->Open(VFSFlags::OF_Read) == 0);
          std::this_thread::sleep_for(std::chrono::milliseconds(5));
          auto d = file->ReadFile();
          REQUIRE(d);
          REQUIRE(!d->empty());
          REQUIRE(d->size() == st.size);
        });

    dispatch_group_wait(dg, DISPATCH_TIME_FOREVER);
}
