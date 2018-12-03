// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include <thread>
#include <boost/filesystem.hpp>
#include <sys/stat.h>

#include "../source/Compression/Compression.h"
#include "../source/Statistics.h"

#include <VFS/VFS.h>
#include <VFS/ArcLA.h>
#include <VFS/Native.h>

using namespace nc;
using namespace nc::ops;
using namespace std::literals;

@interface CompressionTests : XCTestCase
@end

static int VFSCompareEntries(const boost::filesystem::path& _file1_full_path,
                             const VFSHostPtr& _file1_host,
                             const boost::filesystem::path& _file2_full_path,
                             const VFSHostPtr& _file2_host,
                             int &_result);

static std::vector<VFSListingItem> FetchItems(const std::string& _directory_path,
                                              const std::vector<std::string> &_filenames,
                                              VFSHost &_host);

@implementation CompressionTests
{
    boost::filesystem::path m_TmpDir;
    std::shared_ptr<VFSHost> m_NativeHost;
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

- (void)testEmptyArchiveBuilding
{
    Compression operation{std::vector<VFSListingItem>{}, m_TmpDir.native(), m_NativeHost };
    operation.Start();
    operation.Wait();

    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->Exists(operation.ArchivePath().c_str()) );
    
    try {
        auto arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), m_NativeHost);
        XCTAssert( arc_host->StatTotalFiles() == 0 );
    }
    catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testCompressingMacKernel
{
    Compression operation{FetchItems("/System/Library/Kernels/", {"kernel"}, *m_NativeHost),
                          m_TmpDir.native(),
                          m_NativeHost};
    
    operation.Start();
    operation.Wait();

    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( operation.Statistics().ElapsedTime() > 1ms &&
               operation.Statistics().ElapsedTime() < 1s );
    XCTAssert( m_NativeHost->Exists(operation.ArchivePath().c_str()) );
    try {
        auto arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), m_NativeHost);
        XCTAssert( arc_host->StatTotalFiles() == 1 );
        int cmp_result = 0;
        const auto cmp_rc =  VFSEasyCompareFiles("/System/Library/Kernels/kernel", m_NativeHost,
                                                 "/kernel", arc_host,
                                                 cmp_result);
        XCTAssert( cmp_rc == VFSError::Ok && cmp_result == 0 );
    }
    catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testCompressingBinUtilities
{
    const std::vector<std::string> filenames = { "[", "bash", "cat", "chmod", "cp", "csh", "date", "dd", "df",
        "echo", "ed", "expr", "hostname", "kill", "ksh", "launchctl", "link",
        "ln", "ls", "mkdir", "mv", "pax", "ps", "pwd", "rm", "rmdir", "sh", "sleep", "stty",
        "sync", "tcsh", "test", "unlink", "wait4path", "zsh" };

    Compression operation{FetchItems("/bin/", filenames, *m_NativeHost),
        m_TmpDir.native(),
        m_NativeHost};
    
    operation.Start();
    operation.Wait();
    
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->Exists(operation.ArchivePath().c_str()) );
    
    try {
        auto arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), m_NativeHost);
        XCTAssert( arc_host->StatTotalFiles() == filenames.size() );
        
        for( auto &fn: filenames) {
            int cmp_result = 0;
            const auto cmp_rc =  VFSEasyCompareFiles(("/bin/"s + fn).c_str(), m_NativeHost,
                                                     ("/"s + fn).c_str(), arc_host,
                                                     cmp_result);
            XCTAssert( cmp_rc == VFSError::Ok && cmp_result == 0 );
        }
    }
    catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testCompressingBinDirectory
{
    Compression operation{FetchItems("/", {"bin"}, *m_NativeHost),
        m_TmpDir.native(),
        m_NativeHost};
    
    operation.Start();
    operation.Wait();
    
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->Exists(operation.ArchivePath().c_str()) );
    
    try {
        auto arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), m_NativeHost);
        int cmp_result = 0;
        const auto cmp_rc = VFSCompareEntries("/bin/",
                                              m_NativeHost,
                                              "/bin/",
                                              arc_host,
                                              cmp_result);
        XCTAssert( cmp_rc == VFSError::Ok && cmp_result == 0 );
    }
    catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testCompressingChessApp
{
    Compression operation{FetchItems("/Applications/", {"Chess.app"}, *m_NativeHost),
        m_TmpDir.native(),
        m_NativeHost};
    
    operation.Start();
    operation.Wait();
    
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->Exists(operation.ArchivePath().c_str()) );

    try {
        auto arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), m_NativeHost);
        int cmp_result = 0;
        const auto cmp_rc = VFSCompareEntries("/Applications/Chess.app",
                                              m_NativeHost,
                                              "/Chess.app",
                                              arc_host,
                                              cmp_result);
        XCTAssert( cmp_rc == VFSError::Ok && cmp_result == 0 );
    }
    catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (void)testLongCompressionStats
{
 Compression operation{FetchItems("/Applications/", {"iTunes.app"}, *m_NativeHost),
        m_TmpDir.native(),
        m_NativeHost};
    
    operation.Start();
    operation.Wait( 5000ms );
    const auto eta = operation.Statistics().ETA( Statistics::SourceType::Bytes );
    XCTAssert( double(eta->count()) / 1000000000. > 4.9 );
    
    operation.Pause();
    XCTAssert( operation.State() == OperationState::Paused );
    operation.Wait( 5000ms );
    XCTAssert( operation.State() == OperationState::Paused );
    operation.Resume();
    operation.Wait();
    XCTAssert( operation.State() == OperationState::Completed );
    XCTAssert( m_NativeHost->Exists(operation.ArchivePath().c_str()) );

    try {
        auto arc_host = std::make_shared<vfs::ArchiveHost>(operation.ArchivePath().c_str(), m_NativeHost);
        int cmp_result = 0;
        const auto cmp_rc = VFSCompareEntries("/Applications/iTunes.app",
                                              m_NativeHost,
                                              "/iTunes.app",
                                              arc_host,
                                              cmp_result);
        XCTAssert( cmp_rc == VFSError::Ok && cmp_result == 0 );
    }
    catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
    }
}

- (boost::filesystem::path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" "info.filesmanager.files" ".tmp.XXXXXX", NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

@end



static int VFSCompareEntries(const boost::filesystem::path& _file1_full_path,
                             const VFSHostPtr& _file1_host,
                             const boost::filesystem::path& _file2_full_path,
                             const VFSHostPtr& _file2_host,
                             int &_result)
{
    // not comparing flags, perm, times, xattrs, acls etc now
    
    VFSStat st1, st2;
    int ret;
    if((ret =_file1_host->Stat(_file1_full_path.c_str(), st1, VFSFlags::F_NoFollow, 0)) < 0)
        return ret;
    
    if((ret =_file2_host->Stat(_file2_full_path.c_str(), st2, VFSFlags::F_NoFollow, 0)) < 0)
        return ret;
    
    if((st1.mode & S_IFMT) != (st2.mode & S_IFMT)) {
        _result = -1;
        return 0;
    }
    
    if( S_ISREG(st1.mode) ) {
        if(int64_t(st1.size) - int64_t(st2.size) != 0)
            _result = int(int64_t(st1.size) - int64_t(st2.size));
    }
    else if( S_ISLNK(st1.mode) ) {
        char link1[MAXPATHLEN], link2[MAXPATHLEN];
        if( (ret = _file1_host->ReadSymlink(_file1_full_path.c_str(), link1, MAXPATHLEN, 0)) < 0)
            return ret;
        if( (ret = _file2_host->ReadSymlink(_file2_full_path.c_str(), link2, MAXPATHLEN, 0)) < 0)
            return ret;
        if( strcmp(link1, link2) != 0)
            _result = strcmp(link1, link2);
    }
    else if ( S_ISDIR(st1.mode) ) {
        _file1_host->IterateDirectoryListing(_file1_full_path.c_str(), [&](const VFSDirEnt &_dirent) {
            int ret = VFSCompareEntries( _file1_full_path / _dirent.name,
                                        _file1_host,
                                        _file2_full_path / _dirent.name,
                                        _file2_host,
                                        _result);
            if(ret != 0)
                return false;
            return true;
        });
    }
    return 0;
}

static std::vector<VFSListingItem> FetchItems(const std::string& _directory_path,
                                              const std::vector<std::string> &_filenames,
                                              VFSHost &_host)
{
    std::vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}
