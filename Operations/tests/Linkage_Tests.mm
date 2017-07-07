#import <XCTest/XCTest.h>
#include "../source/Linkage/Linkage.h"
#include <VFS/Native.h>

using namespace nc::ops;

@interface Linkage_Tests : XCTestCase

@end

@implementation Linkage_Tests
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

- (void)testSymlinkCreation
{
    const auto path = (m_TmpDir/"symlink").native();
    const auto value = "pointing_somewhere"s;
    Linkage operation{path, value, m_NativeHost, LinkageType::CreateSymlink};
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    
    VFSStat st;
    const auto st_rc = m_NativeHost->Stat(path.c_str(), st, VFSFlags::F_NoFollow);
    XCTAssert( st_rc == VFSError::Ok );
    XCTAssert( (st.mode & S_IFMT) == S_IFLNK );
    
    char buf[MAXPATHLEN];
    XCTAssert( m_NativeHost->ReadSymlink(path.c_str(), buf, sizeof(buf)) == VFSError::Ok );
    XCTAssert( buf == value );
}

- (void)testSymlinkCreationOnInvalidPath
{
    const auto path = (m_TmpDir/"not_existing_directory/symlink").native();
    const auto value = "pointing_somewhere"s;
    Linkage operation{path, value, m_NativeHost, LinkageType::CreateSymlink};
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() != OperationState::Completed );
}

- (void)testSymlinkAlteration
{
    const auto path = (m_TmpDir/"symlink").native();
    const auto value = "pointing_somewhere"s;
    symlink("previous_symlink_value", path.c_str());
    
    Linkage operation{path, value, m_NativeHost, LinkageType::AlterSymlink};
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    
    VFSStat st;
    const auto st_rc = m_NativeHost->Stat(path.c_str(), st, VFSFlags::F_NoFollow);
    XCTAssert( st_rc == VFSError::Ok );
    XCTAssert( (st.mode & S_IFMT) == S_IFLNK );
    
    char buf[MAXPATHLEN];
    XCTAssert( m_NativeHost->ReadSymlink(path.c_str(), buf, sizeof(buf)) == VFSError::Ok );
    XCTAssert( buf == value );
}

- (void) testHarlinkCreation
{
    const auto path = (m_TmpDir/"node1").native();
    const auto value = (m_TmpDir/"node2").native();
    close( creat( value.c_str(), 0755 ) );

    Linkage operation{path, value, m_NativeHost, LinkageType::CreateHardlink};
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );

    VFSStat st1, st2;
    XCTAssert( m_NativeHost->Stat(path.c_str(), st1, 0) == VFSError::Ok );
    XCTAssert( m_NativeHost->Stat(value.c_str(), st2, 0) == VFSError::Ok );
    XCTAssert( st1.inode == st2.inode );
}

- (path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" "com.magnumbytes.nimblecommander" ".tmp.XXXXXX",
            NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

@end

