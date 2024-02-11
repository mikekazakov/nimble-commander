// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/ArcLA.h>
#include <VFS/Native.h>
#include <sys/stat.h>
#include <thread>
#include <fmt/core.h>
#include "NCE.h"

using namespace nc::vfs;

#define PREFIX "VFSArchive "

[[clang::no_destroy]] static const auto g_Preffix = std::string(NCE(nc::env::test::ext_data_prefix)) + "archives/";
[[clang::no_destroy]] static const auto g_Angular = g_Preffix + "angular-1.4.0-beta.4.zip";
[[clang::no_destroy]] static const auto g_Files = g_Preffix + "files-1.1.0(1341).zip";
[[clang::no_destroy]] static const auto g_LZMA = g_Preffix + "lzma-4.32.7.tar.xz";
[[clang::no_destroy]] static const auto g_WarningArchive = g_Preffix + "maverix-master.zip";
[[clang::no_destroy]] static const auto g_ChineseArchive = g_Preffix + "GB18030.zip";
[[clang::no_destroy]] static const auto g_HeadingSlash =
    g_Preffix + "the.expanse.calibans.war.(2017).tv.s02.e13.eng.1cd.zip";
[[clang::no_destroy]] static const auto g_SlashDir = g_Preffix + "archive_with_slash_dir.zip";

static int VFSCompareEntries(const std::filesystem::path &_file1_full_path,
                             const VFSHostPtr &_file1_host,
                             const std::filesystem::path &_file2_full_path,
                             const VFSHostPtr &_file2_host,
                             int &_result)
{
    // not comparing flags, perm, times, xattrs, acls etc now

    VFSStat st1, st2;
    int ret;
    if( (ret = _file1_host->Stat(_file1_full_path.c_str(), st1, VFSFlags::F_NoFollow, 0)) < 0 )
        return ret;

    if( (ret = _file2_host->Stat(_file2_full_path.c_str(), st2, VFSFlags::F_NoFollow, 0)) < 0 )
        return ret;

    if( (st1.mode & S_IFMT) != (st2.mode & S_IFMT) ) {
        _result = -1;
        return 0;
    }

    if( S_ISREG(st1.mode) ) {
        if( int64_t(st1.size) - int64_t(st2.size) != 0 )
            _result = int(int64_t(st1.size) - int64_t(st2.size));
    }
    else if( S_ISLNK(st1.mode) ) {
        char link1[MAXPATHLEN], link2[MAXPATHLEN];
        if( (ret = _file1_host->ReadSymlink(_file1_full_path.c_str(), link1, MAXPATHLEN, 0)) < 0 )
            return ret;
        if( (ret = _file2_host->ReadSymlink(_file2_full_path.c_str(), link2, MAXPATHLEN, 0)) < 0 )
            return ret;
        if( strcmp(link1, link2) != 0 )
            _result = strcmp(link1, link2);
    }
    else if( S_ISDIR(st1.mode) ) {
        _file1_host->IterateDirectoryListing(_file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
            int ret = VFSCompareEntries(
                _file1_full_path / _dirent.name, _file1_host, _file2_full_path / _dirent.name, _file2_host, _result);
            if( ret != 0 )
                return false;
            return true;
        });
    }
    return 0;
}

TEST_CASE(PREFIX "XNUSource - TAR")
{
    TestDir dir;
    auto url = "https://opensource.apple.com/tarballs/xnu/xnu-3248.20.55.tar.gz";
    auto path = dir.directory / "xnu-3248.20.55.tar.gz";
    auto cmd = fmt::format("/usr/local/bin/wget -q -O {} {}", path.native(), url);
    REQUIRE(system(cmd.c_str()) == 0);

    std::shared_ptr<ArchiveHost> host;
    REQUIRE_NOTHROW(host = std::make_shared<ArchiveHost>(path.c_str(), TestEnv().vfs_native));

    REQUIRE(host->StatTotalDirs() == 245);
    REQUIRE(host->StatTotalRegs() == 3451);
    REQUIRE(host->IsDirectory("/", 0, 0) == true);
    REQUIRE(host->IsDirectory("/xnu-xnu-3248.20.55/EXTERNAL_HEADERS/mach-o/x86_64", 0, 0) == true);
    REQUIRE(host->IsDirectory("/xnu-xnu-3248.20.55/EXTERNAL_HEADERS/mach-o/x86_64/", 0, 0) == true);
    REQUIRE(host->Exists("/xnu-xnu-3248.20.55/2342423/9182391273/x86_64") == false);

    VFSStat st;
    REQUIRE(host->Stat("/xnu-xnu-3248.20.55/bsd/security/audit/audit_bsm_socket_type.c", st, 0, 0) == 0);
    REQUIRE(st.mode_bits.reg);
    REQUIRE(st.size == 3313);

    {
        // symlinks were faulty in <1.1.3
        auto fn = "/xnu-xnu-3248.20.55/libkern/.clang-format";
        REQUIRE(host->IsSymlink(fn, VFSFlags::F_NoFollow));
        REQUIRE(host->Stat(fn, st, 0, 0) == 0);
        REQUIRE(st.mode_bits.reg);
        REQUIRE(st.size == 957);

        VFSFilePtr file;
        REQUIRE(host->CreateFile(fn, file, nullptr) == 0);
        REQUIRE(file->Open(VFSFlags::OF_Read) == 0);
        auto d = file->ReadFile();
        REQUIRE(d->size() == 957);
        auto ref = "# See top level .clang-format for explanation of options";
        REQUIRE(std::memcmp(d->data(), ref, strlen(ref)) == 0);
    }

    std::vector<std::string> filenames{"/xnu-xnu-3248.20.55/bsd/bsm/audit_domain.h",
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

    dispatch_group_t dg = dispatch_group_create();

    // massive concurrent access to archive
    for( int i = 0; i < 1000; ++i )
        dispatch_group_async(dg, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          std::string fn = filenames[std::rand() % filenames.size()];
          INFO(fn);

          VFSStat local_st;
          REQUIRE(host->Stat(fn.c_str(), local_st, 0, 0) == 0);

          VFSFilePtr file;
          REQUIRE(host->CreateFile(fn.c_str(), file, nullptr) == 0);
          REQUIRE(file->Open(VFSFlags::OF_Read) == 0);
          std::this_thread::sleep_for(std::chrono::milliseconds(5));
          auto d = file->ReadFile();
          REQUIRE(d);
          REQUIRE(d->size() > 0);
          REQUIRE(d->size() == local_st.size);
        });

    dispatch_group_wait(dg, DISPATCH_TIME_FOREVER);
}

// was fault before 1.0.6, so introducing this regression test
TEST_CASE(PREFIX "angular")
{
    std::shared_ptr<ArchiveHost> host;
    REQUIRE_NOTHROW(host = std::make_shared<ArchiveHost>(g_Angular.c_str(), TestEnv().vfs_native));

    REQUIRE(host->StatTotalFiles() == 2764);
    REQUIRE(host->StatTotalRegs() == 2431);
    REQUIRE(host->StatTotalDirs() == 333);

    VFSStat st;
    auto fn = "/angular-1.4.0-beta.4/docs/examples/example-week-input-directive/protractor.js";
    REQUIRE(host->Stat(fn, st, 0, 0) == 0);
    REQUIRE(st.mode_bits.reg);
    REQUIRE(st.size == 1207);

    VFSFilePtr file;
    REQUIRE(host->CreateFile(fn, file, nullptr) == 0);
    REQUIRE(file->Open(VFSFlags::OF_Read) == 0);
    auto d = file->ReadFile();
    REQUIRE(d->size() == 1207);
    auto ref = "var value = element(by.binding('example.value | date: \"yyyy-Www\"'));";
    REQUIRE(std::memcmp(d->data(), ref, strlen(ref)) == 0);
}

TEST_CASE(PREFIX "lzma support")
{
    std::shared_ptr<ArchiveHost> host;
    REQUIRE_NOTHROW(host = std::make_shared<ArchiveHost>(g_LZMA.c_str(), TestEnv().vfs_native));

    VFSFilePtr file;

    REQUIRE(host->CreateFile("/lzma-4.32.7/ltmain.sh", file, 0) == 0);
    REQUIRE(file->Open(VFSFlags::OF_Read) == 0);

    auto d = file->ReadFile();
    REQUIRE(d->size() == 196440);
    auto ref = "# ltmain.sh - Provide generalized library-building support services.";
    REQUIRE(std::memcmp(d->data(), ref, std::strlen(ref)) == 0);
}

TEST_CASE(PREFIX "archive with warning")
{
    std::shared_ptr<ArchiveHost> host;
    REQUIRE_NOTHROW(host = std::make_shared<ArchiveHost>(g_WarningArchive.c_str(), TestEnv().vfs_native));

    VFSFilePtr file;

    REQUIRE(host->CreateFile("/maverix-master/maverix-theme/app/js/app.js", file, 0) == 0);
    REQUIRE(file->Open(VFSFlags::OF_Read) == 0);

    auto d = file->ReadFile();
    REQUIRE(d->size() == 1426);
    auto ref = "'use strict';";
    REQUIRE(std::memcmp(d->data(), ref, std::strlen(ref)) == 0);
}

TEST_CASE(PREFIX "chinese archive")
{
    std::shared_ptr<ArchiveHost> host;
    REQUIRE_NOTHROW(host = std::make_shared<ArchiveHost>(g_ChineseArchive.c_str(), TestEnv().vfs_native));

    VFSFilePtr file;

    REQUIRE(host->CreateFile(@"/操作系统原理/学生讲座/1.c".UTF8String, file, 0) == 0);
    REQUIRE(file->Open(VFSFlags::OF_Read) == 0);

    auto d = file->ReadFile();
    REQUIRE(d->size() == 627);
    auto ref = "#include <stdio.h>";
    REQUIRE(std::memcmp(d->data(), ref, std::strlen(ref)) == 0);
}

TEST_CASE(PREFIX "archive with heading slash")
{
    std::shared_ptr<ArchiveHost> host;
    REQUIRE_NOTHROW(host = std::make_shared<ArchiveHost>(g_HeadingSlash.c_str(), TestEnv().vfs_native));

    VFSListingPtr listing;
    REQUIRE(host->FetchDirectoryListing("/", listing, 0, nullptr) == VFSError::Ok);
}

TEST_CASE(PREFIX "archive with slash dir")
{
    std::shared_ptr<ArchiveHost> host;
    REQUIRE_NOTHROW(host = std::make_shared<ArchiveHost>(g_SlashDir.c_str(), TestEnv().vfs_native));

    VFSListingPtr listing;
    REQUIRE(host->FetchDirectoryListing("/", listing, 0, nullptr) == VFSError::Ok);
}
