// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "tests_common.h"
#include "../source/NetWebDAV/WebDAVHost.h"
#include <VFS/VFSEasyOps.h>
#include <VFS/Native.h>

using namespace nc::vfs;

static const auto g_NASUsername = NCE(nc::env::test::webdav_nas_username);
static const auto g_NASPassword = NCE(nc::env::test::webdav_nas_password);
static const auto g_BoxComUsername = NCE(nc::env::test::webdav_boxcom_username);
static const auto g_BoxComPassword = NCE(nc::env::test::webdav_boxcom_password);
static const auto g_YandexDiskUsername = NCE(nc::env::test::webdav_yandexdisk_username);
static const auto g_YandexDiskPassword = NCE(nc::env::test::webdav_yandexdisk_password);

@interface WebDAV_Tests : XCTestCase
@end

@implementation WebDAV_Tests


- (shared_ptr<WebDAVHost>) spawnNASHost
{
    return shared_ptr<WebDAVHost> (new WebDAVHost("blaze.local",
                                                  g_NASUsername,
                                                  g_NASPassword,
                                                  "Public",
                                                  false,
                                                  5000));
}

- (shared_ptr<WebDAVHost>) spawnBoxComHost
{
    return shared_ptr<WebDAVHost> (new WebDAVHost("dav.box.com",
                                                  g_BoxComUsername,
                                                  g_BoxComPassword,
                                                  "dav",
                                                  true));
}

- (shared_ptr<WebDAVHost>) spawnYandexDiskHost
{
    return shared_ptr<WebDAVHost> (new WebDAVHost("webdav.yandex.com",
                                                  g_YandexDiskUsername,
                                                  g_YandexDiskPassword,
                                                  "",
                                                  true));
}

- (void)testCanConnectToLocalNAS
{
    const auto host = [self spawnNASHost];

    VFSListingPtr listing;
    int rc = host->FetchDirectoryListing("/", listing, 0, nullptr);
    XCTAssert(rc == VFSError::Ok);
}

- (void)testCanConnectToBoxCom
{
    try {
        auto host = [self spawnBoxComHost];
    }
    catch(...) {
        XCTAssert( false );
    }
}

- (void)testCanFetchBoxComListing
{
    const auto host = [self spawnBoxComHost];
    VFSListingPtr listing;
    
    int rc = host->FetchDirectoryListing("/", listing, 0, nullptr);
    XCTAssert(rc == VFSError::Ok);
    
    const auto has_fn = [listing]( const char *_fn ) {
        return any_of(begin(*listing), end(*listing), [_fn](auto &_i){
            return _i.Filename() == _fn;
        });
    };
    
    XCTAssert( !has_fn("..") );
    XCTAssert( has_fn("Test1") );
}

- (void)testCanFetchBoxComSubfolderListing
{
    const auto host = [self spawnBoxComHost];
    VFSListingPtr listing;
    
    int rc = host->FetchDirectoryListing("/Test1", listing, 0, nullptr);
    XCTAssert(rc == VFSError::Ok);
    
    const auto has_fn = [listing]( const char *_fn ) {
        return any_of(begin(*listing), end(*listing), [_fn](auto &_i){
            return _i.Filename() == _fn;
        });
    };
    
    XCTAssert( has_fn("..") );
    XCTAssert( has_fn("README.md") );
    XCTAssert( has_fn("scorpions-lifes_like_a_river.gpx") );
}

- (void)testCanFetchMultipleListingsOnBoxCom
{
    const auto host = [self spawnBoxComHost];
    VFSListingPtr listing;
    
    int rc1 = host->FetchDirectoryListing("/Test1", listing, 0, nullptr);
    XCTAssert(rc1 == VFSError::Ok);
    int rc2 = host->FetchDirectoryListing("/", listing, 0, nullptr);
    XCTAssert(rc2 == VFSError::Ok);
    int rc3 = host->FetchDirectoryListing("/Test1", listing, 0, nullptr);
    XCTAssert(rc3 == VFSError::Ok);
}

- (void)testConsecutiveStatsOnBoxCom
{
    const auto host = [self spawnBoxComHost];
    VFSStat st;
    int rc = host->Stat("/Test1/scorpions-lifes_like_a_river.gpx", st, 0, nullptr);
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( st.size == 65039 );
    XCTAssert( S_ISREG(st.mode) );

    rc = host->Stat("/Test1/README.md", st, 0, nullptr);
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( st.size == 1450 );
    XCTAssert( S_ISREG(st.mode) );

    rc = host->Stat("/Test1/", st, 0, nullptr);
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( S_ISDIR(st.mode) );

    rc = host->Stat("/", st, 0, nullptr);
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( S_ISDIR(st.mode) );

    rc = host->Stat("", st, 0, nullptr);
    XCTAssert( rc != VFSError::Ok );
    
    rc = host->Stat("/SomeGibberish/MoreGibberish/EvenMoregibberish.txt", st, 0, nullptr);
    XCTAssert( rc != VFSError::Ok );
}

- (void)testCreateDirectoryOnBoxCom
{
    const auto host = [self spawnBoxComHost];
    
    const auto p1 = "/Test2/";
    VFSEasyDelete(p1, host);    

    XCTAssert( host->CreateDirectory(p1, 0, nullptr) == VFSError::Ok );
    XCTAssert( host->Exists(p1) );
    XCTAssert( host->IsDirectory(p1, 0) );

    const auto p2 = "/Test2/SubDir1";
    XCTAssert( host->CreateDirectory(p2, 0, nullptr) == VFSError::Ok );
    XCTAssert( host->Exists(p2) );
    XCTAssert( host->IsDirectory(p2, 0) );

    const auto p3 = "/Test2/SubDir2";
    XCTAssert( host->CreateDirectory(p3, 0, nullptr) == VFSError::Ok );
    XCTAssert( host->Exists(p3) );
    XCTAssert( host->IsDirectory(p3, 0) );
    
    VFSEasyDelete(p1, host);
}

- (void)testFileReadOnBoxCom
{
    const auto host = [self spawnBoxComHost];
    VFSFilePtr file;
    const auto path = "/Test1/scorpions-lifes_like_a_river.gpx";
    const auto filecr_rc = host->CreateFile(path, file, nullptr);
    XCTAssert( filecr_rc == VFSError::Ok );

    const auto open_rc = file->Open(VFSFlags::OF_Read);
    XCTAssert( open_rc == VFSError::Ok );
    
    auto data = file->ReadFile();
    XCTAssert(data &&
              data->size() == 65039 &&
              data->at(65037) == 4 &&
              data->at(65038) == 0 );    
}

- (void)testSimpleFileWriteOnBoxCom
{
    const auto host = [self spawnBoxComHost];
    VFSFilePtr file;
    const auto path = "/temp_file";
    const auto filecr_rc = host->CreateFile(path, file, nullptr);
    XCTAssert( filecr_rc == VFSError::Ok );

    const auto open_rc = file->Open(VFSFlags::OF_Write);
    XCTAssert( open_rc == VFSError::Ok );

    string_view str{"Hello, world!"};
    file->SetUploadSize(str.size());
    const auto write_rc = file->WriteFile(str.data(), str.size());
    XCTAssert( write_rc == VFSError::Ok );
    
    XCTAssert( file->Close() == VFSError::Ok );
    
    const auto open_rc2 = file->Open(VFSFlags::OF_Read);
    XCTAssert( open_rc2 == VFSError::Ok );

    const auto d = file->ReadFile();

    XCTAssert((d &&
              d->size() == str.size() &&
              str == string_view{(const char*)d->data(), d->size()}) );
    
    XCTAssert( file->Close() == VFSError::Ok );
    
    VFSEasyDelete(path, host);
}

- (void)testEmptyFileCreationOnBoxCom
{
    const auto host = [self spawnBoxComHost];
    VFSFilePtr file;
    const auto path = "/empty_file";
    const auto filecr_rc = host->CreateFile(path, file, nullptr);
    XCTAssert( filecr_rc == VFSError::Ok );

    const auto open_rc = file->Open(VFSFlags::OF_Write);
    XCTAssert( open_rc == VFSError::Ok );

    file->SetUploadSize(0);
    
    XCTAssert( file->Close() == VFSError::Ok );
    
    XCTAssert( host->Exists(path) );
    
    VFSEasyDelete(path, host);
}

- (void) testComplexCopyToBoxCom
{
    const auto host = [self spawnBoxComHost];
    VFSEasyDelete("/Test2", host);    
    const auto copy_rc = VFSEasyCopyDirectory("/System/Library/Filesystems/msdos.fs",
                                              VFSNativeHost::SharedHost(),
                                              "/Test2",
                                              host);
    XCTAssert( copy_rc == VFSError::Ok );

    int res = 0;
    int cmp_rc = VFSCompareNodes("/System/Library/Filesystems/msdos.fs",
                                  VFSNativeHost::SharedHost(),
                                  "/Test2",
                                  host,
                                  res);
                                  
    XCTAssert( cmp_rc == VFSError::Ok && res == 0 );
    
    VFSEasyDelete("/Test2", host);
}

- (void) testRenameOnBoxCom
{
    const auto host = [self spawnBoxComHost];
    
    const auto p1 = "/new_empty_file";
    const auto creat_rc = VFSEasyCreateEmptyFile(p1, host);
    XCTAssert( creat_rc == VFSError::Ok );
    
    const auto p2 = u8"/new_empty_file_тест_ееёёё";
    const auto rename_rc = host->Rename(p1, p2, nullptr);
    XCTAssert( rename_rc == VFSError::Ok );
    
    XCTAssert( host->Exists(p2) );
    
    VFSEasyDelete(p2, host);
}

- (void)testStatFSonBoxCom
{
    const auto host = [self spawnBoxComHost];
    VFSStatFS st;
    const auto statfs_rc = host->StatFS("/", st, nullptr);
    XCTAssert( statfs_rc == VFSError::Ok );
    XCTAssert( st.total_bytes > 1'000'000'000L );
}

- (void)testInvalidCredentials
{
    try {
        new WebDAVHost("dav.box.com",
                       g_BoxComUsername,
                       "SomeRandomGibberish",
                       "dav",
                       true);
    }
    catch(VFSErrorException _ex) {
        XCTAssert( true );
        return;
    }
    catch(...) {
        XCTAssert( false );
    }
    XCTAssert( false );
}

- (void)testYandexDiskAccess
{
    const auto host = [self spawnYandexDiskHost];
    VFSStatFS st;
    const auto statfs_rc = host->StatFS("/", st, nullptr);
    XCTAssert( statfs_rc == VFSError::Ok );
    XCTAssert( st.total_bytes > 5'000'000'000L );
}

- (void)testSimpleDownloadFromYandexDisk
{
    const auto host = [self spawnYandexDiskHost];
    
    VFSFilePtr file;
    const auto path = "/Bears.jpg";
    const auto filecr_rc = host->CreateFile(path, file, nullptr);
    XCTAssert( filecr_rc == VFSError::Ok );

    const auto open_rc = file->Open(VFSFlags::OF_Read);
    XCTAssert( open_rc == VFSError::Ok );
    
    auto data = file->ReadFile();
    XCTAssert(data &&
              data->size() == 1'555'830 &&
              data->at(1'555'828) == 255 &&
              data->at(1'555'829) == 217 );
}

- (void) testComplexCopyToYandexDisk
{
    const auto host = [self spawnYandexDiskHost];
    VFSEasyDelete("/Test2", host);    
    const auto copy_rc = VFSEasyCopyDirectory("/System/Library/Filesystems/msdos.fs",
                                              VFSNativeHost::SharedHost(),
                                              "/Test2",
                                              host);
    XCTAssert( copy_rc == VFSError::Ok );

    int res = 0;
    int cmp_rc = VFSCompareNodes("/System/Library/Filesystems/msdos.fs",
                                  VFSNativeHost::SharedHost(),
                                  "/Test2",
                                  host,
                                  res);
                                  
    XCTAssert( cmp_rc == VFSError::Ok && res == 0 );
    
    VFSEasyDelete("/Test2", host);
}

@end
