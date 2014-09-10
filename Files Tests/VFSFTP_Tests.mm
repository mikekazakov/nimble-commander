//
//  VFSFTP_Tests.c
//  Files
//
//  Created by Michael G. Kazakov on 20.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "tests_common.h"
#import "VFS.h"

static string g_LocalFTP = "192.168.2.5";
static string g_LocalTestPath = "/Public/!FilesTesting/";

static string UUID()
{
    return [NSUUID.UUID UUIDString].UTF8String;
}

@interface VFSFTP_Tests : XCTestCase
@end

@implementation VFSFTP_Tests

- (void)testFtpMozillaOrg
{
static const char* readme = "\n\
   ftp.mozilla.org / archive.mozilla.org - files are in /pub/mozilla.org\n\
\n\
   releases.mozilla.org now points to our CDN distribution network and no longer works for FTP traffic\n\
";
    
    auto host = make_shared<VFSNetFTPHost>("ftp.mozilla.org");
    XCTAssert( host->Open("/") == 0 );
    
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
    XCTAssert( file->Seek(0x50, VFSFile::Seek_Set) == 0x50 );
    XCTAssert( file->Read(buf, 16) == 16 );
    XCTAssert( memcmp(buf, "leases.mozilla.o", 16) == 0 );
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
    XCTAssert( host->Open("/") == 0 );
    
    const char *fn1 = "/System/Library/Kernels/kernel",
               *fn2 = "/Public/!FilesTesting/kernel";
    VFSStat stat;
    
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

- (void)test127_0_0_1
{
    VFSNetFTPOptions opts;
    opts.user = "r2d2";
    opts.passwd = "r2d2";
    
    auto host = make_shared<VFSNetFTPHost>("127.0.0.1");
    XCTAssert( host->Open("/", opts) == 0 );
    
    const char *fn1 = "/System/Library/Kernels/kernel",
    *fn2 = "/kernel";
    VFSStat stat;
    
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
    XCTAssert( host->Open("/") == 0 );
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

// thanks to QNAP weird firmware update - it's ftp server stop overwriting files and began to appending them always
// so currently using OSX Server built-in ftp.
- (void)test127_0_0_1_AppendTest
{
    VFSNetFTPOptions opts;
    opts.user = "r2d2";
    opts.passwd = "r2d2";
    
//    auto host = make_shared<VFSNetFTPHost>("192.168.2.5");
    auto host = make_shared<VFSNetFTPHost>("127.0.0.1");
    
    XCTAssert( host->Open("/", opts) == 0 );
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
    
    XCTAssert( file->Open(VFSFile::OF_Write) == 0 ); // should implicitly truncating for FTP uploads
    XCTAssert( file->Size() == 0 );
    XCTAssert( file->Pos() == 0 );
    XCTAssert( file->Write(str2, strlen(str2)) == strlen(str2) );
    XCTAssert( file->Close() == 0);
    
    XCTAssert( host->Stat(fn, stat, 0, 0) == 0 );
    XCTAssert( stat.size == strlen(str2) );
    
    XCTAssert( file->Open(VFSFile::OF_Read) == 0 );
    char buf[4096];
    XCTAssert( file->Read(buf, 4096) == strlen(str2) );
    XCTAssert( memcmp(buf, str2, strlen(str2)) == 0 );
}

- (void) testLocal_MKD_RMD
{
    auto host = make_shared<VFSNetFTPHost>(g_LocalFTP.c_str());
    XCTAssert( host->Open("/") == 0 );
    for(auto dir: {g_LocalTestPath + UUID(),
                   g_LocalTestPath + string(@"В лесу родилась елочка, В лесу она росла".UTF8String),
                   g_LocalTestPath + string(@"北京市 >≥±§ 😱".UTF8String)
        })
    {
        XCTAssert( host->CreateDirectory(dir.c_str(), 0755, 0) == 0 );
        XCTAssert( host->IsDirectory(dir.c_str(), 0, 0) == true );
        XCTAssert( host->RemoveDirectory(dir.c_str(), 0) == 0 );
        XCTAssert( host->IsDirectory(dir.c_str(), 0, 0) == false );
    }
    
    for(auto dir: {g_LocalTestPath + "some / very / bad / filename",
                   string("/some/another/invalid/path")
        })
    {
        XCTAssert( host->CreateDirectory(dir.c_str(), 0755, 0) != 0 );
        XCTAssert( host->IsDirectory(dir.c_str(), 0, 0) == false );
    }
}

- (void) testLocal_Rename_NAS
{
    auto host = make_shared<VFSNetFTPHost>(g_LocalFTP.c_str());
    XCTAssert( host->Open("/") == 0 );
    
    string fn1 = "/System/Library/Kernels/kernel", fn2 = g_LocalTestPath + "kernel", fn3 = g_LocalTestPath + "kernel34234234";
    
    VFSStat stat;
    
    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2.c_str(), stat, 0, 0) == 0)
        XCTAssert( host->Unlink(fn2.c_str(), 0) == 0);
    
    XCTAssert( VFSEasyCopyFile(fn1.c_str(), VFSNativeHost::SharedHost(), fn2.c_str(), host) == 0);
    XCTAssert( host->Rename(fn2.c_str(), fn3.c_str(), 0) == 0);
    XCTAssert( host->Stat(fn3.c_str(), stat, 0, 0) == 0);
    XCTAssert( host->Unlink(fn3.c_str(), 0) == 0);


    if( host->Stat((g_LocalTestPath + "DirectoryName1").c_str(), stat, 0, 0) == 0)
        XCTAssert( host->RemoveDirectory((g_LocalTestPath + "DirectoryName1").c_str(), 0) == 0);
    if( host->Stat((g_LocalTestPath + "DirectoryName2").c_str(), stat, 0, 0) == 0)
        XCTAssert( host->RemoveDirectory((g_LocalTestPath + "DirectoryName2").c_str(), 0) == 0);
    
    XCTAssert( host->CreateDirectory((g_LocalTestPath + "DirectoryName1").c_str(), 0755, 0) == 0);
    XCTAssert( host->Rename((g_LocalTestPath + "DirectoryName1/").c_str(),
                            (g_LocalTestPath + "DirectoryName2/").c_str(),
                            0) == 0);
    XCTAssert( host->Stat((g_LocalTestPath + "DirectoryName2").c_str(), stat, 0, 0) == 0);
    XCTAssert( host->RemoveDirectory((g_LocalTestPath + "DirectoryName2").c_str(), 0) == 0);
}

- (void) testLocal_Rename_127001
{
    VFSNetFTPOptions opts;
    opts.user = "r2d2";    
    opts.passwd = "r2d2";

    auto host = make_shared<VFSNetFTPHost>("127.0.0.1");
    XCTAssert( host->Open("/", opts) == 0 );
    
    string fn1 = "/System/Library/Kernels/kernel", fn2 = "/kernel", fn3 = "/kernel34234234";
    
    VFSStat stat;
    
    // if there's a trash from previous runs - remove it
    if( host->Stat(fn2.c_str(), stat, 0, 0) == 0)
        XCTAssert( host->Unlink(fn2.c_str(), 0) == 0);
    
    XCTAssert( VFSEasyCopyFile(fn1.c_str(), VFSNativeHost::SharedHost(), fn2.c_str(), host) == 0);
    XCTAssert( host->Rename(fn2.c_str(), fn3.c_str(), 0) == 0);
    XCTAssert( host->Stat(fn3.c_str(), stat, 0, 0) == 0);
    XCTAssert( host->Unlink(fn3.c_str(), 0) == 0);
    
    if( host->Stat("/DirectoryName1", stat, 0, 0) == 0)
        XCTAssert( host->RemoveDirectory("/DirectoryName1", 0) == 0);
    if( host->Stat("/DirectoryName2", stat, 0, 0) == 0)
        XCTAssert( host->RemoveDirectory("/DirectoryName2", 0) == 0);
    
    XCTAssert( host->CreateDirectory("/DirectoryName1", 0640, 0) == 0);
    XCTAssert( host->Rename("/DirectoryName1/", "/DirectoryName2/", 0) == 0);
    XCTAssert( host->Stat("/DirectoryName2", stat, 0, 0) == 0);
    XCTAssert( host->RemoveDirectory("/DirectoryName2", 0) == 0);
}

- (void)testListing_Mozilla_Org
{
    auto path = "/pub/camino/";
    auto host = make_shared<VFSNetFTPHost>("ftp.mozilla.org");
    XCTAssert( host->Open(path) == 0 );

    set<string> should_be = {"nightly", "releases", "source", "tinderbox-builds"};
    __block set<string> in_fact;
    
    XCTAssert( host->IterateDirectoryListing(path, ^bool(const VFSDirEnt &_dirent) {
            in_fact.emplace(_dirent.name);
            return true;
        }) == 0);
    XCTAssert(should_be == in_fact);
}

- (void)testListing_Microsoft_Com
{
    auto path = "/developr/fortran/";
    auto host = make_shared<VFSNetFTPHost>("ftp.microsoft.com");
    XCTAssert( host->Open(path) == 0 );
    
    set<string> should_be = {"KB", "public", "unsup-ed", "README.TXT", "ReadMe1.txt"};
    __block set<string> in_fact;
    
    XCTAssert( host->IterateDirectoryListing(path, ^bool(const VFSDirEnt &_dirent) {
        in_fact.emplace(_dirent.name);
        return true;
    }) == 0);
    XCTAssert(should_be == in_fact);
}

- (void)testBigFilesReadingCancellation
{
    path path = "/pub/diskimages/Firefox1.0.iso";
    auto host = make_shared<VFSNetFTPHost>("ftp.mozilla.org");
    XCTAssert( host->Open(path.parent_path().c_str()) == 0 );
  
    __block bool finished = false;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        VFSFilePtr file;
        char buf[256];
        XCTAssert( host->CreateFile(path.c_str(), file, 0) == 0 );
        XCTAssert( file->Open(VFSFile::OF_Read) == 0 );
        XCTAssert( file->Read(buf, sizeof(buf)) == sizeof(buf) );
        XCTAssert( file->Close() == 0 ); // at this moment we have read only a small part of file
                                         // and Close() should tell curl to stop reading and will wait for a pending operations to be finished
        finished = true;
    });
    
    [self waitUntilFinish:finished];
}

- (void) waitUntilFinish:(volatile bool&)_finished
{
    microseconds sleeped = 0us, sleep_tresh = 60s;
    while (!_finished)
    {
        this_thread::sleep_for(100us);
        sleeped += 100us;
        XCTAssert( sleeped < sleep_tresh);
        if(sleeped > sleep_tresh)
            break;
    }
}

@end

