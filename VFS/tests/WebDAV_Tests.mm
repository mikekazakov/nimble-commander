#include "tests_common.h"
#include "../source/NetWebDAV/VFSNetWebDAVHost.h"
#include <VFS/VFSEasyOps.h>

using namespace nc::vfs;

static const auto g_BoxComUsername = "mike.kazakov+ncwebdavtest@gmail.com";
static const auto g_BoxComPassword = "6S3zUvkkNikF";

@interface WebDAV_Tests : XCTestCase
@end

@implementation WebDAV_Tests

- (void)testBasic
{
    shared_ptr<WebDAVHost> host(new WebDAVHost("192.168.2.5", "guest", "", "Public", false, 5000));

    VFSListingPtr listing;
    int rc = host->FetchDirectoryListing("/", listing, 0, nullptr);
    XCTAssert(rc == VFSError::Ok);
}


- (shared_ptr<WebDAVHost>) spawnBoxComHost
{
    return shared_ptr<WebDAVHost> (new WebDAVHost("dav.box.com",
                                                  g_BoxComUsername,
                                                  g_BoxComPassword,
                                                  "dav",
                                                  true));
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

@end
