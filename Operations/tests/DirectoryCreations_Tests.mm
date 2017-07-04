#import <XCTest/XCTest.h>
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include "../source/DirectoryCreation/DirectoryCreation.h"

using namespace nc::ops;

@interface DirectoryCreationTests : XCTestCase
@end


@implementation DirectoryCreationTests
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

- (void)testSimpleCreation
{
    DirectoryCreation operation{ "Test", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->Exists((m_TmpDir/"Test").c_str()) );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test").c_str(), 0) );
}

- (void)testMultipleDirectoriesCreation
{
    DirectoryCreation operation{ "Test1/Test2/Test3", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1").c_str(), 0) );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1/Test2").c_str(), 0) );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1/Test2/Test3").c_str(), 0) );
}

- (void)testTrailingSlashes
{
    DirectoryCreation operation{ "Test///", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test").c_str(), 0) );
}

- (void)testHeadingSlashes
{
    DirectoryCreation operation{ "///Test", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test").c_str(), 0) );
}

- (void)testEmptyInput
{
    DirectoryCreation operation{ "", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
}

- (void)testWeirdInput
{
    DirectoryCreation operation{ "!@#$%^&*()_+", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"!@#$%^&*()_+").c_str(), 0) );
}

- (void)testAlredyExistingDir
{
    mkdir( (m_TmpDir/"Test1").c_str(), 0755 );
    DirectoryCreation operation{ "Test1/Test2/Test3", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1").c_str(), 0) );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1/Test2").c_str(), 0) );
    XCTAssert( m_NativeHost->IsDirectory((m_TmpDir/"Test1/Test2/Test3").c_str(), 0) );
}

- (void)testAlredyExistingRegFile
{
    close( creat( (m_TmpDir/"Test1").c_str(), 0755 ) );
    DirectoryCreation operation{ "Test1/Test2/Test3", m_TmpDir.native(), *m_NativeHost };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() != OperationState::Completed );
    XCTAssert( m_NativeHost->Exists((m_TmpDir/"Test1").c_str()) );
    XCTAssert( !m_NativeHost->IsDirectory((m_TmpDir/"Test1").c_str(), 0) );
    XCTAssert( !m_NativeHost->Exists((m_TmpDir/"Test1/Test2").c_str()) );
    XCTAssert( !m_NativeHost->Exists((m_TmpDir/"Test1/Test2/Test3").c_str()) );
}

- (path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir,
            "%s" "com.magnumbytes.nimblecommander" ".tmp.XXXXXX",
            NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

@end
