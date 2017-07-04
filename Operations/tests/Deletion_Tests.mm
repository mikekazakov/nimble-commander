#import <XCTest/XCTest.h>
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include "../source/Deletion/Deletion.h"

using namespace nc::ops;

@interface DeletionTests : XCTestCase
@end

static vector<VFSListingItem> FetchItems(const string& _directory_path,
                                         const vector<string> &_filenames,
                                         VFSHost &_host);

@implementation DeletionTests
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

- (void)testRegRemoval
{
    close( creat( (m_TmpDir/"regular_file").c_str(), 0755 ) );
    Deletion operation{ FetchItems(m_TmpDir.native(), {"regular_file"}, *m_NativeHost),
                        DeletionType::Permanent };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( !m_NativeHost->Exists((m_TmpDir/"regular_file").c_str()) );
}

- (void)testDirRemoval
{
    mkdir( (m_TmpDir/"directory").c_str(), 0755 );
    Deletion operation{ FetchItems(m_TmpDir.native(), {"directory"}, *m_NativeHost),
                        DeletionType::Permanent };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( !m_NativeHost->Exists((m_TmpDir/"directory").c_str()) );
}

- (void)testLinkRemoval
{
    link( (m_TmpDir/"link").c_str() , "/System/Library/Kernels/kernel" );
    Deletion operation{ FetchItems(m_TmpDir.native(), {"link"}, *m_NativeHost),
                        DeletionType::Permanent };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( !m_NativeHost->Exists((m_TmpDir/"link").c_str()) );
}

- (void)testNestedRemoval
{
    mkdir( (m_TmpDir/"top").c_str(), 0755 );
    mkdir( (m_TmpDir/"top/next1").c_str(), 0755 );
    close( creat( (m_TmpDir/"top/next1/reg1").c_str(), 0755 ) );
    close( creat( (m_TmpDir/"top/next1/reg2").c_str(), 0755 ) );
    mkdir( (m_TmpDir/"top/next2").c_str(), 0755 );
    close( creat( (m_TmpDir/"top/next2/reg1").c_str(), 0755 ) );
    close( creat( (m_TmpDir/"top/next2/reg2").c_str(), 0755 ) );

    Deletion operation{ FetchItems(m_TmpDir.native(), {"top"}, *m_NativeHost),
                        DeletionType::Permanent };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( !m_NativeHost->Exists((m_TmpDir/"top").c_str()) );
}

- (void)testNestedTrash
{
    mkdir( (m_TmpDir/"top").c_str(), 0755 );
    mkdir( (m_TmpDir/"top/next1").c_str(), 0755 );
    close( creat( (m_TmpDir/"top/next1/reg1").c_str(), 0755 ) );
    close( creat( (m_TmpDir/"top/next1/reg2").c_str(), 0755 ) );
    mkdir( (m_TmpDir/"top/next2").c_str(), 0755 );
    close( creat( (m_TmpDir/"top/next2/reg1").c_str(), 0755 ) );
    close( creat( (m_TmpDir/"top/next2/reg2").c_str(), 0755 ) );

    Deletion operation{ FetchItems(m_TmpDir.native(), {"top"}, *m_NativeHost),
                        DeletionType::Trash };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( !m_NativeHost->Exists((m_TmpDir/"top").c_str()) );
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

static vector<VFSListingItem> FetchItems(const string& _directory_path,
                                         const vector<string> &_filenames,
                                         VFSHost &_host)
{
    vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}
