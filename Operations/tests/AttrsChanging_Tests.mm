// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include "TestEnv.h"
#include "../source/AttrsChanging/AttrsChanging.h"
#include <VFS/Native.h>
#include <boost/filesystem.hpp>
#include <sys/stat.h>

using namespace nc::ops;

@interface AttrsChanging_Tests : XCTestCase

@end

@implementation AttrsChanging_Tests
{
    boost::filesystem::path m_TmpDir;
    std::shared_ptr<VFSHost> m_NativeHost;
}

- (void)setUp
{
    [super setUp];
    m_NativeHost = TestEnv().vfs_native;
    m_TmpDir = self.makeTmpDir;
}

- (void)tearDown
{
    VFSEasyDelete(m_TmpDir.c_str(), m_NativeHost);
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

- (void)testChflags
{
    const auto path = (m_TmpDir/"test").native();
    close( creat( path.c_str(), 0755 ) );
    
    AttrsChangingCommand cmd;
    cmd.items = [self fetchItems:{"test"} fromDirectory:m_TmpDir.native()];
    cmd.flags.emplace();
    cmd.flags->u_hidden = true;
    
    AttrsChanging operation{ cmd };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    
    VFSStat st;
    XCTAssert( m_NativeHost->Stat(path.c_str(), st, 0) == VFSError::Ok );
    XCTAssert( st.flags & UF_HIDDEN );
}

- (void)testSetTime
{
    const auto path = (m_TmpDir/"test").native();
    const auto mtime = (long)[NSDate dateWithTimeIntervalSinceNow:-10000].timeIntervalSince1970;
    close( creat( path.c_str(), 0755 ) );
    
    AttrsChangingCommand cmd;
    cmd.items = [self fetchItems:{"test"} fromDirectory:m_TmpDir.native()];
    cmd.times.emplace();
    cmd.times->mtime = mtime;
 
    AttrsChanging operation{ cmd };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    
    VFSStat st;
    XCTAssert( m_NativeHost->Stat(path.c_str(), st, 0) == VFSError::Ok );
    XCTAssert( st.mtime.tv_sec == mtime );
}

- (boost::filesystem::path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" "com.magnumbytes.nimblecommander" ".tmp.XXXXXX",
            NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

- (std::vector<VFSListingItem>) fetchItems:(const std::vector<std::string> &)_filenames
                             fromDirectory:(const std::string&)_directory_path
{
    std::vector<VFSListingItem> items;
    m_NativeHost->FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}

@end
