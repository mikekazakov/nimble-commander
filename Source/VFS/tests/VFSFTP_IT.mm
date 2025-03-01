// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
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

    const char *fn1 = "/System/Library/Kernels/kernel";
    const char *fn2 = "/kernel";

    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2, 0) )
        REQUIRE(host->Unlink(fn2));

    // copy file to the remote server
    REQUIRE(VFSEasyCopyFile(fn1, TestEnv().vfs_native, fn2, host) == 0);

    // compare it with origin
    REQUIRE(VFSEasyCompareFiles(fn1, TestEnv().vfs_native, fn2, host) == 0);

    // check that it appeared in stat cache
    REQUIRE(host->Stat(fn2, 0));

    // delete it
    REQUIRE(host->Unlink(fn2));
    REQUIRE(!host->Unlink("/Public/!FilesTesting/wf8g2398fg239f6g23976fg79gads")); // also check deleting wrong entry

    // check that it is no longer available in stat cache
    REQUIRE(!host->Stat(fn2, 0));
}

TEST_CASE(PREFIX "empty file test")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
    const char *fn = "/empty_file";

    if( host->Stat(fn, 0) )
        REQUIRE(host->Unlink(fn));

    const VFSFilePtr file = host->CreateFile(fn).value();
    REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == 0);
    REQUIRE(file->IsOpened() == true);
    REQUIRE(file->Close() == 0);

    // sometimes this fail. mb caused by FTP server implementation (?)
    const VFSStat stat = host->Stat(fn, 0).value();
    REQUIRE(stat.size == 0);

    REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create | VFSFlags::OF_NoExist) != 0);
    REQUIRE(file->IsOpened() == false);

    REQUIRE(host->Unlink(fn));
    REQUIRE(!host->Stat(fn, 0));
}

TEST_CASE(PREFIX "MKD RMD")
{
    VFSHostPtr host;
    VFSHostPtr shadowhost;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
    REQUIRE_NOTHROW(shadowhost = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
    for( const auto &dir : std::vector<std::string>{"/" + nc::base::UUID::Generate().ToString(),
                                                    "/В лесу родилась елочка, В лесу она росла",
                                                    "/北京市 >≥±§ 😱"} ) {
        REQUIRE(host->CreateDirectory(dir, 0755));
        REQUIRE(host->IsDirectory(dir, 0) == true);                              // cached
        REQUIRE(shadowhost->IsDirectory(dir, VFSFlags::F_ForceRefresh) == true); // non-cached
        REQUIRE(host->RemoveDirectory(dir));
        REQUIRE(host->IsDirectory(dir, 0) == false);                              // cached
        REQUIRE(shadowhost->IsDirectory(dir, VFSFlags::F_ForceRefresh) == false); // non-cached
    }

    {
        REQUIRE(!host->CreateDirectory("", 0755));
        REQUIRE(!host->CreateDirectory("Hello, world!", 0755));
        REQUIRE(!host->CreateDirectory("/", 0755));
        REQUIRE(!host->CreateDirectory("/", 0755));
    }
    {
        REQUIRE(!host->RemoveDirectory(""));
        REQUIRE(!host->RemoveDirectory("/"));
        REQUIRE(!host->RemoveDirectory("//"));
        REQUIRE(!host->RemoveDirectory("///"));
        REQUIRE(!host->RemoveDirectory("////"));
        REQUIRE(!host->RemoveDirectory("/I don't even exist"));
        REQUIRE(!host->RemoveDirectory("/I don't even exist/////"));
        REQUIRE(!host->RemoveDirectory("/I don't even exist/me too!"));
        REQUIRE(!host->RemoveDirectory("/I don't even exist/me too///!"));
    }

    {
        REQUIRE(host->CreateDirectory("/First", 0755));
        REQUIRE(shadowhost->IsDirectory("/First", VFSFlags::F_ForceRefresh)); // non-cached
        REQUIRE(host->CreateDirectory("/First/Second", 0755));
        REQUIRE(shadowhost->IsDirectory("/First/Second", VFSFlags::F_ForceRefresh)); // non-cached
        REQUIRE(host->CreateDirectory("/First/Second/Третий", 0755));
        REQUIRE(shadowhost->IsDirectory("/First/Second/Третий", VFSFlags::F_ForceRefresh)); // non-cached
        REQUIRE(host->CreateDirectory("/First/Second/Третий/🤡", 0755));
        REQUIRE(shadowhost->IsDirectory("/First/Second/Третий/🤡", VFSFlags::F_ForceRefresh)); // non-cached

        REQUIRE(host->RemoveDirectory("/First/Second/Третий/🤡"));
        REQUIRE(shadowhost->IsDirectory("/First/Second/Третий/🤡", VFSFlags::F_ForceRefresh) == false); // non-cached
        REQUIRE(host->RemoveDirectory("/First/Second/Третий"));
        REQUIRE(shadowhost->IsDirectory("/First/Second/Третий", VFSFlags::F_ForceRefresh) == false); // non-cached
        REQUIRE(host->RemoveDirectory("/First/Second"));
        REQUIRE(shadowhost->IsDirectory("/First/Second", VFSFlags::F_ForceRefresh) == false); // non-cached
        REQUIRE(host->RemoveDirectory("/First"));
        REQUIRE(shadowhost->IsDirectory("/First", VFSFlags::F_ForceRefresh) == false); // non-cached
    }

    for( const auto &dir : std::vector<std::string>{
             "/some / very / bad / filename", "/some/another/invalid/path", "not even an absolute path"} ) {
        REQUIRE(!host->CreateDirectory(dir, 0755));
        REQUIRE(host->IsDirectory(dir, 0) == false);
        REQUIRE(shadowhost->IsDirectory(dir, VFSFlags::F_ForceRefresh) == false); // non-cached
    }
}

TEST_CASE(PREFIX "renaming")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));

    const std::string fn1 = "/System/Library/Kernels/kernel";
    const std::string fn2 = "/kernel";
    const std::string fn3 = "/kernel34234234";

    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2, 0) )
        REQUIRE(host->Unlink(fn2));

    REQUIRE(VFSEasyCopyFile(fn1.c_str(), TestEnv().vfs_native, fn2.c_str(), host) == 0);
    REQUIRE(host->Rename(fn2, fn3));
    REQUIRE(host->Stat(fn3, 0));
    REQUIRE(host->Unlink(fn3));

    if( host->Stat("/DirectoryName1", 0) )
        REQUIRE(host->RemoveDirectory("/DirectoryName1"));
    if( host->Stat("/DirectoryName2", 0) )
        REQUIRE(host->RemoveDirectory("/DirectoryName2"));

    REQUIRE(host->CreateDirectory("/DirectoryName1", 0755));
    REQUIRE(host->Rename("/DirectoryName1", "/DirectoryName2"));
    REQUIRE(host->Stat("/DirectoryName2", 0));
    REQUIRE(host->CreateDirectory("/DirectoryName2/SomethingElse", 0755));
    REQUIRE(host->Rename("/DirectoryName2/SomethingElse", "/DirectoryName2/SomethingEvenElse"));
    REQUIRE(host->RemoveDirectory("/DirectoryName2/SomethingEvenElse"));
    REQUIRE(host->RemoveDirectory("/DirectoryName2"));
}

TEST_CASE(PREFIX "listing")
{
    {
        // Create the context to check with a separate instance of FTPHost to not have any cached state.
        VFSHostPtr host;
        REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
        std::ignore = VFSEasyDelete("/Test", host);
        auto touch = [&](const char *_path) {
            const VFSFilePtr file = host->CreateFile(_path).value();
            REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == 0);
        };
        REQUIRE(host->CreateDirectory("/Test", 0755));
        REQUIRE(host->CreateDirectory("/Test/DirectoryName1", 0755));
        REQUIRE(host->CreateDirectory("/Test/DirectoryName2", 0755));
        REQUIRE(host->CreateDirectory("/Test/DirectoryName3", 0755));
        REQUIRE(host->CreateDirectory("/Test/DirectoryName4", 0755));
        touch("/Test/FileName1.txt");
        touch("/Test/FileName2.txt");
        touch("/Test/FileName3.txt");
        touch("/Test/FileName4.txt");
    }
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
    const std::set<std::string> expected_filenames = {"DirectoryName1",
                                                      "DirectoryName2",
                                                      "DirectoryName3",
                                                      "DirectoryName4",
                                                      "FileName1.txt",
                                                      "FileName2.txt",
                                                      "FileName3.txt",
                                                      "FileName4.txt"};
    std::set<std::string> filenames;
    REQUIRE(host->IterateDirectoryListing("/Test/", [&](const VFSDirEnt &_dirent) {
        filenames.emplace(_dirent.name);
        return true;
    }));
    REQUIRE(filenames == expected_filenames);
    std::ignore = VFSEasyDelete("/Test", host);
}

static void WriteAll(VFSFile &_file, const std::span<const uint8_t> _bytes)
{
    ssize_t write_left = _bytes.size();
    const uint8_t *buf = _bytes.data();
    while( write_left > 0 ) {
        const ssize_t res = _file.Write(buf, write_left);
        REQUIRE(res >= 0);
        write_left -= res;
        buf += res;
    }
}

TEST_CASE(PREFIX "seekread")
{
    {
        // Create the context to check with a separate instance of FTPHost to not have any cached state.
        VFSHostPtr host;
        REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
        std::ignore = VFSEasyDelete("/TestSeekRead", host);

        constexpr size_t sz = 50'000'000;
        std::vector<uint8_t> bytes(sz);
        for( size_t i = 0; i < sz; ++i )
            bytes[i] = static_cast<uint8_t>(i & 0xFF);

        REQUIRE(host->CreateDirectory("/TestSeekRead", 0755));
        const VFSFilePtr file = host->CreateFile("/TestSeekRead/blob").value();
        REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == 0);
        WriteAll(*file, bytes);
        REQUIRE(file->Close() == 0);
    }

    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));

    constexpr auto fn = "/TestSeekRead/blob";
    const VFSFilePtr file = host->CreateFile(fn).value();
    REQUIRE(file->Open(VFSFlags::OF_Read) == 0);

    struct TC {
        uint64_t offset;
        std::vector<uint8_t> expected;
    } const tcs[] = {
        {.offset = 0x2E0F077,
         .expected = {0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86}},
        {.offset = 0x0000001, .expected = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08}},
        {.offset = 0x000000A, .expected = {0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F}},
        {.offset = 0x0000000, .expected = {0x00}},
        {.offset = 0x0000000, .expected = {}},
        {.offset = 0x0123456, .expected = {0x56, 0x57, 0x58}},
        {.offset = 0x123F077,
         .expected = {0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86}},
    };

    for( auto &tc : tcs ) {
        std::vector<uint8_t> buf(tc.expected.size());
        REQUIRE(file->Seek(tc.offset, VFSFile::Seek_Set) == static_cast<int64_t>(tc.offset));
        REQUIRE(file->Read(buf.data(), tc.expected.size()) == static_cast<int64_t>(tc.expected.size()));
        REQUIRE(buf == tc.expected);
    }

    std::ignore = VFSEasyDelete("/TestSeekRead", host);
}

TEST_CASE(PREFIX "big files reading cancellation")
{
    {
        // Create the context to check with a separate instance of FTPHost to not have any cached state.
        VFSHostPtr host;
        REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
        std::ignore = VFSEasyDelete("/TestCancellation", host);

        constexpr size_t sz = 200'000'000;
        std::vector<uint8_t> bytes(sz);
        for( size_t i = 0; i < sz; ++i )
            bytes[i] = static_cast<uint8_t>(i & 0xFF);

        REQUIRE(host->CreateDirectory("/TestCancellation", 0755));
        const VFSFilePtr file = host->CreateFile("/TestCancellation/blob").value();
        REQUIRE(file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == 0);
        WriteAll(*file, bytes);
        REQUIRE(file->Close() == 0);
    }

    VFSHostPtr host;
    REQUIRE_NOTHROW(host = std::make_shared<FTPHost>("127.0.0.1", "ftpuser", "ftpuserpasswd", "/", 9021));
    const auto host_path = "/TestCancellation/blob";
    std::atomic_bool finished = false;
    std::thread th{[&] {
        char buf[256];
        const VFSFilePtr file = host->CreateFile(host_path).value();
        REQUIRE(file->Open(VFSFlags::OF_Read) == 0);
        REQUIRE(file->Read(buf, sizeof(buf)) == sizeof(buf));
        REQUIRE(file->Close() == 0); // at this moment we have read only a small part of file
        // and Close() should tell curl to stop reading and will wait
        // for a pending operations to be finished
        finished = true;
    }};

    const auto deadline = std::chrono::system_clock::now() + std::chrono::seconds(1);
    while( !finished ) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        REQUIRE((std::chrono::system_clock::now() < deadline));
    }
    th.join();
    std::ignore = VFSEasyDelete("/TestCancellation", host);
}
