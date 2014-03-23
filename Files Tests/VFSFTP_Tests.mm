//
//  VFSFTP_Tests.c
//  Files
//
//  Created by Michael G. Kazakov on 20.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "tests_common.h"
#import "VFS.h"



@interface VFSFTP_Tests : XCTestCase
@end

@implementation VFSFTP_Tests

- (void)testFtpMozillaOrg
{
static const char* readme ="\n\
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
    
    auto host = make_shared<VFSNetFTPHost>("ftp.mozilla.org");
    XCTAssert( host->Open("/", nullptr) == 0 );
    
    VFSStat stat;
    XCTAssert( host->Stat("/README", stat, 0, 0) == 0 );
    XCTAssert( stat.size == strlen(readme) );

    VFSFilePtr file;
    // basic checks
    XCTAssert( host->CreateFile("/README", file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) == 0 );
    XCTAssert( file->Size() == strlen(readme) );
    auto data = file->ReadFile();
    XCTAssert( file->Eof() );
    XCTAssert( data != nullptr );
    XCTAssert( data->size() == strlen(readme) );
    XCTAssert( memcmp(data->data(), readme, data->size()) == 0 );
    
    XCTAssert( file->Close() == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) == 0 );
    
    // check over-reading
    char buf[4096];
    XCTAssert( file->Read(buf, 4096) == strlen(readme) );
    
    // check seeking
    XCTAssert( file->Seek(0x150, VFSFile::Seek_Set) == 0x150 );
    XCTAssert( file->Read(buf, 16) == 16 );
    XCTAssert( memcmp(buf, "a public release", 16) == 0 );
    XCTAssert( file->Seek(0, VFSFile::Seek_Set) == 0 );
    XCTAssert( file->Read(buf, 16) == 16 );
    XCTAssert( memcmp(buf, "\n   ftp.mozilla.", 16) == 0 );
    XCTAssert( file->Seek(0xFFFFFFF, VFSFile::Seek_Set) == strlen(readme) );
    XCTAssert( file->Eof() );
    XCTAssert( file->Read(buf, 16) == 0 );
    
    // check seeking at big distance and reading an arbitrary selected known data block
    XCTAssert( host->CreateFile("/pub/firefox/releases/28.0b9/source/firefox-28.0b9.bundle", file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) == 0 );    
    XCTAssert( file->Seek(0x23B0A820, VFSFile::Seek_Set) == 0x23B0A820 );
    XCTAssert( file->Read(buf, 16) == 16 );
    XCTAssert( memcmp(buf, "\x84\x62\x9d\xc0\x90\x38\xbb\x53\x23\xf1\xce\x45\x91\x74\x32\x2c", 16) == 0 );
    
    // check reaction on invalid requests
    XCTAssert( host->CreateFile("/iwuhdowgfuiwygfuiwgfuiwef", file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) != 0 );
    XCTAssert( host->CreateFile("/pub", file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) != 0 );
    XCTAssert( host->CreateFile("/pub/", file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) != 0 );
    XCTAssert( host->CreateFile("/", file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Read) != 0 );
}

- (void)test192_168_2_5
{
    auto host = make_shared<VFSNetFTPHost>("192.168.2.5");
    XCTAssert( host->Open("/", nullptr) == 0 );
    
    const char *fn1 = "/mach_kernel",
               *fn2 = "/Public/!FilesTesting/mach_kernel";
    VFSStat stat;

//OF_NoExist
    
    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2, stat, 0, 0) == 0)
        XCTAssert( host->Unlink(fn2, 0) == 0);
    
    // copy file to remote server
    XCTAssert( VFSEasyCopyFile(fn1, VFSNativeHost::SharedHost(), fn2, host) == 0);
    int compare;

    // compare it with origin
    XCTAssert( VFSEasyCompareFiles(fn1, VFSNativeHost::SharedHost(), fn2, host, compare) == 0);
    XCTAssert( compare == 0);
    
    // check that it appeared in stat cache
    XCTAssert( host->Stat(fn2, stat, 0, 0) == 0);
    
    // delete it
    XCTAssert( host->Unlink(fn2, 0) == 0);
    XCTAssert( host->Unlink("/Public/!FilesTesting/wf8g2398fg239f6g23976fg79gads", 0) != 0); // also check deleting wrong entry
    
    // check that it is no longer available in stat cache
    XCTAssert( host->Stat(fn2, stat, 0, 0) != 0);
}

- (void)test192_168_2_5_EmptyFileTest
{
    auto host = make_shared<VFSNetFTPHost>("192.168.2.5");
    XCTAssert( host->Open("/", nullptr) == 0 );
    const char *fn = "/Public/!FilesTesting/empty_file";

    VFSStat stat;
    if( host->Stat(fn, stat, 0, 0) == 0 )
        XCTAssert( host->Unlink(fn, 0) == 0 );
    
    VFSFilePtr file;
    XCTAssert( host->CreateFile(fn, file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Write | VFSFile::OF_Create) == 0 );
    XCTAssert( file->IsOpened() == true );
    XCTAssert( file->Close() == 0);

    // sometimes this fail. mb caused by FTP server implementation (?)
    XCTAssert( host->Stat(fn, stat, 0, 0) == 0);
    XCTAssert( stat.size == 0);
    
    XCTAssert( file->Open(VFSFile::OF_Write | VFSFile::OF_Create | VFSFile::OF_NoExist) != 0 );
    XCTAssert( file->IsOpened() == false );
    
    XCTAssert( host->Unlink(fn, 0) == 0 );
    XCTAssert( host->Stat(fn, stat, 0, 0) != 0);
}

- (void)test192_168_2_5_AppendTest
{
    auto host = make_shared<VFSNetFTPHost>("192.168.2.5");
    XCTAssert( host->Open("/", nullptr) == 0 );
    const char *fn = "/Public/!FilesTesting/append.txt";

    VFSStat stat;
    if( host->Stat(fn, stat, 0, 0) == 0 )
        XCTAssert( host->Unlink(fn, 0) == 0 );

    VFSFilePtr file;
    const char *str = "Hello World!\n";
    const char *str2= "Underworld!\n";
    XCTAssert( host->CreateFile(fn, file, 0) == 0 );
    XCTAssert( file->Open(VFSFile::OF_Write | VFSFile::OF_Create) == 0 );
    XCTAssert( file->Write(str, strlen(str)) == strlen(str) );
    XCTAssert( file->Close() == 0 );

    XCTAssert( file->Open(VFSFile::OF_Write | VFSFile::OF_Append) == 0 );
    XCTAssert( file->Size() == strlen(str) );
    XCTAssert( file->Pos() == strlen(str) );
    XCTAssert( file->Write(str, strlen(str)) == strlen(str) );
    XCTAssert( file->Close() == 0 );
    
    XCTAssert( host->Stat(fn, stat, 0, 0) == 0 );
    XCTAssert( stat.size == strlen(str)*2 );
    
    XCTAssert( file->Open(VFSFile::OF_Write) == 0 );
    XCTAssert( file->Size() == 0 ); // implicitly truncating for FTP uploads
    XCTAssert( file->Pos() == 0 );
    XCTAssert( file->Write(str2, strlen(str2)) == strlen(str2) );
    XCTAssert( file->Close() == 0);
    
    XCTAssert( file->Open(VFSFile::OF_Read) == 0 );
    char buf[4096];
    XCTAssert( file->Read(buf, 409) == strlen(str2) );
    XCTAssert( memcmp(buf, str2, strlen(str2)) == 0 );
}

@end

