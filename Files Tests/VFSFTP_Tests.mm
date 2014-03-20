//
//  VFSFTP_Tests.c
//  Files
//
//  Created by Michael G. Kazakov on 20.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "tests_common.h"
#import "VFS.h"

static const char* g_Ftp_Mozilla_Org_Readme ="\n\
   ftp.mozilla.org / archive.mozilla.org - files are in /pub/mozilla.org\n\
\n\
   Notice: This server is the only place to obtain nightly builds and needs to\n\
   remain available to developers and testers. High bandwidth servers that\n\
   contain the public release files are available at ftp://releases.mozilla.org/\n\
   If you need to link to a public release, please link to the release server,\n\
   not here. Thanks!\n\
\n\
   Attempts to download high traffic release files from this server will get a\n\
   \"550 Permission denied.\" response.\n\
";

@interface VFSFTP_Tests : XCTestCase
@end

@implementation VFSFTP_Tests

- (void)testFtpMozillaOrg
{
    auto host = make_shared<VFSNetFTPHost>("ftp.mozilla.org");
    XCTAssert( host->Open("/", nullptr) == 0 );
    
    VFSStat stat;
    XCTAssert( host->Stat("/README", stat, 0, 0) == 0 );
    XCTAssert( stat.size == strlen(g_Ftp_Mozilla_Org_Readme) );

    VFSFilePtr file;
    // basic checks
    XCTAssert( host->CreateFile("/README", &file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) == 0 );
    XCTAssert( file->Size() == strlen(g_Ftp_Mozilla_Org_Readme) );
    NSData *data = file->ReadFile();
    XCTAssert( file->Eof() );
    XCTAssert( data != nil );
    XCTAssert( data.length == strlen(g_Ftp_Mozilla_Org_Readme) );
    XCTAssert( memcmp(data.bytes, g_Ftp_Mozilla_Org_Readme, data.length) == 0 );
    
    XCTAssert( file->Close() == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) == 0 );
    
    // check over-reading
    char buf[4096];
    XCTAssert( file->Read(buf, 4096) == strlen(g_Ftp_Mozilla_Org_Readme) );
    
    // check seeking
    XCTAssert( file->Seek(0x150, VFSFile::Seek_Set) == 0x150 );
    XCTAssert( file->Read(buf, 16) == 16 );
    XCTAssert( memcmp(buf, "a public release", 16) == 0 );
    XCTAssert( file->Seek(0, VFSFile::Seek_Set) == 0 );
    XCTAssert( file->Read(buf, 16) == 16 );
    XCTAssert( memcmp(buf, "\n   ftp.mozilla.", 16) == 0 );
    XCTAssert( file->Seek(0xFFFFFFF, VFSFile::Seek_Set) == strlen(g_Ftp_Mozilla_Org_Readme) );
    XCTAssert( file->Eof() );
    XCTAssert( file->Read(buf, 16) == 0 );
    
    // check seeking at big distance and reading an arbitrary selected known data block
    XCTAssert( host->CreateFile("/pub/firefox/releases/28.0b9/source/firefox-28.0b9.bundle", &file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) == 0 );    
    XCTAssert( file->Seek(0x23B0A820, VFSFile::Seek_Set) == 0x23B0A820 );
    XCTAssert( file->Read(buf, 16) == 16 );
    XCTAssert( memcmp(buf, "\x84\x62\x9d\xc0\x90\x38\xbb\x53\x23\xf1\xce\x45\x91\x74\x32\x2c", 16) == 0 );
    
    // check reaction on invalid requests
    XCTAssert( host->CreateFile("/iwuhdowgfuiwygfuiwgfuiwef", &file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) != 0 );
    XCTAssert( host->CreateFile("/pub", &file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) != 0 );
    XCTAssert( host->CreateFile("/pub/", &file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) != 0 );
    XCTAssert( host->CreateFile("/", &file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) != 0 );
}


@end

