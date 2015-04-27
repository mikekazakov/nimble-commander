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

@interface VFSSFTP_Tests : XCTestCase
@end

@implementation VFSSFTP_Tests

- (shared_ptr<VFSNetSFTPHost>) hostVBoxDebian7x86 {
    return make_shared<VFSNetSFTPHost>("debian7x86.local");
}

- (shared_ptr<VFSNetSFTPHost>) hostVBoxUbuntu1404x64 {
    return make_shared<VFSNetSFTPHost>("192.168.2.171");
}

- (VFSNetSFTPOptions) optionsForVBoxDebian7x86 {
    VFSNetSFTPOptions opts;
    opts.user = "root";
    opts.passwd = "123456";
    opts.port = -1;
    return opts;
}

- (VFSNetSFTPOptions) optionsForVBoxDebian7x86_PrivKey {
    VFSNetSFTPOptions opts;
    opts.user = "root";
    opts.passwd = "";
    opts.keypath = "/.FilesTestingData/sftp/id_rsa_debian7x86_local_root";
    return opts;
}

- (VFSNetSFTPOptions) optionsForVBoxDebian7x86_PrivKeyPass {
    VFSNetSFTPOptions opts;
    opts.user = "root";
    opts.passwd = "qwerty";
    opts.keypath = "/.FilesTestingData/sftp/id_rsa_debian7x86_local_root_qwerty";
    return opts;
}

- (void)testBasicWithOpts:(VFSNetSFTPOptions)_opts
{
    auto host = self.hostVBoxDebian7x86;
    XCTAssert( host->Open(_opts) == 0);
    
    XCTAssert( host->HomeDir() == "/root" );
    
    shared_ptr<VFSListing> listing;
    XCTAssert( host->FetchDirectoryListing("/", &listing, 0, 0) == 0);
    
    if(!listing)
        return;
    
    PanelData data;
    data.Load(listing);
    XCTAssert( data.DirectoryEntries().Count() == 22);
    XCTAssert( "bin"s == data.EntryAtSortPosition(0)->Name() );
    XCTAssert( "var"s == data.EntryAtSortPosition(19)->Name() );
    XCTAssert( "initrd.img"s == data.EntryAtSortPosition(20)->Name() );
    XCTAssert( "vmlinuz"s == data.EntryAtSortPosition(21)->Name() );
    
    XCTAssert( data.EntryAtSortPosition(0)->IsDir() );
    // need to check symlinks
}

- (void)testBasic
{
    [self testBasicWithOpts:self.optionsForVBoxDebian7x86];
}

- (void)testBasicWithPrivateKey
{
    [self testBasicWithOpts:self.optionsForVBoxDebian7x86_PrivKey];
}

- (void)testBasicWithPrivateKeyPass
{
    [self testBasicWithOpts:self.optionsForVBoxDebian7x86_PrivKeyPass];
}

- (void) testBasicRead {
    auto host = self.hostVBoxDebian7x86;
    XCTAssert( host->Open(self.optionsForVBoxDebian7x86) == 0);
    
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
    { // auth with private key
        VFSNetSFTPOptions opts;
        opts.user = "r2d2";
        opts.keypath = "/.FilesTestingData/sftp/id_rsa_ubuntu1404x64_local_r2d2";
        auto host = self.hostVBoxUbuntu1404x64;
        XCTAssert( host->Open(opts) == 0);
        XCTAssert( host->HomeDir() == "/home/r2d2" );
    }
    
    { // auth with encrypted private key
    VFSNetSFTPOptions opts;
    opts.user = "r2d2";
    opts.passwd = "qwerty";
    opts.keypath = "/.FilesTestingData/sftp/id_rsa_ubuntu1404x64_local_r2d2_qwerty";
    auto host = self.hostVBoxUbuntu1404x64;
    XCTAssert( host->Open(opts) == 0);
    XCTAssert( host->HomeDir() == "/home/r2d2" );
    }
    
    { // auth with login-password pair
        VFSNetSFTPOptions opts;
        opts.user = "r2d2";
        opts.passwd = "r2d2";
        auto host = self.hostVBoxUbuntu1404x64;
        XCTAssert( host->Open(opts) == 0);
        XCTAssert( host->HomeDir() == "/home/r2d2" );
    }
}



@end
