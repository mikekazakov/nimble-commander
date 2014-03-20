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
    char buf[4096];
    XCTAssert( file->Read(buf, 4096) == strlen(g_Ftp_Mozilla_Org_Readme) );
    
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

