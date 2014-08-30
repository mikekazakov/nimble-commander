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

- (VFSNetSFTPOptions) optionsForVBoxDebian7x86 {
    VFSNetSFTPOptions opts;
    opts.user = "root";
    opts.passwd = "123456";
    opts.port = -1;
    return opts;
}

- (void)testBasic {
    auto host = self.hostVBoxDebian7x86;
    XCTAssert( host->Open(self.optionsForVBoxDebian7x86) == 0);
    
    XCTAssert( host->HomeDir() == "/root" );
    
    shared_ptr<VFSListing> listing;
    XCTAssert( host->FetchDirectoryListing("/", &listing, 0, 0) == 0);
    
    PanelData data;
    data.Load(listing);
    XCTAssert( data.DirectoryEntries().Count() == 22);
    XCTAssert( string("bin") == data.EntryAtSortPosition(0)->Name() );
    XCTAssert( string("var") == data.EntryAtSortPosition(19)->Name() );
    XCTAssert( string("initrd.img") == data.EntryAtSortPosition(20)->Name() );
    XCTAssert( string("vmlinuz") == data.EntryAtSortPosition(21)->Name() );
    
    XCTAssert( data.EntryAtSortPosition(0)->IsDir() );
    // need to check symlinks
}

- (void) testBasicRead {
    auto host = self.hostVBoxDebian7x86;
    XCTAssert( host->Open(self.optionsForVBoxDebian7x86) == 0);
    
    VFSFilePtr file;
    XCTAssert( host->CreateFile("/etc/debian_version", file, 0) == 0);
    XCTAssert( file->Open( VFSFile::OF_Read ) == 0);
    
    auto cont = file->ReadFile();
    
    XCTAssert( cont->size() == 4 );
    XCTAssert( memcmp(cont->data(), "7.6\n", 4) == 0);
    
    file->Close();
}

@end
