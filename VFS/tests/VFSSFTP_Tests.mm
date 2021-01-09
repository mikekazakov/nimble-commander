// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "TestEnv.h"
#include <VFS/NetSFTP.h>
#include <Habanero/dispatch_cpp.h>
#include <Habanero/DispatchGroup.h>
#include "NCE.h"

using namespace nc::vfs;

#define PREFIX "VFSSFTP "

[[clang::no_destroy]] static const auto g_Keys =
    std::filesystem::path(NCE(nc::env::test::ext_data_prefix)) / "sftp";
static const auto g_QNAPNAS = NCE(nc::env::test::sftp_qnap_nas_host);
static const auto g_VBoxDebian7x86 = NCE(nc::env::test::sftp_vbox_debian_7x86_host);
static const auto g_VBoxDebian7x86User = NCE(nc::env::test::sftp_vbox_debian_7x86_user);
static const auto g_VBoxDebian7x86Passwd = NCE(nc::env::test::sftp_vbox_debian_7x86_passwd);
static const auto g_VBoxDebian7x86KeyPasswd = NCE(nc::env::test::sftp_vbox_debian_7x86_key_passwd);
static const auto g_VBoxDebian8x86 = NCE(nc::env::test::sftp_vbox_debian_8x86_host);
static const auto g_VBoxDebian8x86User = NCE(nc::env::test::sftp_vbox_debian_8x86_user);
static const auto g_VBoxDebian8x86Passwd = NCE(nc::env::test::sftp_vbox_debian_8x86_passwd);
static const auto g_VBoxUbuntu1404x64 = NCE(nc::env::test::sftp_vbox_ubuntu_1404x64_host);
static const auto g_VBoxUbuntu1404x64User = NCE(nc::env::test::sftp_vbox_ubuntu_1404x64_user);
static const auto g_VBoxUbuntu1404x64Passwd = NCE(nc::env::test::sftp_vbox_ubuntu_1404x64_passwd);
static const auto g_VBoxUbuntu1404x64KeyPasswd =
    NCE(nc::env::test::sftp_vbox_ubuntu_1404x64_key_passwd);

static VFSHostPtr hostForVBoxDebian7x86()
{
    return std::make_shared<SFTPHost>(
        g_VBoxDebian7x86, g_VBoxDebian7x86User, g_VBoxDebian7x86Passwd, "", -1);
}

static VFSHostPtr hostForVBoxDebian7x86WithPrivKey()
{
    return std::make_shared<SFTPHost>(g_VBoxDebian7x86,
                                      g_VBoxDebian7x86User,
                                      "",
                                      (g_Keys / "id_rsa_debian7x86_local_root").c_str(),
                                      -1);
}

static VFSHostPtr hostForVBoxDebian7x86WithPrivKeyPass()
{
    return std::make_shared<SFTPHost>(g_VBoxDebian7x86,
                                      g_VBoxDebian7x86User,
                                      g_VBoxDebian7x86KeyPasswd,
                                      (g_Keys / "id_rsa_debian7x86_local_root_qwerty").c_str(),
                                      -1);
}

static VFSHostPtr hostForVBoxDebian8x86()
{
    return std::make_shared<SFTPHost>(
        g_VBoxDebian8x86, g_VBoxDebian8x86User, g_VBoxDebian8x86Passwd, "");
}

static VFSHostPtr hostForVBoxUbuntu()
{
    return std::make_shared<SFTPHost>(
        g_VBoxUbuntu1404x64, g_VBoxUbuntu1404x64User, g_VBoxUbuntu1404x64Passwd, "");
}

static void TestBasicWithHost(VFSHostPtr host)
{
    VFSListingPtr listing;
    REQUIRE(host->FetchDirectoryListing("/", listing, 0, 0) == 0);

    if( !listing )
        return;

    auto has = [&](const std::string fn) {
        return std::find_if(std::begin(*listing), std::end(*listing), [&](const auto &v) {
                   return v.Filename() == fn;
               }) != std::end(*listing);
    };
    auto at = [&](const std::string fn) {
        return *std::find_if(std::begin(*listing), std::end(*listing), [&](const auto &v) {
            return v.Filename() == fn;
        });
    };

    REQUIRE(listing->Count() == 22);
    REQUIRE(has("bin"));
    REQUIRE(has("var"));
    REQUIRE(has("initrd.img"));
    REQUIRE(has("vmlinuz"));
    REQUIRE(at("bin").IsDir());

    // need to check symlinks
}

TEST_CASE(PREFIX "basic")
{
    TestBasicWithHost(hostForVBoxDebian7x86());
}

TEST_CASE(PREFIX "doesn't crash on many connections")
{
    auto host = hostForVBoxDebian7x86();

    // in this test VFS must simply not crash under this workload.
    // returning errors on this case is ok at the moment
    DispatchGroup grp;
    for( int i = 0; i < 100; ++i )
        grp.Run([&] {
            VFSStat st;
            host->Stat("/bin/cat", st, 0);
        });
    grp.Wait();
}

TEST_CASE(PREFIX "basic with private key")
{
    TestBasicWithHost(hostForVBoxDebian7x86WithPrivKey());
}

TEST_CASE(PREFIX "basic with private key pass")
{
    TestBasicWithHost(hostForVBoxDebian7x86WithPrivKeyPass());
}

TEST_CASE(PREFIX "invalid pwd for debian")
{
    REQUIRE_THROWS_AS(
        std::make_shared<SFTPHost>(g_VBoxDebian7x86, "wiufhiwhf", "u3hf8973h89fh", "", -1),
        VFSErrorException);
}

TEST_CASE(PREFIX "invalid pwd for NAS")
{
    REQUIRE_THROWS_AS(std::make_shared<SFTPHost>(g_QNAPNAS, "wiufhiwhf", "u3hf8973h89fh", "", -1),
                      VFSErrorException);
}

TEST_CASE(PREFIX "basic read")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = hostForVBoxDebian7x86());
    VFSFilePtr file;
    REQUIRE(host->CreateFile("/etc/debian_version", file, 0) == 0);
    REQUIRE(file->Open(VFSFlags::OF_Read) == 0);

    auto cont = file->ReadFile();

    REQUIRE(cont->size() == 4);
    REQUIRE(memcmp(cont->data(), "7.6\n", 4) == 0);
}

TEST_CASE(PREFIX "basic ubuntu 14.04")
{
    std::shared_ptr<SFTPHost> host;
    { // auth with private key
        REQUIRE_NOTHROW(host = std::make_shared<SFTPHost>(
                            g_VBoxUbuntu1404x64,
                            g_VBoxUbuntu1404x64User,
                            "",
                            (g_Keys / "id_rsa_ubuntu1404x64_local_r2d2").c_str()));
        REQUIRE(host->HomeDir() == "/home/r2d2");
    }

    { // auth with encrypted private key
        REQUIRE_NOTHROW(host = std::make_shared<SFTPHost>(
                            g_VBoxUbuntu1404x64,
                            g_VBoxUbuntu1404x64User,
                            g_VBoxUbuntu1404x64KeyPasswd,
                            (g_Keys / "id_rsa_ubuntu1404x64_local_r2d2_qwerty").c_str()));
        REQUIRE(host->HomeDir() == "/home/r2d2");
    }

    { // auth with encrypted private key / RSA4096
        REQUIRE_NOTHROW(host = std::make_shared<SFTPHost>(
                            g_VBoxUbuntu1404x64,
                            g_VBoxUbuntu1404x64User,
                            g_VBoxUbuntu1404x64KeyPasswd,
                            (g_Keys / "id_rsa_ubuntu1404x64_local_r2d2_qwerty_4096").c_str()));
        REQUIRE(host->HomeDir() == "/home/r2d2");
    }

    { // auth with encrypted private key / ECDSA
        REQUIRE_NOTHROW(host = std::make_shared<SFTPHost>(
                            g_VBoxUbuntu1404x64,
                            g_VBoxUbuntu1404x64User,
                            g_VBoxUbuntu1404x64KeyPasswd,
                            (g_Keys / "id_ecdsa_ubuntu1404x64_local_r2d2_qwerty").c_str()));
        REQUIRE(host->HomeDir() == "/home/r2d2");
    }

    { // auth with login-password pair
        REQUIRE_NOTHROW(
            host = std::make_shared<SFTPHost>(
                g_VBoxUbuntu1404x64, g_VBoxUbuntu1404x64User, g_VBoxUbuntu1404x64Passwd, ""));
        REQUIRE(host->HomeDir() == "/home/r2d2");
    }
}

TEST_CASE(PREFIX "SSH-less SFTP")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = hostForVBoxDebian8x86());

    VFSListingPtr listing;
    REQUIRE(host->FetchDirectoryListing("/", listing, 0, 0) == 0);

    if( !listing )
        return;

    auto has = [&](const std::string fn) {
        return std::find_if(std::begin(*listing), std::end(*listing), [&](const auto &v) {
                   return v.Filename() == fn;
               }) != std::end(*listing);
    };
    auto at = [&](const std::string fn) {
        return *std::find_if(std::begin(*listing), std::end(*listing), [&](const auto &v) {
            return v.Filename() == fn;
        });
    };

    REQUIRE(listing->Count() == 21);
    REQUIRE(has("bin"));
    REQUIRE(has("var"));
    REQUIRE(has("initrd.img"));
    REQUIRE(has("vmlinuz"));
    REQUIRE(at("bin").IsDir());

    VFSFilePtr file;
    REQUIRE(host->CreateFile("/etc/debian_version", file, 0) == 0);
    REQUIRE(file->Open(VFSFlags::OF_Read) == 0);

    auto cont = file->ReadFile();

    REQUIRE(cont->size() == 4);
    REQUIRE(memcmp(cont->data(), "8.4\n", 4) == 0);
}

TEST_CASE(PREFIX "read link")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = hostForVBoxDebian8x86());
    char link[MAXPATHLEN];
    const auto rc = host->ReadSymlink("/vmlinuz", link, sizeof(link));
    REQUIRE(rc == VFSError::Ok);
    REQUIRE(link == std::string_view("boot/vmlinuz-3.16.0-4-586"));
}

TEST_CASE(PREFIX "create link")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = hostForVBoxUbuntu());
    const auto lnk_path = "/home/r2d2/smtest";
    const auto createlink_rc = host->CreateSymlink(lnk_path, "/path/to/some/rubbish");
    REQUIRE(createlink_rc == VFSError::Ok);

    char link[MAXPATHLEN];
    const auto readlink_rc = host->ReadSymlink(lnk_path, link, sizeof(link));
    REQUIRE(readlink_rc == VFSError::Ok);
    REQUIRE(link == std::string_view("/path/to/some/rubbish"));

    REQUIRE(host->Unlink(lnk_path) == VFSError::Ok);
}

TEST_CASE(PREFIX "chmod")
{
    VFSHostPtr host;
    REQUIRE_NOTHROW(host = hostForVBoxUbuntu());
    const auto path = "/home/r2d2/chmodtest";

    REQUIRE(VFSEasyCreateEmptyFile(path, host) == VFSError::Ok);
    VFSStat st;
    REQUIRE(host->Stat(path, st, 0) == VFSError::Ok);
    REQUIRE(st.mode_bits.xusr == 0);

    st.mode_bits.xusr = 1;
    REQUIRE(host->SetPermissions(path, st.mode) == VFSError::Ok);

    memset(&st, 0, sizeof(st));
    REQUIRE(host->Stat(path, st, 0) == VFSError::Ok);
    REQUIRE(st.mode_bits.xusr == 1);

    REQUIRE(host->Unlink(path) == VFSError::Ok);
}

TEST_CASE(PREFIX "chown")
{
    VFSHostPtr host;

    REQUIRE_NOTHROW(host = hostForVBoxDebian7x86());

    const auto path = "/root/chowntest";

    REQUIRE(VFSEasyCreateEmptyFile(path, host) == VFSError::Ok);
    VFSStat st;
    REQUIRE(host->Stat(path, st, 0) == VFSError::Ok);

    const auto new_uid = st.uid + 1;
    const auto new_gid = st.gid + 1;
    REQUIRE(host->SetOwnership(path, new_uid, new_gid) == VFSError::Ok);

    REQUIRE(host->Stat(path, st, 0) == VFSError::Ok);
    REQUIRE(st.uid == new_uid);
    REQUIRE(st.gid == new_gid);

    REQUIRE(host->Unlink(path) == VFSError::Ok);
}

// I had a weird behavior of ssh, which return a permission error when reading past end-of-file.
// That behvaiour occured in VFSSeqToRandomWrapper
TEST_CASE(PREFIX "RandomWrappers")
{
    // auth with encrypted private key / ECDSA
    auto host =
        std::make_shared<SFTPHost>(g_VBoxUbuntu1404x64,
                                   g_VBoxUbuntu1404x64User,
                                   g_VBoxUbuntu1404x64KeyPasswd,
                                   (g_Keys / "id_ecdsa_ubuntu1404x64_local_r2d2_qwerty").c_str());

    VFSFilePtr seq_file;
    REQUIRE(host->CreateFile((host->HomeDir() + "/.ssh/authorized_keys").c_str(), seq_file, 0) ==
            VFSError::Ok);

    auto wrapper = std::make_shared<VFSSeqToRandomROWrapperFile>(seq_file);
    REQUIRE(wrapper->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock, nullptr, nullptr) ==
            VFSError::Ok);
}
