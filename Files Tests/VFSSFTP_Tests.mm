//
//  VFSSFTP_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 25/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "tests_common.h"
#import "VFS.h"
#import "PanelData.h"

static const auto g_QNAPNAS             = "192.168.2.5";
static const auto g_VBoxDebian7x86      = "debian7x86.local";
static const auto g_VBoxUbuntu1404x64   = "192.168.2.171";

@interface VFSSFTP_Tests : XCTestCase
@end

@implementation VFSSFTP_Tests

- (VFSHostPtr) hostForVBoxDebian7x86
{
    return make_shared<VFSNetSFTPHost>(g_VBoxDebian7x86,
                                       "root",
                                       "123456",
                                       "",
                                       -1);
}

- (VFSHostPtr) hostForVBoxDebian7x86WithPrivKey
{
    return make_shared<VFSNetSFTPHost>(g_VBoxDebian7x86,
                                       "root",
                                       "",
                                       "/.FilesTestingData/sftp/id_rsa_debian7x86_local_root",
                                       -1);
}

- (VFSHostPtr) hostForVBoxDebian7x86WithPrivKeyPass
{
    return make_shared<VFSNetSFTPHost>(g_VBoxDebian7x86,
                                       "root",
                                       "qwerty",
                                       "/.FilesTestingData/sftp/id_rsa_debian7x86_local_root_qwerty",
                                       -1);
}

- (void)testBasicWithHost:(VFSHostPtr)host
{
    VFSListingPtr listing;
    XCTAssert( host->FetchFlexibleListing("/", listing, 0, 0) == 0);
    
    if(!listing)
        return;
    
    PanelData data;
    data.Load(listing);
    XCTAssert( data.Listing().Count() == 22);
    XCTAssert( "bin"s == data.EntryAtSortPosition(0).Name() );
    XCTAssert( "var"s == data.EntryAtSortPosition(19).Name() );
    XCTAssert( "initrd.img"s == data.EntryAtSortPosition(20).Name() );
    XCTAssert( "vmlinuz"s == data.EntryAtSortPosition(21).Name() );
    
    XCTAssert( data.EntryAtSortPosition(0).IsDir() );
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
        make_shared<VFSNetSFTPHost>(g_VBoxDebian7x86,
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
        make_shared<VFSNetSFTPHost>(g_QNAPNAS,
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
        auto host = make_shared<VFSNetSFTPHost>(g_VBoxUbuntu1404x64,
                                    "r2d2",
                                    "",
                                    "/.FilesTestingData/sftp/id_rsa_ubuntu1404x64_local_r2d2");
        XCTAssert( host->HomeDir() == "/home/r2d2" );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
    
    try { // auth with encrypted private key
        auto host = make_shared<VFSNetSFTPHost>(g_VBoxUbuntu1404x64,
                                                "r2d2",
                                                "qwerty",
                                                "/.FilesTestingData/sftp/id_rsa_ubuntu1404x64_local_r2d2_qwerty");
    XCTAssert( host->HomeDir() == "/home/r2d2" );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }

    
    try { // auth with login-password pair
        auto host = make_shared<VFSNetSFTPHost>(g_VBoxUbuntu1404x64,
                                                "r2d2",
                                                "r2d2",
                                                "");
        XCTAssert( host->HomeDir() == "/home/r2d2" );
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }

}



@end
