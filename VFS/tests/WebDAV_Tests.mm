#include "tests_common.h"
#include "../source/NetWebDAV/VFSNetWebDAVHost.h"

using namespace nc::vfs;

static const auto g_BoxComUsername = "mike.kazakov+ncwebdavtest@gmail.com";
static const auto g_BoxComPassword = "6S3zUvkkNikF";

@interface WebDAV_Tests : XCTestCase
@end

@implementation WebDAV_Tests

- (void)testBasic
{
    shared_ptr<WebDAVHost> host(new WebDAVHost("192.168.2.5", "admin", "iddqd", "Public", false, 5000));
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
    
    XCTAssert( has_fn("..") );
    XCTAssert( has_fn("Test1") );
}

- (void)testCanFetchBoxComSubfolderListing
{
    const auto host = [self spawnBoxComHost];
    VFSListingPtr listing;
    
    int rc = host->FetchDirectoryListing("/Test1", listing, VFSFlags::F_NoDotDot, nullptr);
    XCTAssert(rc == VFSError::Ok);
    
    const auto has_fn = [listing]( const char *_fn ) {
        return any_of(begin(*listing), end(*listing), [_fn](auto &_i){
            return _i.Filename() == _fn;
        });
    };
    
    XCTAssert( !has_fn("..") );
    XCTAssert( has_fn("README.md") );
    XCTAssert( has_fn("scorpions-lifes_like_a_river.gpx") );
}


@end
