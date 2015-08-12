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
    static const char* readme = "The contents of ftp://ftp.mozilla.org has moved to http://archive.mozilla.org\n";
    
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("ftp.mozilla.org", "", "", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    VFSStat stat;
    XCTAssert( host->Stat("/README", stat, 0, 0) == 0 );
    XCTAssert( stat.size == strlen(readme) );

    VFSFilePtr file;
    // basic checks
    XCTAssert( host->CreateFile("/README", file, 0) == 0 );
    XCTAssert( file->Open(VFSFlags::OF_Read) == 0 );
    XCTAssert( file->Size() == strlen(readme) );
    auto data = file->ReadFile();
    XCTAssert( file->Eof() );
    XCTAssert( data != nullptr );
    XCTAssert( data->size() == strlen(readme) );
    XCTAssert( memcmp(data->data(), readme, data->size()) == 0 );
    
    XCTAssert( file->Close() == 0 );
    XCTAssert( file->Open(VFSFlags::OF_Read) == 0 );
    
    // check over-reading
    char buf[4096];
    XCTAssert( file->Read(buf, 4096) == strlen(readme) );
    
    // check seeking
    XCTAssert( file->Seek(0x30, VFSFile::Seek_Set) == 0x30 );
    XCTAssert( file->Read(buf, 16) == 16 );
    XCTAssert( memcmp(buf, "to http://archiv", 16) == 0 );
    XCTAssert( file->Seek(0, VFSFile::Seek_Set) == 0 );
    XCTAssert( file->Read(buf, 16) == 16 );
    XCTAssert( memcmp(buf, "The contents of ", 14) == 0 );
    XCTAssert( file->Seek(0xFFFFFFF, VFSFile::Seek_Set) == strlen(readme) );
    XCTAssert( file->Eof() );
    XCTAssert( file->Read(buf, 16) == 0 );
    
    // check reaction on invalid requests
    XCTAssert( host->CreateFile("/iwuhdowgfuiwygfuiwgfuiwef", file, 0) == 0 );
    XCTAssert( file->Open(VFSFlags::OF_Read) != 0 );
    XCTAssert( host->CreateFile("/pub", file, 0) == 0 );
    XCTAssert( file->Open(VFSFlags::OF_Read) != 0 );
    XCTAssert( host->CreateFile("/pub/", file, 0) == 0 );
    XCTAssert( file->Open(VFSFlags::OF_Read) != 0 );
    XCTAssert( host->CreateFile("/", file, 0) == 0 );
    XCTAssert( file->Open(VFSFlags::OF_Read) != 0 );
}

- (void)test192_168_2_5
{
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("192.168.2.5", "", "", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
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

- (void)testMacMini
{
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("macmini.local", "r2d2", "r2d2", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
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
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("192.168.2.5", "", "", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    const char *fn = "/Public/!FilesTesting/empty_file";

    VFSStat stat;
    if( host->Stat(fn, stat, 0, 0) == 0 )
        XCTAssert( host->Unlink(fn, 0) == 0 );
    
    VFSFilePtr file;
    XCTAssert( host->CreateFile(fn, file, 0) == 0 );
    XCTAssert( file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == 0 );
    XCTAssert( file->IsOpened() == true );
    XCTAssert( file->Close() == 0);

    // sometimes this fail. mb caused by FTP server implementation (?)
    XCTAssert( host->Stat(fn, stat, 0, 0) == 0);
    XCTAssert( stat.size == 0);
    
    XCTAssert( file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create | VFSFlags::OF_NoExist) != 0 );
    XCTAssert( file->IsOpened() == false );
    
    XCTAssert( host->Unlink(fn, 0) == 0 );
    XCTAssert( host->Stat(fn, stat, 0, 0) != 0);
}

// thanks to QNAP weird firmware update - it's ftp server stop overwriting files and began to appending them always
// so currently using OSX Server built-in ftp.
- (void)testMacMini_AppendTest
{
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("macmini.local", "r2d2", "r2d2", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    const char *fn = "/Public/!FilesTesting/append.txt";

    VFSStat stat;
    if( host->Stat(fn, stat, 0, 0) == 0 )
        XCTAssert( host->Unlink(fn, 0) == 0 );

    VFSFilePtr file;
    const char *str = "Hello World!\n";
    const char *str2= "Underworld!\n";
    XCTAssert( host->CreateFile(fn, file, 0) == 0 );
    XCTAssert( file->Open(VFSFlags::OF_Write | VFSFlags::OF_Create) == 0 );
    XCTAssert( file->Write(str, strlen(str)) == strlen(str) );
    XCTAssert( file->Close() == 0 );

    XCTAssert( file->Open(VFSFlags::OF_Write | VFSFlags::OF_Append) == 0 );
    XCTAssert( file->Size() == strlen(str) );
    XCTAssert( file->Pos() == strlen(str) );
    XCTAssert( file->Write(str, strlen(str)) == strlen(str) );
    XCTAssert( file->Close() == 0 );
    
    XCTAssert( host->Stat(fn, stat, 0, 0) == 0 );
    XCTAssert( stat.size == strlen(str)*2 );
    
    XCTAssert( file->Open(VFSFlags::OF_Write) == 0 ); // should implicitly truncating for FTP uploads
    XCTAssert( file->Size() == 0 );
    XCTAssert( file->Pos() == 0 );
    XCTAssert( file->Write(str2, strlen(str2)) == strlen(str2) );
    XCTAssert( file->Close() == 0);
    
    XCTAssert( host->Stat(fn, stat, 0, 0) == 0 );
    XCTAssert( stat.size == strlen(str2) );
    
    XCTAssert( file->Open(VFSFlags::OF_Read) == 0 );
    char buf[4096];
    XCTAssert( file->Read(buf, 4096) == strlen(str2) );
    XCTAssert( memcmp(buf, str2, strlen(str2)) == 0 );
}

- (void) testLocal_MKD_RMD
{
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>(g_LocalFTP, "", "", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
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
                   "/some/another/invalid/path"s
        })
    {
        XCTAssert( host->CreateDirectory(dir.c_str(), 0755, 0) != 0 );
        XCTAssert( host->IsDirectory(dir.c_str(), 0, 0) == false );
    }
}

- (void) testLocal_Rename_NAS
{
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>(g_LocalFTP, "", "", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
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
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("macmini.local", "r2d2", "r2d2", "/");
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
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

- (void)testListing_Kernel_Org
{
    auto path = "/pub/dist/";
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("ftp.kernel.org", "", "", path);
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    set<string> should_be = {"knoppix", "knoppix-dvd", "planb", "superrescue"};
    set<string> in_fact;
    
    XCTAssert( host->IterateDirectoryListing(path, [&](const VFSDirEnt &_dirent) {
            in_fact.emplace(_dirent.name);
            return true;
        }) == 0);
    XCTAssert(should_be == in_fact);
}

- (void)testSeekRead_Kernel_Org
{
    VFSHostPtr host;
    try {
        auto host = make_shared<VFSNetFTPHost>("ftp.kernel.org", "", "", "/pub/dist/planb/");
        
        // check seeking at big distance and reading an arbitrary selected known data block
        VFSFilePtr file;
        char buf[4096];
        XCTAssert( host->CreateFile("/pub/dist/planb/custom-kit.tar.gz", file, 0) == 0 );
        XCTAssert( file->Open(VFSFlags::OF_Read) == 0 );
        XCTAssert( file->Seek(0x14F52440, VFSFile::Seek_Set) == 0x14F52440);
        XCTAssert( file->Read(buf, 16) == 16 );
        XCTAssert( memcmp(buf, "\x59\xc6\x88\x0c\x54\x5a\x54\xfe\xd3\x95\x96\x81\xf7\x50\xa5\x65", 16) == 0 );
        
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testListing_RedHat_Com
{
    auto path = "/redhat/dst2007/APPLICATIONS/";
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("ftp.redhat.com", "", "", path);
    } catch (VFSErrorException &e) {
        XCTAssert( 0 );
        return;
    }
    set<string> should_be = {"evolution", "evolution-data-server", "gcj", "IBMJava2-JRE", "IBMJava2-SDK", "java-1.4.2-bea", "java-1.4.2-ibm", "rhn_satellite_java_update"};
    set<string> in_fact;
    
    XCTAssert( host->IterateDirectoryListing(path, [&](const VFSDirEnt &_dirent) {
        in_fact.emplace(_dirent.name);
        return true;
    }) == 0);
    XCTAssert(should_be == in_fact);
}

- (void)testBigFilesReadingCancellation
{
    path path = "/pub/dist/planb/custom-kit.tar.gz";
    
    VFSHostPtr host;
    try {
        host = make_shared<VFSNetFTPHost>("ftp.kernel.org", "", "", path.parent_path().native());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;        
    }    
  
    __block bool finished = false;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        VFSFilePtr file;
        char buf[256];
        XCTAssert( host->CreateFile(path.c_str(), file, 0) == 0 );
        XCTAssert( file->Open(VFSFlags::OF_Read) == 0 );
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

