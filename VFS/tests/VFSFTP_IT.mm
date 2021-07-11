// Copyright (C) 2014-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include "NCE.h"
#include <VFS/VFS.h>
#include <VFS/NetFTP.h>
#include <VFS/Native.h>
#include <set>
#include <thread>

using namespace nc::vfs;

[[clang::no_destroy]] static std::string g_LocalFTP = NCE(nc::env::test::ftp_qnap_nas_host);
[[clang::no_destroy]] static std::string g_LocalTestPath = "/Public/!FilesTesting/";

#define PREFIX "VFSFTP "

static std::string UUID()
{
    return [NSUUID.UUID UUIDString].UTF8String;
}

TEST_CASE(PREFIX "local ftp")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>(g_LocalFTP, "", "", "/"));

    const char *fn1 = "/System/Library/Kernels/kernel", *fn2 = "/Public/!FilesTesting/kernel";
    VFSStat stat;

    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2, stat, 0, 0) == 0 )
        REQUIRE(host->Unlink(fn2, 0) == 0);

    // copy file to remote server
    REQUIRE(VFSEasyCopyFile(fn1, TestEnv().vfs_native, fn2, host) == 0);
    int compare;

    // compare it with origin
    REQUIRE(VFSEasyCompareFiles(fn1, TestEnv().vfs_native, fn2, host, compare) == 0);
    REQUIRE(compare == 0);

    // check that it appeared in stat cache
    REQUIRE(host->Stat(fn2, stat, 0, 0) == 0);

    // delete it
    REQUIRE(host->Unlink(fn2, 0) == 0);
    REQUIRE(host->Unlink("/Public/!FilesTesting/wf8g2398fg239f6g23976fg79gads", 0) !=
            0); // also check deleting wrong entry

    // check that it is no longer available in stat cache
    REQUIRE(host->Stat(fn2, stat, 0, 0) != 0);
}

TEST_CASE(PREFIX "LocalFTP, empty file test")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>(g_LocalFTP, "", "", "/"));
    const char *fn = "/Public/!FilesTesting/empty_file";

    VFSStat stat;
    if( host->Stat(fn, stat, 0, 0) == 0 )
        REQUIRE(host->Unlink(fn, 0) == 0);

    VFSFilePtr file;
    REQUIRE(host->CreateFile(fn, file, 0) == 0);
    REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == 0);
    REQUIRE(file->IsOpened() == true);
    REQUIRE(file->Close() == 0);

    // sometimes this fail. mb caused by FTP server implementation (?)
    REQUIRE(host->Stat(fn, stat, 0, 0) == 0);
    REQUIRE(stat.size == 0);

    REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create | VFSFlags::OF_NoExist) != 0);
    REQUIRE(file->IsOpened() == false);

    REQUIRE(host->Unlink(fn, 0) == 0);
    REQUIRE(host->Stat(fn, stat, 0, 0) != 0);
}

TEST_CASE(PREFIX "LocalFTP, MKD RMD")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>(g_LocalFTP, "", "", "/"));
    for( auto dir :
         {g_LocalTestPath + UUID(),
          g_LocalTestPath + std::string(@"В лесу родилась елочка, В лесу она росла".UTF8String),
          g_LocalTestPath + std::string(@"北京市 >≥±§ 😱".UTF8String)} ) {
        REQUIRE(host->CreateDirectory(dir.c_str(), 0755, 0) == 0);
        REQUIRE(host->IsDirectory(dir.c_str(), 0, 0) == true);
        REQUIRE(host->RemoveDirectory(dir.c_str(), 0) == 0);
        REQUIRE(host->IsDirectory(dir.c_str(), 0, 0) == false);
    }

    for( auto dir : {g_LocalTestPath + "some / very / bad / filename",
                     std::string("/some/another/invalid/path")} ) {
        REQUIRE(host->CreateDirectory(dir.c_str(), 0755, 0) != 0);
        REQUIRE(host->IsDirectory(dir.c_str(), 0, 0) == false);
    }
}

TEST_CASE(PREFIX "LocalFTP, rename nas")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = make_shared<FTPHost>(g_LocalFTP, "", "", "/"));

    std::string fn1 = "/System/Library/Kernels/kernel", fn2 = g_LocalTestPath + "kernel",
                fn3 = g_LocalTestPath + "kernel34234234";

    VFSStat stat;

    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2.c_str(), stat, 0, 0) == 0 )
        REQUIRE(host->Unlink(fn2.c_str(), 0) == 0);

    REQUIRE(VFSEasyCopyFile(fn1.c_str(), TestEnv().vfs_native, fn2.c_str(), host) == 0);
    REQUIRE(host->Rename(fn2.c_str(), fn3.c_str(), 0) == 0);
    REQUIRE(host->Stat(fn3.c_str(), stat, 0, 0) == 0);
    REQUIRE(host->Unlink(fn3.c_str(), 0) == 0);

    if( host->Stat((g_LocalTestPath + "DirectoryName1").c_str(), stat, 0, 0) == 0 )
        REQUIRE(host->RemoveDirectory((g_LocalTestPath + "DirectoryName1").c_str(), 0) == 0);
    if( host->Stat((g_LocalTestPath + "DirectoryName2").c_str(), stat, 0, 0) == 0 )
        REQUIRE(host->RemoveDirectory((g_LocalTestPath + "DirectoryName2").c_str(), 0) == 0);

    REQUIRE(host->CreateDirectory((g_LocalTestPath + "DirectoryName1").c_str(), 0755, 0) == 0);
    REQUIRE(host->Rename((g_LocalTestPath + "DirectoryName1/").c_str(),
                         (g_LocalTestPath + "DirectoryName2/").c_str(),
                         0) == 0);
    REQUIRE(host->Stat((g_LocalTestPath + "DirectoryName2").c_str(), stat, 0, 0) == 0);
    REQUIRE(host->RemoveDirectory((g_LocalTestPath + "DirectoryName2").c_str(), 0) == 0);
}

TEST_CASE(PREFIX "listing - ftp.uk.debian.org", "[!mayfail]")
{
    auto path = "/debian/dists/Debian10.9/main/installer-i386/20190702/images/netboot/";
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("ftp.uk.debian.org", "", "", path, 21, true));
    std::set<std::string> should_be = {"debian-installer",
                                       "gtk",
                                       "pxelinux.cfg",
                                       "xen",
                                       "mini.iso",
                                       "netboot.tar.gz",
                                       "pxelinux.0"};
    std::set<std::string> in_fact;

    REQUIRE(host->IterateDirectoryListing(path, [&](const VFSDirEnt &_dirent) {
        in_fact.emplace(_dirent.name);
        return true;
    }) == 0);
    REQUIRE(should_be == in_fact);
}

TEST_CASE(PREFIX "seekread - ftp.uk.debian.org", "[!mayfail]")
{
    const auto host_name = "ftp.uk.debian.org";
    const auto host_dir = "/debian/dists/Debian10.9/main/installer-i386/20190702/images/netboot/";
    const auto host_path =
        "/debian/dists/Debian10.9/main/installer-i386/20190702/images/netboot/netboot.tar.gz";

    const auto offset = 0x1D79AC0;
    const auto length = 16;
    const auto expected = "\xFA\x34\x58\xB3\x1B\x51\x25\x14\xFD\x80\x87\xB0\x08\x7A\x08\x17";

    const auto host = std::make_shared<FTPHost>(host_name, "", "", host_dir, 21, true);

    // check seeking at big distance and reading an arbitrary selected known data block
    VFSFilePtr file;
    char buf[4096];
    REQUIRE(host->CreateFile(host_path, file, 0) == 0);
    REQUIRE(file->Open(VFSFlags::OF_Read) == 0);
    REQUIRE(file->Seek(offset, VFSFile::Seek_Set) == offset);
    REQUIRE(file->Read(buf, length) == length);
    REQUIRE(memcmp(buf, expected, length) == 0);
}

TEST_CASE(PREFIX "listing, redhat.com")
{
    auto path = "/redhat/dst2007/APPLICATIONS/";
    VFSHostPtr host = std::make_shared<FTPHost>("ftp.redhat.com", "", "", path);

    std::set<std::string> should_be = {"evolution",
                                       "evolution-data-server",
                                       "gcj",
                                       "IBMJava2-JRE",
                                       "IBMJava2-SDK",
                                       "java-1.4.2-bea",
                                       "java-1.4.2-ibm",
                                       "rhn_satellite_java_update"};
    std::set<std::string> in_fact;

    REQUIRE(host->IterateDirectoryListing(path, [&](const VFSDirEnt &_dirent) {
        in_fact.emplace(_dirent.name);
        return true;
    }) == 0);
    REQUIRE(should_be == in_fact);
}

TEST_CASE(PREFIX "big files reading cancellation", "[!mayfail]")
{
    const auto host_name = "ftp.uk.debian.org";
    const auto host_dir =
        "/debian/dists/Debian10.9/main/installer-i386/20190702/images/netboot/gtk/";
    const auto host_path =
        "/debian/dists/Debian10.9/main/installer-i386/20190702/images/netboot/gtk/mini.iso";

    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>(host_name, "", "", host_dir, 21, true));

    std::atomic_bool finished = false;
    std::thread([&] {
        VFSFilePtr file;
        char buf[256];
        REQUIRE(host->CreateFile(host_path, file, 0) == 0);
        REQUIRE(file->Open(VFSFlags::OF_Read) == 0);
        REQUIRE(file->Read(buf, sizeof(buf)) == sizeof(buf));
        REQUIRE(file->Close() == 0); // at this moment we have read only a small part of file
                                     // and Close() should tell curl to stop reading and will wait
                                     // for a pending operations to be finished
        finished = true;
    }).detach();

    const auto deadline = std::chrono::system_clock::now() + std::chrono::seconds(60);
    while( finished == false ) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        REQUIRE(std::chrono::system_clock::now() < deadline);
    }
}
