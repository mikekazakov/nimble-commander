#import <XCTest/XCTest.h>
#include "../source/AttrsChanging/AttrsChanging.h"
#include <VFS/Native.h>

using namespace nc::ops;

@interface AttrsChanging_Tests : XCTestCase

@end

@implementation AttrsChanging_Tests
{
    path m_TmpDir;
    shared_ptr<VFSHost> m_NativeHost;
}

- (void)setUp
{
    [super setUp];
    m_NativeHost = VFSNativeHost::SharedHost();
    m_TmpDir = self.makeTmpDir;
}

- (void)tearDown
{
    VFSEasyDelete(m_TmpDir.c_str(), VFSNativeHost::SharedHost());
    [super tearDown];
}

- (void)testChmod
{
    const auto path = (m_TmpDir/"test").native();
    close( creat( path.c_str(), 0755 ) );
    
    AttrsChangingCommand cmd;
    cmd.items = [self fetchItems:{"test"} fromDirectory:m_TmpDir.native()];
    cmd.permissions.emplace();
    cmd.permissions->grp_r = false;
    cmd.permissions->grp_x = false;
    cmd.permissions->oth_r = false;
    cmd.permissions->oth_x = false;
    
    AttrsChanging operation{ cmd };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    
    VFSStat st;
    XCTAssert( m_NativeHost->Stat(path.c_str(), st, 0) == VFSError::Ok );
    XCTAssert( (st.mode & ~S_IFMT) == 0700 );
}

- (void)testRecursion
{
    const auto path = (m_TmpDir/"test").native();
    const auto path1= (m_TmpDir/"test/qwer").native();
    const auto path2= (m_TmpDir/"test/qwer/asdf").native();
    mkdir( path.c_str(), 0755 );
    mkdir( path1.c_str(), 0755 );
    close( creat( path2.c_str(), 0755 ) );
    
    AttrsChangingCommand cmd;
    cmd.items = [self fetchItems:{"test"} fromDirectory:m_TmpDir.native()];
    cmd.permissions.emplace();
    cmd.permissions->grp_r = false;
    cmd.permissions->grp_x = false;
    cmd.permissions->oth_r = false;
    cmd.permissions->oth_x = false;
    cmd.apply_to_subdirs = true;
    
    AttrsChanging operation{ cmd };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    
    VFSStat st;
    XCTAssert( m_NativeHost->Stat(path.c_str(), st, 0) == VFSError::Ok );
    XCTAssert( (st.mode & ~S_IFMT) == 0700 );
    
    XCTAssert( m_NativeHost->Stat(path1.c_str(), st, 0) == VFSError::Ok );
    XCTAssert( (st.mode & ~S_IFMT) == 0700 );

    XCTAssert( m_NativeHost->Stat(path2.c_str(), st, 0) == VFSError::Ok );
    XCTAssert( (st.mode & ~S_IFMT) == 0700 );
}

- (void)testChown
{
    const auto path = (m_TmpDir/"test").native();
    close( creat( path.c_str(), 0755 ) );
    
    AttrsChangingCommand cmd;
    cmd.items = [self fetchItems:{"test"} fromDirectory:m_TmpDir.native()];
    cmd.ownage.emplace();
    cmd.ownage->gid = 12;
    
    AttrsChanging operation{ cmd };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    
    VFSStat st;
    XCTAssert( m_NativeHost->Stat(path.c_str(), st, 0) == VFSError::Ok );
    XCTAssert( st.gid == 12 );
}

- (path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" "com.magnumbytes.nimblecommander" ".tmp.XXXXXX",
            NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

- (vector<VFSListingItem>) fetchItems:(const vector<string> &)_filenames
                        fromDirectory:(const string&)_directory_path
{
    vector<VFSListingItem> items;
    m_NativeHost->FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}

@end
