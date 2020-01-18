// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include "TestEnv.h"
#include <VFS/VFS.h>
#include <VFS/Native.h>
#include <VFS/NetFTP.h>
#include "../source/Deletion/Deletion.h"
#include "Environment.h"
#include <boost/filesystem.hpp>
#include <sys/stat.h>

using namespace nc;
using namespace nc::ops;

static const auto g_LocalFTP =  NCE(nc::env::test::ftp_qnap_nas_host);

@interface DeletionTests : XCTestCase
@end

static std::vector<VFSListingItem> FetchItems(const std::string& _directory_path,
                                              const std::vector<std::string> &_filenames,
                                              VFSHost &_host);

@implementation DeletionTests
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

- (void)testFailingRemoval
{
    Deletion operation{ FetchItems("/System/Library/Kernels",
                                   {"kernel"},
                                   *m_NativeHost),
                        DeletionType::Permanent };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() != OperationState::Completed );
}

- (void)testComplexDeletion
{
    XCTAssert( VFSEasyCopyNode("/System/Applications/Mail.app",
                               m_NativeHost,
                               (boost::filesystem::path(m_TmpDir) / "Mail.app").c_str(),
                               m_NativeHost) == 0);
    
    Deletion operation{ FetchItems(m_TmpDir.native(),
                                   {"Mail.app"},
                                   *m_NativeHost),
                        DeletionType::Permanent };
    operation.Start();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    
    XCTAssert( !m_NativeHost->Exists((boost::filesystem::path(m_TmpDir) / "Mail.app").c_str()) );
}

- (void)testSimpleDeleteFromFTP
{
    try {
        auto host = std::make_shared<vfs::FTPHost>(g_LocalFTP, "", "", "/");
        
        const char *fn1 = "/System/Library/Kernels/kernel", *fn2 = "/Public/!FilesTesting/mach_kernel";
        VFSStat stat;
        
        // if there's a trash from previous runs - remove it
        if( host->Stat(fn2, stat, 0, 0) == 0)
            XCTAssert( host->Unlink(fn2, 0) == 0);
        
        XCTAssert( VFSEasyCopyFile(fn1, TestEnv().vfs_native, fn2, host) == 0);
        
        Deletion operation{ FetchItems("/Public/!FilesTesting", {"mach_kernel"}, *host),
            DeletionType::Permanent };
        operation.Start();
        operation.Wait();
        
        XCTAssert( host->Stat(fn2, stat, 0, 0) != 0); // check that file has gone
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testDeletingFromFTPDirectory
{
    try {
        auto host = std::make_shared<vfs::FTPHost>(g_LocalFTP, "", "", "/");
        
        const char *fn1 = "/bin", *fn2 = "/Public/!FilesTesting/bin";
        VFSStat stat;
        
        // if there's a trash from previous runs - remove it
        if( host->Stat(fn2, stat, 0, 0) == 0)
            XCTAssert(VFSEasyDelete(fn2, host) == 0);
        
        XCTAssert( VFSEasyCopyNode(fn1, TestEnv().vfs_native, fn2, host) == 0);
        
        
        Deletion operation{ FetchItems("/Public/!FilesTesting", {"bin"}, *host),
            DeletionType::Permanent };
        operation.Start();
        operation.Wait();
        
        XCTAssert( host->Stat(fn2, stat, 0, 0) != 0); // check that file has gone
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (boost::filesystem::path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir,
            "%s" "com.magnumbytes.nimblecommander" ".tmp.XXXXXX",
            NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

@end

static std::vector<VFSListingItem> FetchItems(const std::string& _directory_path,
                                              const std::vector<std::string> &_filenames,
                                              VFSHost &_host)
{
    std::vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}
