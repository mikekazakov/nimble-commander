// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "tests_common.h"
#include <VFS/NetSFTP.h>
#include <Habanero/dispatch_cpp.h>
#include <Habanero/DispatchGroup.h>

using namespace nc::vfs;
using namespace std;
using boost::filesystem::path;

[[clang::no_destroy]] static const path g_Keys = path(NCE(nc::env::test::ext_data_prefix)) / "sftp";
static const auto g_QNAPNAS                     = NCE(nc::env::test::sftp_qnap_nas_host);
static const auto g_VBoxDebian7x86              = NCE(nc::env::test::sftp_vbox_debian_7x86_host);
static const auto g_VBoxDebian7x86User          = NCE(nc::env::test::sftp_vbox_debian_7x86_user);
static const auto g_VBoxDebian7x86Passwd        = NCE(nc::env::test::sftp_vbox_debian_7x86_passwd);
static const auto g_VBoxDebian7x86KeyPasswd     = NCE(nc::env::test::sftp_vbox_debian_7x86_key_passwd);
static const auto g_VBoxDebian8x86              = NCE(nc::env::test::sftp_vbox_debian_8x86_host);
static const auto g_VBoxDebian8x86User          = NCE(nc::env::test::sftp_vbox_debian_8x86_user);
static const auto g_VBoxDebian8x86Passwd        = NCE(nc::env::test::sftp_vbox_debian_8x86_passwd);
static const auto g_VBoxUbuntu1404x64           = NCE(nc::env::test::sftp_vbox_ubuntu_1404x64_host);
static const auto g_VBoxUbuntu1404x64User       = NCE(nc::env::test::sftp_vbox_ubuntu_1404x64_user);
static const auto g_VBoxUbuntu1404x64Passwd     = NCE(nc::env::test::sftp_vbox_ubuntu_1404x64_passwd);
static const auto g_VBoxUbuntu1404x64KeyPasswd  = NCE(nc::env::test::sftp_vbox_ubuntu_1404x64_key_passwd);

@interface VFSSFTP_Tests : XCTestCase
@end

@implementation VFSSFTP_Tests

- (VFSHostPtr) hostForVBoxDebian7x86
{
    return make_shared<SFTPHost>(g_VBoxDebian7x86,
                                 g_VBoxDebian7x86User,
                                 g_VBoxDebian7x86Passwd,
                                 "",
                                 -1);
}

- (VFSHostPtr) hostForVBoxDebian7x86WithPrivKey
{
    return make_shared<SFTPHost>(g_VBoxDebian7x86,
                                 g_VBoxDebian7x86User,
                                 "",
                                 (g_Keys/"id_rsa_debian7x86_local_root").c_str(),
                                 -1);
}

- (VFSHostPtr) hostForVBoxDebian7x86WithPrivKeyPass
{
    return make_shared<SFTPHost>(g_VBoxDebian7x86,
                                 g_VBoxDebian7x86User,
                                 g_VBoxDebian7x86KeyPasswd,
                                 (g_Keys/"id_rsa_debian7x86_local_root_qwerty").c_str(),
                                 -1);
}

- (VFSHostPtr) hostForVBoxDebian8x86
{
    return make_shared<SFTPHost>(g_VBoxDebian8x86,
                                 g_VBoxDebian8x86User,
                                 g_VBoxDebian8x86Passwd,
                                 "");
}

- (VFSHostPtr) hostForVBoxUbuntu
{
    return make_shared<SFTPHost>(g_VBoxUbuntu1404x64,
                                 g_VBoxUbuntu1404x64User,
                                 g_VBoxUbuntu1404x64Passwd,
                                 "");
}

- (void)testBasicWithHost:(VFSHostPtr)host
{
    VFSListingPtr listing;
    XCTAssert( host->FetchDirectoryListing("/", listing, 0, 0) == 0);
    
    if(!listing)
        return;
    
    auto has = [&](const string fn) {
        return find_if( begin(*listing), end(*listing), [&](const auto &v) {
            return v.Filename() == fn;
        }) != end(*listing);
    };
    auto at = [&](const string fn) {
        return *find_if( begin(*listing), end(*listing), [&](const auto &v) {
            return v.Filename() == fn;
        });
    };
    
    XCTAssert( listing->Count() == 22 );
    XCTAssert( has("bin") );
    XCTAssert( has("var") );
    XCTAssert( has("initrd.img") );
    XCTAssert( has("vmlinuz") );
    XCTAssert( at("bin").IsDir() );

    // need to check symlinks
}

- (void)testBasic
{
    try
    {
        [self testBasicWithHost:self.hostForVBoxDebian7x86];
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testCrashOnManyConnections
{
    auto host = self.hostForVBoxDebian7x86;

    // in this test VFS must simply not crash under this workload.
    // returning errors on this case is ok at the moment
    DispatchGroup grp;
    for( int i =0; i < 100; ++i)
        grp.Run( [&]{
            VFSStat st;
            host->Stat("/bin/cat", st, 0);
        });
    grp.Wait();
}

- (void)testBasicWithPrivateKey
{
    [self testBasicWithHost:self.hostForVBoxDebian7x86WithPrivKey];
}

- (void)testBasicWithPrivateKeyPass
{
    [self testBasicWithHost:self.hostForVBoxDebian7x86WithPrivKeyPass];
}

- (void)testInvalidPWD_Debian
{
    try {
        make_shared<SFTPHost>(g_VBoxDebian7x86,
                              "wiufhiwhf",
                              "u3hf8973h89fh",
                              "",
                              -1);
        XCTAssert( false );
    } catch ( VFSErrorException &e ) {
        XCTAssert( e.code() != 0 );
    }
}

- (void)testInvalidPWD_NAS
{
    try {
        make_shared<SFTPHost>(g_QNAPNAS,
                              "wiufhiwhf",
                              "u3hf8973h89fh",
                              "",
                              -1);
        XCTAssert( false );
    } catch ( VFSErrorException &e ) {
        XCTAssert( e.code() != 0 );
    }
}

- (void) testBasicRead {
    VFSHostPtr host;
    try
    {
        host = self.hostForVBoxDebian7x86;
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    VFSFilePtr file;
    XCTAssert( host->CreateFile("/etc/debian_version", file, 0) == 0);
    XCTAssert( file->Open( VFSFlags::OF_Read ) == 0);
    
    auto cont = file->ReadFile();
    
    XCTAssert( cont->size() == 4 );
    XCTAssert( memcmp(cont->data(), "7.6\n", 4) == 0);
    
    file->Close();
}

- (void) testBasicUbuntu1404
{
    try { // auth with private key
        auto host = make_shared<SFTPHost>(g_VBoxUbuntu1404x64,
                                    g_VBoxUbuntu1404x64User,
                                    "",
                                    (g_Keys/"id_rsa_ubuntu1404x64_local_r2d2").c_str());
        XCTAssert( host->HomeDir() == "/home/r2d2" );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
    
    try { // auth with encrypted private key
        auto host = make_shared<SFTPHost>(g_VBoxUbuntu1404x64,
                                          g_VBoxUbuntu1404x64User,
                                          g_VBoxUbuntu1404x64KeyPasswd,
                                          (g_Keys/"id_rsa_ubuntu1404x64_local_r2d2_qwerty").c_str());
    XCTAssert( host->HomeDir() == "/home/r2d2" );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }

    try { // auth with encrypted private key / RSA4096
        auto host = make_shared<SFTPHost>(g_VBoxUbuntu1404x64,
                                          g_VBoxUbuntu1404x64User,
                                          g_VBoxUbuntu1404x64KeyPasswd,
                                          (g_Keys/"id_rsa_ubuntu1404x64_local_r2d2_qwerty_4096").c_str());
    XCTAssert( host->HomeDir() == "/home/r2d2" );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }

    try { // auth with encrypted private key / ECDSA
        auto host = make_shared<SFTPHost>(g_VBoxUbuntu1404x64,
                                          g_VBoxUbuntu1404x64User,
                                          g_VBoxUbuntu1404x64KeyPasswd,
                                          (g_Keys/"id_ecdsa_ubuntu1404x64_local_r2d2_qwerty").c_str());
    XCTAssert( host->HomeDir() == "/home/r2d2" );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
    
    try { // auth with login-password pair
        auto host = make_shared<SFTPHost>(g_VBoxUbuntu1404x64,
                                          g_VBoxUbuntu1404x64User,
                                          g_VBoxUbuntu1404x64Passwd,
                                          "");
        XCTAssert( host->HomeDir() == "/home/r2d2" );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }

}

- (void) testSSHlessSFTP
{
    try
    {
        auto host = self.hostForVBoxDebian8x86;
        
        VFSListingPtr listing;
        XCTAssert( host->FetchDirectoryListing("/", listing, 0, 0) == 0);
        
        if(!listing)
            return;
        
        auto has = [&](const string fn) {
            return find_if( begin(*listing), end(*listing), [&](const auto &v) {
                return v.Filename() == fn;
            }) != end(*listing);
        };
        auto at = [&](const string fn) {
            return *find_if( begin(*listing), end(*listing), [&](const auto &v) {
                return v.Filename() == fn;
            });
        };
        
        XCTAssert( listing->Count() == 21 );
        XCTAssert( has("bin") );
        XCTAssert( has("var") );
        XCTAssert( has("initrd.img") );
        XCTAssert( has("vmlinuz") );
        XCTAssert( at("bin").IsDir() );
        
        
        VFSFilePtr file;
        XCTAssert( host->CreateFile("/etc/debian_version", file, 0) == 0);
        XCTAssert( file->Open( VFSFlags::OF_Read ) == 0);
        
        auto cont = file->ReadFile();
        
        XCTAssert( cont->size() == 4 );
        XCTAssert( memcmp(cont->data(), "8.4\n", 4) == 0);
        
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void) testReadLink
{
    try
    {
        const auto host = self.hostForVBoxDebian8x86;
        char link[MAXPATHLEN];
        const auto rc = host->ReadSymlink("/vmlinuz", link, sizeof(link));
        XCTAssert( rc == VFSError::Ok );
        XCTAssert( link == "boot/vmlinuz-3.16.0-4-586"s );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testCreateLink
{
    try
    {
        const VFSHostPtr host = self.hostForVBoxUbuntu;
        const auto lnk_path = "/home/r2d2/smtest";
        const auto createlink_rc = host->CreateSymlink(lnk_path,
                                                       "/path/to/some/rubbish");
        XCTAssert( createlink_rc == VFSError::Ok );
        
        char link[MAXPATHLEN];
        const auto readlink_rc = host->ReadSymlink(lnk_path, link, sizeof(link));
        XCTAssert( readlink_rc == VFSError::Ok );
        XCTAssert( link == "/path/to/some/rubbish"s );
        
        XCTAssert( host->Unlink(lnk_path) == VFSError::Ok );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testChmod
{
    try
    {
        const auto host = self.hostForVBoxUbuntu;
        const auto path = "/home/r2d2/chmodtest";

        XCTAssert( VFSEasyCreateEmptyFile(path, host) == VFSError::Ok );
        VFSStat st;
        XCTAssert( host->Stat(path, st, 0) == VFSError::Ok );
        XCTAssert( st.mode_bits.xusr == 0 );

        st.mode_bits.xusr = 1;
        XCTAssert( host->SetPermissions(path, st.mode) == VFSError::Ok );
        
        memset( &st, 0, sizeof(st) );        
        XCTAssert( host->Stat(path, st, 0) == VFSError::Ok );
        XCTAssert( st.mode_bits.xusr == 1 );
        
        XCTAssert( host->Unlink(path) == VFSError::Ok );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testChown
{
    try
    {
        const auto host = self.hostForVBoxDebian7x86;
        const auto path = "/root/chowntest";

        XCTAssert( VFSEasyCreateEmptyFile(path, host) == VFSError::Ok );
        VFSStat st;
        XCTAssert( host->Stat(path, st, 0) == VFSError::Ok );
        
        const auto new_uid = st.uid + 1;
        const auto new_gid = st.gid + 1;
        XCTAssert( host->SetOwnership(path, new_uid, new_gid) == VFSError::Ok );
        
        XCTAssert( host->Stat(path, st, 0) == VFSError::Ok );
        XCTAssert( st.uid == new_uid );
        XCTAssert( st.gid == new_gid );
        
        XCTAssert( host->Unlink(path) == VFSError::Ok );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

// I had a weird behavior of ssh, which return a permission error when reading past end-of-file.
// That behvaiour occured in VFSSeqToRandomWrapper
- (void)testRandomWrapper
{
    try { // auth with encrypted private key / ECDSA
        auto host = make_shared<SFTPHost>(g_VBoxUbuntu1404x64,
                                          g_VBoxUbuntu1404x64User,
                                          g_VBoxUbuntu1404x64KeyPasswd,
                                          (g_Keys/"id_ecdsa_ubuntu1404x64_local_r2d2_qwerty").c_str());
                                          
        VFSFilePtr seq_file;
        XCTAssert( host->CreateFile( (host->HomeDir() + "/.ssh/authorized_keys").c_str(), seq_file, 0) == VFSError::Ok);
        
        auto wrapper = std::make_shared<VFSSeqToRandomROWrapperFile>(seq_file);
        XCTAssert( wrapper->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock, nullptr, nullptr) == VFSError::Ok );
                                          
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

@end
