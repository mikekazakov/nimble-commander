// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/NetFTP.h>
#include <VFS/Native.h>
#include <Base/UUID.h>
#include <set>
#include <thread>

using namespace nc::vfs;

#define PREFIX "VFSFTP "

TEST_CASE(PREFIX "just connect")
{
    REQUIRE_NOTHROW(std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
    REQUIRE_THROWS(std::make_shared<FTPHost>("127.0.0.1", "wronguser", "ftpuserpasswd", "/", 9021));
    REQUIRE_THROWS(std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "wronguserpasswd", "/", 9021));
}

TEST_CASE(PREFIX "upload and compare")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));

    const char *fn1 = "/System/Library/Kernels/kernel", *fn2 = "/kernel";
    VFSStat stat;

    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2, stat, 0, 0) == 0 )
        REQUIRE(host->Unlink(fn2, 0) == 0);

    // copy file to the remote server
    REQUIRE(VFSEasyCopyFile(fn1, TestEnv().vfs_native, fn2, host) == 0);

    // compare it with origin
    int compare = 0;
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

TEST_CASE(PREFIX "empty file test")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
    const char *fn = "/empty_file";

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

TEST_CASE(PREFIX "MKD RMD")
{
    VFSHostPtr host, shadowhost;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
    REQUIRE_NOTHROW(shadowhost = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
    for( const auto &dir : std::vector<std::string>{"/" + nc::base::UUID::Generate().ToString(),
                                                    "/В лесу родилась елочка, В лесу она росла",
                                                    "/北京市 >≥±§ 😱"} ) {
        REQUIRE(host->CreateDirectory(dir.c_str(), 0755) == 0);
        REQUIRE(host->IsDirectory(dir.c_str(), 0) == true);                              // cached
        REQUIRE(shadowhost->IsDirectory(dir.c_str(), VFSFlags::F_ForceRefresh) == true); // non-cached
        REQUIRE(host->RemoveDirectory(dir.c_str()) == 0);
        REQUIRE(host->IsDirectory(dir.c_str(), 0) == false);                              // cached
        REQUIRE(shadowhost->IsDirectory(dir.c_str(), VFSFlags::F_ForceRefresh) == false); // non-cached
    }

    {
        REQUIRE(host->CreateDirectory("", 0755) != 0);
        REQUIRE(host->CreateDirectory("Hello, world!", 0755) != 0);
        REQUIRE(host->CreateDirectory("/", 0755) != 0);
        REQUIRE(host->CreateDirectory("/", 0755) != 0);
    }
    {
        REQUIRE(host->RemoveDirectory("/") != 0);
        REQUIRE(host->RemoveDirectory("") != 0);
        REQUIRE(host->RemoveDirectory("/") != 0);
        REQUIRE(host->RemoveDirectory("//") != 0);
        REQUIRE(host->RemoveDirectory("///") != 0);
        REQUIRE(host->RemoveDirectory("////") != 0);
        REQUIRE(host->RemoveDirectory("/I don't even exist") != 0);
        REQUIRE(host->RemoveDirectory("/I don't even exist/////") != 0);
        REQUIRE(host->RemoveDirectory("/I don't even exist/me too!") != 0);
        REQUIRE(host->RemoveDirectory("/I don't even exist/me too///!") != 0);
    }

    {
        REQUIRE(host->CreateDirectory("/First", 0755) == 0);
        REQUIRE(shadowhost->IsDirectory("/First", VFSFlags::F_ForceRefresh)); // non-cached
        REQUIRE(host->CreateDirectory("/First/Second", 0755) == 0);
        REQUIRE(shadowhost->IsDirectory("/First/Second", VFSFlags::F_ForceRefresh)); // non-cached
        REQUIRE(host->CreateDirectory("/First/Second/Третий", 0755) == 0);
        REQUIRE(shadowhost->IsDirectory("/First/Second/Третий", VFSFlags::F_ForceRefresh)); // non-cached
        REQUIRE(host->CreateDirectory("/First/Second/Третий/🤡", 0755) == 0);
        REQUIRE(shadowhost->IsDirectory("/First/Second/Третий/🤡", VFSFlags::F_ForceRefresh)); // non-cached

        REQUIRE(host->RemoveDirectory("/First/Second/Третий/🤡") == 0);
        REQUIRE(shadowhost->IsDirectory("/First/Second/Третий/🤡", VFSFlags::F_ForceRefresh) == false); // non-cached
        REQUIRE(host->RemoveDirectory("/First/Second/Третий") == 0);
        REQUIRE(shadowhost->IsDirectory("/First/Second/Третий", VFSFlags::F_ForceRefresh) == false); // non-cached
        REQUIRE(host->RemoveDirectory("/First/Second") == 0);
        REQUIRE(shadowhost->IsDirectory("/First/Second", VFSFlags::F_ForceRefresh) == false); // non-cached
        REQUIRE(host->RemoveDirectory("/First") == 0);
        REQUIRE(shadowhost->IsDirectory("/First", VFSFlags::F_ForceRefresh) == false); // non-cached
    }

    for( const auto &dir : std::vector<std::string>{
             "/some / very / bad / filename", "/some/another/invalid/path", "not even an absolute path"} ) {
        REQUIRE(host->CreateDirectory(dir.c_str(), 0755) != 0);
        REQUIRE(host->IsDirectory(dir.c_str(), 0) == false);
        REQUIRE(shadowhost->IsDirectory(dir.c_str(), VFSFlags::F_ForceRefresh) == false); // non-cached
    }
}

TEST_CASE(PREFIX "renaming")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));

    std::string fn1 = "/System/Library/Kernels/kernel", fn2 = "/kernel", fn3 = "/kernel34234234";

    VFSStat stat;

    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2.c_str(), stat, 0) == 0 )
        REQUIRE(host->Unlink(fn2.c_str()) == 0);

    REQUIRE(VFSEasyCopyFile(fn1.c_str(), TestEnv().vfs_native, fn2.c_str(), host) == 0);
    REQUIRE(host->Rename(fn2.c_str(), fn3.c_str()) == 0);
    REQUIRE(host->Stat(fn3.c_str(), stat, 0) == 0);
    REQUIRE(host->Unlink(fn3.c_str()) == 0);

    if( host->Stat("/DirectoryName1", stat, 0) == 0 )
        REQUIRE(host->RemoveDirectory("/DirectoryName1") == 0);
    if( host->Stat("/DirectoryName2", stat, 0) == 0 )
        REQUIRE(host->RemoveDirectory("/DirectoryName2") == 0);

    REQUIRE(host->CreateDirectory("/DirectoryName1", 0755) == 0);
    REQUIRE(host->Rename("/DirectoryName1", "/DirectoryName2") == 0);
    REQUIRE(host->Stat("/DirectoryName2", stat, 0) == 0);
    REQUIRE(host->CreateDirectory("/DirectoryName2/SomethingElse", 0755) == 0);
    REQUIRE(host->Rename("/DirectoryName2/SomethingElse", "/DirectoryName2/SomethingEvenElse") == 0);
    REQUIRE(host->RemoveDirectory("/DirectoryName2/SomethingEvenElse") == 0);
    REQUIRE(host->RemoveDirectory("/DirectoryName2") == 0);
}

TEST_CASE(PREFIX "listing, redhat.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("ftp.redhat.com", "", "", "/"));

    std::set<std::string> filenames;
    REQUIRE(host->IterateDirectoryListing("/redhat/dst2007/APPLICATIONS/", [&](const VFSDirEnt &_dirent) {
        filenames.emplace(_dirent.name);
        return true;
    }) == 0);
    REQUIRE(filenames == std::set<std::string>{"evolution",
                                               "evolution-data-server",
                                               "gcj",
                                               "IBMJava2-JRE",
                                               "IBMJava2-SDK",
                                               "java-1.4.2-bea",
                                               "java-1.4.2-ibm",
                                               "rhn_satellite_java_update"});
}

TEST_CASE(PREFIX "seekread, redhat.com")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("ftp.redhat.com", "", "", "/"));

    // check seeking at big distance and reading an arbitrary selected known data block
    constexpr auto offset = 0x170CE00;
    constexpr auto length = 16;
    constexpr auto expected = "\x90\xFF\x7F\xEA\x11\xAA\xEE\x0E\x9A\x2E\xD6\x6E\xC6\x26\x76\xE6";
    constexpr auto fn =
        "/redhat/dst2007/APPLICATIONS/rhn_satellite_java_update/dst-4.0-4AS/java-1.4.2-ibm-1.4.2.7-1jpp.4.el4.i386.rpm";
    VFSFilePtr file;
    char buf[length];
    REQUIRE(host->CreateFile(fn, file, 0) == 0);
    REQUIRE(file->Open(VFSFlags::OF_Read) == 0);
    REQUIRE(file->Seek(offset, VFSFile::Seek_Set) == offset);
    REQUIRE(file->Read(buf, length) == length);
    REQUIRE(memcmp(buf, expected, length) == 0);
}

TEST_CASE(PREFIX "big files reading cancellation", "[!mayfail]")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("ftp.redhat.com", "", "", "/"));

    const auto host_path =
        "/redhat/dst2007/APPLICATIONS/rhn_satellite_java_update/dst-4.0-4AS/java-1.4.2-ibm-1.4.2.7-1jpp.4.el4.i386.rpm";

    std::atomic_bool finished = false;
    std::thread th{[&] {
        VFSFilePtr file;
        char buf[256];
        REQUIRE(host->CreateFile(host_path, file, 0) == 0);
        REQUIRE(file->Open(VFSFlags::OF_Read) == 0);
        REQUIRE(file->Read(buf, sizeof(buf)) == sizeof(buf));
        REQUIRE(file->Close() == 0); // at this moment we have read only a small part of file
        // and Close() should tell curl to stop reading and will wait
        // for a pending operations to be finished
        finished = true;
    }};

    const auto deadline = std::chrono::system_clock::now() + std::chrono::seconds(60);
    while( finished == false ) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        REQUIRE(std::chrono::system_clock::now() < deadline);
    }
    th.join();
}
