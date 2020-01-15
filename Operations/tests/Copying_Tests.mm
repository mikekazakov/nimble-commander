// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include <sys/stat.h>
#include <VFS/Native.h>
#include <VFS/NetFTP.h>
#include <VFS/ArcUnRAR.h>
#include <VFS/XAttr.h>
#include "../source/Copying/Copying.h"
#include "../source/Copying/Helpers.h"
#include "Environment.h"
#include <boost/filesystem.hpp>

using namespace nc::ops;
using namespace nc::vfs;
using namespace std::literals;
static const boost::filesystem::path g_DataPref = NCE(nc::env::test::ext_data_prefix);
static const boost::filesystem::path g_PhotosRAR = g_DataPref / "archives" / "photos.rar";
static const auto g_LocalFTP =  NCE(nc::env::test::ftp_qnap_nas_host);

static std::vector<VFSListingItem> FetchItems(const std::string& _directory_path,
                                              const std::vector<std::string> &_filenames,
                                              VFSHost &_host)
{
    std::vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}

static int VFSCompareEntries(const boost::filesystem::path& _file1_full_path,
                             const VFSHostPtr& _file1_host,
                             const boost::filesystem::path& _file2_full_path,
                             const VFSHostPtr& _file2_host,
                             int &_result);

@interface CopyingTests : XCTestCase
@end

@implementation CopyingTests
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

- (void)testOverwriteBugRegression
{
    // ensures no-return of a bug introduced 30/01/15
    auto dir = self.makeTmpDir;
    auto dst = dir / "dest.zzz";
    auto host = VFSNativeHost::SharedHost();
    int result;
    
    {
        CopyingOptions opts;
        opts.docopy = true;
        Copying op(FetchItems((g_DataPref / "operations/copying/").native(), {"overwrite_test_big.zzz"}, *host),
                   dst.native(),
                   host,
                   opts);
        
        op.Start();
        op.Wait();
    }
    
    XCTAssert( VFSEasyCompareFiles((g_DataPref / "operations/copying/overwrite_test_big.zzz").c_str(), host, dst.c_str(), host, result) == 0 );
    XCTAssert( result == 0);
    
    {
        CopyingOptions opts;
        opts.docopy = true;
        opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
        Copying op(FetchItems((g_DataPref / "operations/copying/").native(), {"overwrite_test_small.zzz"}, *host),
                   dst.native(),
                   host,
                   opts);
        op.Start();
        op.Wait();
    }
    
    XCTAssert( VFSEasyCompareFiles((g_DataPref / "operations/copying/overwrite_test_small.zzz").c_str(), host, dst.c_str(), host, result) == 0 );
    XCTAssert( result == 0);
    
    XCTAssert( VFSEasyDelete(dir.c_str(), host) == 0);
}

- (void)testOverwriteBugRegressionReversion
{
    // reversion of testOverwriteBugRegression
    auto dir = self.makeTmpDir;
    auto dst = dir / "dest.zzz";
    auto host = VFSNativeHost::SharedHost();
    int result;
    
    {
        CopyingOptions opts;
        opts.docopy = true;
        Copying op(FetchItems((g_DataPref / "operations/copying/").native(), {"overwrite_test_small.zzz"}, *host),
                   dst.native(),
                   host,
                   opts);
        op.Start();
        op.Wait();
    }
    
    XCTAssert( VFSEasyCompareFiles((g_DataPref / "operations/copying/overwrite_test_small.zzz").c_str(), host, dst.c_str(), host, result) == 0 );
    XCTAssert( result == 0);
    
    {
        CopyingOptions opts;
        opts.docopy = true;
        opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
        Copying op(FetchItems((g_DataPref / "operations/copying/").native(), {"overwrite_test_big.zzz"}, *host),
                   dst.native(),
                   host,
                   opts);
        op.Start();
        op.Wait();
    }
    
    XCTAssert( VFSEasyCompareFiles((g_DataPref / "operations/copying/overwrite_test_big.zzz").c_str(), host, dst.c_str(), host, result) == 0 );
    XCTAssert( result == 0);
    
    XCTAssert( VFSEasyDelete(dir.c_str(), host) == 0);
}

- (void)testCaseRenaming
{
    auto dir = self.makeTmpDir;
    auto host = VFSNativeHost::SharedHost();
    
    {
        auto src = dir / "directory";
        mkdir(src.c_str(), S_IWUSR | S_IXUSR | S_IRUSR);
        
        CopyingOptions opts;
        opts.docopy = false;
        Copying op(FetchItems(dir.native(), {"directory"}, *host),
                   (dir / "DIRECTORY").native(),
                   host,
                   opts);
        op.Start();
        op.Wait();
        
        XCTAssert( host->IsDirectory((dir / "DIRECTORY").c_str(), 0, nullptr) == true );
        XCTAssert( FetchItems(dir.native(), {"DIRECTORY"}, *host).front().Filename() == "DIRECTORY" );
    }
    
    {
        auto src = dir / "filename";
        close(open(src.c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR));
        
        CopyingOptions opts;
        opts.docopy = false;
        Copying op(FetchItems(dir.native(), {"filename"}, *host),
                   (dir / "FILENAME").native(),
                   host,
                   opts);
        
        op.Start();
        op.Wait();
        
        XCTAssert( host->Exists((dir / "FILENAME").c_str()) == true );
        XCTAssert( FetchItems(dir.native(), {"FILENAME"}, *host).front().Filename() == "FILENAME" );
    }
    
    XCTAssert( VFSEasyDelete(dir.c_str(), host) == 0);
}

- (void)testCopyToFTP_192_168_2_5_____1
{
    VFSHostPtr host;
    try {
        host = std::make_shared<FTPHost>(g_LocalFTP, "", "", "/");
    } catch( VFSErrorException &e ) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    const char *fn1 = "/System/Library/Kernels/kernel",
               *fn2 = "/Public/!FilesTesting/kernel";

    [self EnsureClean:fn2 at:host];
    
    CopyingOptions opts;
    Copying op(FetchItems("/System/Library/Kernels/", {"kernel"}, *VFSNativeHost::SharedHost()),
               "/Public/!FilesTesting/",
               host,
               opts);
    
    op.Start();
    op.Wait();
        
    int compare;
    XCTAssert( VFSEasyCompareFiles(fn1, VFSNativeHost::SharedHost(), fn2, host, compare) == 0);
    XCTAssert( compare == 0);
    
    XCTAssert( host->Unlink(fn2, 0) == 0);
}

- (void)testCopyToFTP_192_168_2_5_____2
{
    VFSHostPtr host;
    try {
        host = std::make_shared<FTPHost>(g_LocalFTP, "", "", "/");
    } catch( VFSErrorException &e ) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    auto files = {"Info.plist", "PkgInfo", "version.plist"};
    
    for(auto &i: files)
      [self EnsureClean:"/Public/!FilesTesting/"s + i at:host];
    
    CopyingOptions opts;
    Copying op(FetchItems("/System/Applications/Mail.app/Contents", {begin(files), end(files)}, *VFSNativeHost::SharedHost()),
               "/Public/!FilesTesting/",
               host,
               opts);
    
    op.Start();
    op.Wait();
    
    for(auto &i: files) {
        int compare;
        XCTAssert( VFSEasyCompareFiles(("/System/Applications/Mail.app/Contents/"s + i).c_str(),
                                       VFSNativeHost::SharedHost(),
                                       ("/Public/!FilesTesting/"s + i).c_str(),
                                       host,
                                       compare) == 0);
        XCTAssert( compare == 0);
        XCTAssert( host->Unlink(("/Public/!FilesTesting/"s + i).c_str(), 0) == 0);
    }
}

- (void)testCopyToFTP_192_168_2_5_____3
{
    VFSHostPtr host;
    try {
        host = std::make_shared<FTPHost>(g_LocalFTP, "", "", "/");
    } catch( VFSErrorException &e ) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    [self EnsureClean:"/Public/!FilesTesting/bin" at:host];
    
    CopyingOptions opts;
    Copying op(FetchItems("/", {"bin"}, *VFSNativeHost::SharedHost()),
               "/Public/!FilesTesting/",
               host,
               opts);
    
    op.Start();
    op.Wait();
    
    int result = 0;
    XCTAssert( VFSCompareEntries("/bin",
                                 VFSNativeHost::SharedHost(),
                                 "/Public/!FilesTesting/bin",
                                 host,
                                 result) == 0);
    XCTAssert( result == 0 );
    
    [self EnsureClean:"/Public/!FilesTesting/bin" at:host];
}

- (void)testCopyGenericToGeneric_Modes_CopyToPrefix
{
    CopyingOptions opts;
    Copying op(FetchItems("/System/Applications/", {"Mail.app"}, *VFSNativeHost::SharedHost()),
               m_TmpDir.native(),
               m_NativeHost,
               opts);
    
    op.Start();
    op.Wait();

    int result = 0;
    XCTAssert( VFSCompareEntries(boost::filesystem::path("/System/Applications") / "Mail.app",
                                 VFSNativeHost::SharedHost(),
                                 m_TmpDir / "Mail.app",
                                 VFSNativeHost::SharedHost(),
                                 result) == 0);
    XCTAssert( result == 0 );
}

- (void)testCopyGenericToGeneric_Modes_CopyToPrefix_WithAbsentDirectoriesInPath
{
    // just like testCopyGenericToGeneric_Modes_CopyToPrefix but file copy operation should build a destination path
    boost::filesystem::path dst_dir = m_TmpDir / "Some" / "Absent" / "Dir" / "Is" / "Here/";
    
    CopyingOptions opts;
    Copying op(FetchItems("/System/Applications/", {"Mail.app"}, *VFSNativeHost::SharedHost()),
               dst_dir.native(),
               m_NativeHost,
               opts);
    
    op.Start();
    op.Wait();
    
    int result = 0;
    XCTAssert( VFSCompareEntries(boost::filesystem::path("/System/Applications") / "Mail.app",
                                 VFSNativeHost::SharedHost(),
                                 dst_dir / "Mail.app",
                                 VFSNativeHost::SharedHost(),
                                 result) == 0);
    XCTAssert( result == 0 );
}

// this test is now actually outdated, since FileCopyOperation now requires that destination path is absolute
- (void)testCopyGenericToGeneric_Modes_CopyToPrefix_WithLocalDir
{
    // works on single host - In and Out same as where source files are
    auto host = VFSNativeHost::SharedHost();
    
    XCTAssert( VFSEasyCopyNode("/System/Applications/Mail.app",
                               host,
                               (m_TmpDir / "Mail.app").c_str(),
                               host) == 0);
    
    CopyingOptions opts;
    Copying op(FetchItems(m_TmpDir.native(), {"Mail.app"}, *VFSNativeHost::SharedHost()),
               (m_TmpDir / "SomeDirectoryName/").native(),
               m_NativeHost,
               opts);
    
    op.Start();
    op.Wait();
    
    int result = 0;
    XCTAssert( VFSCompareEntries("/System/Applications/Mail.app", host, m_TmpDir / "SomeDirectoryName" / "Mail.app", host, result) == 0);
    XCTAssert( result == 0 );
}

// this test is now somewhat outdated, since FileCopyOperation now requires that destination path is absolute
- (void)testCopyGenericToGeneric_Modes_CopyToPathName_WithLocalDir
{
    // works on single host - In and Out same as where source files are
    // Copies "Mail.app" to "Mail2.app" in the same dir
    auto host = VFSNativeHost::SharedHost();
    
    XCTAssert( VFSEasyCopyNode("/System/Applications/Mail.app",
                               host,
                               (boost::filesystem::path(m_TmpDir) / "Mail.app").c_str(),
                               host) == 0);
    
    Copying op(FetchItems(m_TmpDir.native(), {"Mail.app"}, *VFSNativeHost::SharedHost()),
               (m_TmpDir / "Mail2.app").native(),
               m_NativeHost,
               {});
    
    op.Start();
    op.Wait();
    
    int result = 0;
    XCTAssert( VFSCompareEntries("/System/Applications/Mail.app", host, m_TmpDir / "Mail2.app", host, result) == 0);
    XCTAssert( result == 0 );
}

- (void)testCopyGenericToGeneric_Modes_CopyToPathName_SingleFile
{
    VFSHostPtr host;
    try {
        host = std::make_shared<FTPHost>(g_LocalFTP, "", "", "/");
    } catch( VFSErrorException &e ) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    const char *fn1 = "/System/Library/Kernels/kernel",
    *fn2 = "/Public/!FilesTesting/kernel",
    *fn3 = "/Public/!FilesTesting/kernel copy";
    
    [self EnsureClean:fn2 at:host];
    [self EnsureClean:fn3 at:host];
    
    {
        Copying op(FetchItems("/System/Library/Kernels/", {"kernel"}, *VFSNativeHost::SharedHost()),
                   "/Public/!FilesTesting/",
                   host,
                   {});
        op.Start();
        op.Wait();
    }
    
    int compare;
    XCTAssert( VFSEasyCompareFiles(fn1, VFSNativeHost::SharedHost(), fn2, host, compare) == 0);
    XCTAssert( compare == 0);
    
    
    {
        Copying op(FetchItems("/Public/!FilesTesting/", {"kernel"}, *host),
                   fn3,
                   host,
                   {});
        op.Start();
        op.Wait();
    }
    
    XCTAssert( VFSEasyCompareFiles(fn2, host, fn3, host, compare) == 0);
    XCTAssert( compare == 0);
    
    XCTAssert( host->Unlink(fn2, 0) == 0);
    XCTAssert( host->Unlink(fn3, 0) == 0);
}

- (void)testCopyGenericToGeneric_Modes_RenameToPathPreffix
{
    // works on single host - In and Out same as where source files are
    // Copies "Mail.app" to "Mail2.app" in the same dir
    auto dir2 = m_TmpDir / "Some" / "Dir" / "Where" / "Files" / "Should" / "Be" / "Renamed/";
    auto host = VFSNativeHost::SharedHost();
    
    XCTAssert( VFSEasyCopyNode("/System/Applications/Mail.app", host, (m_TmpDir / "Mail.app").c_str(), host) == 0);
    
    CopyingOptions opts;
    opts.docopy = false;
    Copying op(FetchItems(m_TmpDir.native(), {"Mail.app"}, *host),
               dir2.native(),
               host,
               opts);
    op.Start();
    op.Wait();
    
    int result = 0;
    XCTAssert( VFSCompareEntries("/System/Applications/Mail.app", host, dir2 / "Mail.app", host, result) == 0);
    XCTAssert( result == 0 );
}

- (void)testCopyGenericToGeneric_Modes_RenameToPathName
{
    // works on single host - In and Out same as where source files are
    // Copies "Mail.app" to "Mail2.app" in the same dir
    auto host = VFSNativeHost::SharedHost();
    
    XCTAssert( VFSEasyCopyNode("/System/Applications/Mail.app", host, (m_TmpDir / "Mail.app").c_str(), host) == 0);
    
    CopyingOptions opts;
    opts.docopy = false;
    Copying op(FetchItems(m_TmpDir.native(), {"Mail.app"}, *host),
               (m_TmpDir / "Mail2.app").native(),
               host,
               opts);
    op.Start();
    op.Wait();

    int result = 0;
    XCTAssert( VFSCompareEntries("/System/Applications/Mail.app", host, m_TmpDir / "Mail2.app", host, result) == 0);
    XCTAssert( result == 0 );
}

- (void)testCopyUnRARToXAttr
{
    VFSHostPtr host_src;
    try {
        host_src = std::make_shared<UnRARHost>(g_PhotosRAR.c_str(), VFSNativeHost::SharedHost() );
    } catch( VFSErrorException &e ) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    auto file = m_TmpDir / "tmp";
    fclose( fopen(file.c_str(), "w") );
    
    VFSHostPtr host_dst;
    try {
        host_dst = std::make_shared<XAttrHost>(file.c_str(), VFSNativeHost::SharedHost());
    } catch( VFSErrorException &e ) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    Copying op(FetchItems(reinterpret_cast<const char*>(u8"/Чемал-16/"), {"IMG_0257.JPG"}, *host_src),
               "/",
               host_dst,
               {});
    op.Start();
    op.Wait();
    
    int result = 0;
    XCTAssert( VFSEasyCompareFiles(reinterpret_cast<const char*>(u8"/Чемал-16/IMG_0257.JPG"),
        host_src, "/IMG_0257.JPG", host_dst, result) == 0);
    XCTAssert( result == 0 );
}

- (void)testSymlinksOverwriting
{
    symlink( "old_symlink_value", (m_TmpDir/"file1").c_str() );
    symlink( "new_symlink_value", (m_TmpDir/"file2").c_str() );
    
    CopyingOptions opts;
    opts.docopy = true;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
    auto host = VFSNativeHost::SharedHost();
    Copying op(FetchItems(m_TmpDir.c_str(), {"file2"}, *host),
               (m_TmpDir/"file1").c_str(),
               host,
               opts);

    op.Start();
    op.Wait();
    XCTAssert( op.State() == OperationState::Completed );
    XCTAssert( boost::filesystem::read_symlink(m_TmpDir/"file1") == "new_symlink_value" );
}

- (void)testOverwritingOfSymlinksInSubdir
{
    mkdir((m_TmpDir/"D1").c_str(), 0755);
    symlink( "old_symlink_value", (m_TmpDir/"D1"/"symlink").c_str() );
    mkdir((m_TmpDir/"D2").c_str(), 0755);
    mkdir((m_TmpDir/"D2"/"D1").c_str(), 0755);
    symlink( "new_symlink_value", (m_TmpDir/"D2"/"D1"/"symlink").c_str() );
    
    CopyingOptions opts;
    opts.docopy = true;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
    auto host = VFSNativeHost::SharedHost();
    Copying op(FetchItems((m_TmpDir/"D2").c_str(), {"D1"}, *host),
               m_TmpDir.c_str(),
               host,
               opts);
    
    op.Start();
    op.Wait();
    XCTAssert( op.State() == OperationState::Completed );
    XCTAssert( boost::filesystem::read_symlink(m_TmpDir/"D1"/"symlink") == "new_symlink_value" );
}

- (void)testSymlinkRenaming
{
    using namespace boost::filesystem;
    symlink( "symlink_value", (m_TmpDir/"file1").c_str() );
    
    CopyingOptions opts;
    opts.docopy = false;
    auto host = VFSNativeHost::SharedHost();
    Copying op(FetchItems(m_TmpDir.c_str(), {"file1"}, *host),
               (m_TmpDir/"file2").c_str(),
               host,
               opts);

    op.Start();
    op.Wait();
    XCTAssert( op.State() == OperationState::Completed );
    XCTAssert( symlink_status(m_TmpDir/"file1").type() == file_type::file_not_found );
    XCTAssert( read_symlink(m_TmpDir/"file2") == "symlink_value" );
}

static uint32_t FileFlags(const char *path)
{
    struct stat st;
    if( stat( path, &st ) != 0 )
        return 0;
    return st.st_flags;
}

- (void)testRenameDirIntoExistingDir
{
    using namespace boost::filesystem;
    // DirA/TestDir
    // DirB/TestDir
    // DirB/TestDir/file.txt
    mkdir( (m_TmpDir / "DirA").c_str(), 0755 );
    mkdir( (m_TmpDir / "DirA" / "TestDir").c_str(), 0755 );
    mkdir( (m_TmpDir / "DirB").c_str(), 0755 );
    mkdir( (m_TmpDir / "DirB" / "TestDir").c_str(), 0755 );
    chflags( (m_TmpDir / "DirB" / "TestDir").c_str(), UF_HIDDEN );
    close( open((m_TmpDir / "DirB" / "TestDir" / "file.txt").c_str(),
                O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    
    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteOld;
    auto host = VFSNativeHost::SharedHost();
    Copying op(FetchItems((m_TmpDir / "DirB").c_str(), {"TestDir"}, *host),
               (m_TmpDir/"DirA").c_str(),
               host,
               opts);
    
    op.Start();
    op.Wait();
    XCTAssert( op.State() == OperationState::Completed );
    XCTAssert(status(m_TmpDir / "DirB" / "TestDir").type() == file_type::file_not_found );
    XCTAssert(status(m_TmpDir / "DirA" / "TestDir" / "file.txt").type() == file_type::regular_file);
    XCTAssert((FileFlags((m_TmpDir / "DirA" / "TestDir").c_str()) & UF_HIDDEN ) != 0 );
}

- (void)testRenamingDirIntoExistingReg
{
    using namespace boost::filesystem;
    // DirA/item (file)
    // DirB/item (directory)
    mkdir( (m_TmpDir / "DirA").c_str(), 0755 );
    close( open((m_TmpDir / "DirA" / "item").c_str(),
                O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    mkdir( (m_TmpDir / "DirB").c_str(), 0755 );
    mkdir( (m_TmpDir / "DirB" / "item").c_str(), 0755 );
    
    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
    auto host = VFSNativeHost::SharedHost();
    Copying op(FetchItems((m_TmpDir / "DirB").c_str(), {"item"}, *host),
               (m_TmpDir/"DirA").c_str(),
               host,
               opts);
    
    op.Start();
    op.Wait();
    XCTAssert( op.State() == OperationState::Completed );
    XCTAssert(status(m_TmpDir / "DirB" / "item").type() == file_type::file_not_found );
    XCTAssert(status(m_TmpDir / "DirA" / "item").type() == file_type::directory_file );
}

- (void)testRenamingNonEmptyDirIntoExistingReg
{
    using namespace boost::filesystem;
    // DirA/item (file)
    // DirB/item (directory)
    // DirB/item/test
    mkdir( (m_TmpDir / "DirA").c_str(), 0755 );
    close( open((m_TmpDir / "DirA" / "item").c_str(),
                O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    mkdir( (m_TmpDir / "DirB").c_str(), 0755 );
    mkdir( (m_TmpDir / "DirB" / "item").c_str(), 0755 );
    close( open((m_TmpDir / "DirB" / "item" / "test").c_str(),
                O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    
    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::OverwriteAll;
    auto host = VFSNativeHost::SharedHost();
    Copying op(FetchItems((m_TmpDir / "DirB").c_str(), {"item"}, *host),
               (m_TmpDir/"DirA").c_str(),
               host,
               opts);
    
    op.Start();
    op.Wait();
    XCTAssert( op.State() == OperationState::Completed );
    XCTAssert(status(m_TmpDir / "DirB" / "item").type() == file_type::file_not_found );
    XCTAssert(status(m_TmpDir / "DirA" / "item").type() == file_type::directory_file );
    XCTAssert(status(m_TmpDir / "DirA" / "item" / "test").type() == file_type::regular_file );
}

- (void)testCopiedApplicationHasAValidSignature
{
    CopyingOptions opts;
    opts.docopy = true;
    auto host = VFSNativeHost::SharedHost();
    Copying op(FetchItems("/System/Applications", {"Mail.app"}, *host),
               m_TmpDir.c_str(),
               host,
               opts);
    op.Start();
    op.Wait();
    XCTAssert( op.State() == OperationState::Completed );
    const auto command = "/usr/bin/codesign --verify "s + (m_TmpDir/"Mail.app").native();
    XCTAssert( system( command.c_str() ) == 0);
}

- (boost::filesystem::path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir,
            "%s" "info.filesmanager.files" ".tmp.XXXXXX",
            NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

- (void) EnsureClean:(const std::string&)_fn at:(const VFSHostPtr&)_h
{
    VFSStat stat;
    if( _h->Stat(_fn.c_str(), stat, 0, 0) == 0)
        XCTAssert( VFSEasyDelete(_fn.c_str(), _h) == 0);
}

static int VFSCompareEntries(const boost::filesystem::path& _file1_full_path,
                             const VFSHostPtr& _file1_host,
                             const boost::filesystem::path& _file2_full_path,
                             const VFSHostPtr& _file2_host,
                             int &_result)
{
    // not comparing flags, perm, times, xattrs, acls etc now
    
    VFSStat st1, st2;
    int ret;
    if((ret =_file1_host->Stat(_file1_full_path.c_str(), st1, 0, 0)) != 0)
        return ret;

    if((ret =_file2_host->Stat(_file2_full_path.c_str(), st2, 0, 0)) != 0)
        return ret;
    
    if((st1.mode & S_IFMT) != (st2.mode & S_IFMT))
    {
        _result = -1;
        return 0;
    }
    
    if( S_ISREG(st1.mode) )
    {
        _result = int(int64_t(st1.size) - int64_t(st2.size));
        return 0;
    }
    else if ( S_ISDIR(st1.mode) )
    {
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

- (void)testCopyingToExistingItemWithKeepingBothResultsInOrigWithCopiedWithAnotherName
{
    using namespace boost::filesystem;
    // DirA/item (file)
    // DirB/item (file)
    mkdir( (m_TmpDir / "DirA").c_str(), 0755 );
    close( open((m_TmpDir / "DirA" / "item").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    mkdir( (m_TmpDir / "DirB").c_str(), 0755 );
    close( open((m_TmpDir / "DirB" / "item").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    
    CopyingOptions opts;
    opts.docopy = true;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = VFSNativeHost::SharedHost();
    Copying op(FetchItems((m_TmpDir / "DirB").c_str(), {"item"}, *host),
               (m_TmpDir/"DirA").c_str(),
               host,
               opts);
    
    op.Start();
    op.Wait();
    XCTAssert( op.State() == OperationState::Completed );
    XCTAssert( status(m_TmpDir / "DirA" / "item 2").type() == file_type::regular_file );
}

- (void)testRenamingToExistingItemWithKeepingBothResultsInOrigRenamedWithAnotherName
{
    using namespace boost::filesystem;
    // DirA/item (file)
    // DirB/item (file)
    mkdir( (m_TmpDir / "DirA").c_str(), 0755 );
    close( open((m_TmpDir / "DirA" / "item").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    mkdir( (m_TmpDir / "DirB").c_str(), 0755 );
    close( open((m_TmpDir / "DirB" / "item").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    
    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = VFSNativeHost::SharedHost();
    Copying op(FetchItems((m_TmpDir / "DirB").c_str(), {"item"}, *host),
               (m_TmpDir/"DirA").c_str(),
               host,
               opts);
    
    op.Start();
    op.Wait();
    XCTAssert( op.State() == OperationState::Completed );
    XCTAssert(status(m_TmpDir / "DirA" / "item 2").type() == file_type::regular_file );
    XCTAssert(status(m_TmpDir / "DirB" / "item").type() == file_type::file_not_found );    
}

- (void)testCopyingSymlinkToExistingItemWithKeepingBothResultsInOrigCopiedWithAnotherName
{
    using namespace boost::filesystem;
    // DirA/item (file)
    // DirB/item (file)
    mkdir( (m_TmpDir / "DirA").c_str(), 0755 );
    close( open((m_TmpDir / "DirA" / "item").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    mkdir( (m_TmpDir / "DirB").c_str(), 0755 );
    symlink("something", (m_TmpDir / "DirB" / "item").c_str());
    
    CopyingOptions opts;
    opts.docopy = true;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = VFSNativeHost::SharedHost();
    Copying op(FetchItems((m_TmpDir / "DirB").c_str(), {"item"}, *host),
               (m_TmpDir/"DirA").c_str(),
               host,
               opts);
    
    op.Start();
    op.Wait();
    XCTAssert( op.State() == OperationState::Completed );
    XCTAssert( symlink_status(m_TmpDir / "DirA" / "item 2").type() == file_type::symlink_file );        
}

- (void)testRenamingSymlinkToExistingItemWithKeepingBothResultsInOrigRenamedWithAnotherName
{
    using namespace boost::filesystem;
    // DirA/item (file)
    // DirB/item (file)
    mkdir( (m_TmpDir / "DirA").c_str(), 0755 );
    close( open((m_TmpDir / "DirA" / "item").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    mkdir( (m_TmpDir / "DirB").c_str(), 0755 );
    symlink("something", (m_TmpDir / "DirB" / "item").c_str());
    
    CopyingOptions opts;
    opts.docopy = false;
    opts.exist_behavior = CopyingOptions::ExistBehavior::KeepBoth;
    auto host = VFSNativeHost::SharedHost();
    Copying op(FetchItems((m_TmpDir / "DirB").c_str(), {"item"}, *host),
               (m_TmpDir/"DirA").c_str(),
               host,
               opts);
    
    op.Start();
    op.Wait();
    XCTAssert( op.State() == OperationState::Completed );
    XCTAssert( symlink_status(m_TmpDir / "DirA" / "item 2").type() == file_type::symlink_file ); 
    XCTAssert( status(m_TmpDir / "DirB" / "item").type() == file_type::file_not_found );    
}

@end


@interface Copying_FindNonExistingItemPath_Tests : XCTestCase
@end

@implementation Copying_FindNonExistingItemPath_Tests
{
    boost::filesystem::path m_TmpDir;
    std::shared_ptr<VFSHost> m_NativeHost;
}

- (void)setUp
{
    [super setUp];
    m_NativeHost = VFSNativeHost::SharedHost();
    char dir[MAXPATHLEN];
    sprintf(dir,
            "%s" "info.filesmanager.files" ".tmp.XXXXXX",
            NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    m_TmpDir = dir;
}

- (void)tearDown
{
    VFSEasyDelete(m_TmpDir.c_str(), VFSNativeHost::SharedHost());
    [super tearDown];
}

- (void) testRegularFileWithoutExtension
{
    auto orig_path = m_TmpDir / "item"; 
    close( open((orig_path / "item").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );    
    
    auto proposed_path = copying::FindNonExistingItemPath(orig_path.native(), *m_NativeHost); 
    
    XCTAssert( proposed_path == (m_TmpDir / "item 2").native() );
}

- (void) testDoesntCheckTheInitialPath
{
    auto orig_path = m_TmpDir / "item";     

    auto proposed_path = copying::FindNonExistingItemPath(orig_path.native(), *m_NativeHost); 
    
    XCTAssert( proposed_path == (m_TmpDir / "item 2").native() );
}

- (void) testRegularFileWithoutExtensionWhenPossibleTargetsAlreadyExist
{
    auto orig_path = m_TmpDir / "item"; 
    close( open((m_TmpDir / "item").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    close( open((m_TmpDir / "item 2").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );    
    close( open((m_TmpDir / "item 3").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    close( open((m_TmpDir / "item 4").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    
    auto proposed_path = copying::FindNonExistingItemPath(orig_path.native(), *m_NativeHost); 
    
    XCTAssert( proposed_path == (m_TmpDir / "item 5").native() );
}

- (void) testRegularFileWithExtension
{
    auto orig_path = m_TmpDir / "item.zip";
    
    auto proposed_path = copying::FindNonExistingItemPath(orig_path.native(), *m_NativeHost); 
    
    XCTAssert( proposed_path == (m_TmpDir / "item 2.zip").native() );
}

- (void) testRegularFileWithExtensionWhenPossibleTargetsAlreadyExist
{
    auto orig_path = m_TmpDir / "item.zip"; 
    close( open((m_TmpDir / "item.zip").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    close( open((m_TmpDir / "item 2.zip").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );    
    close( open((m_TmpDir / "item 3.zip").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    close( open((m_TmpDir / "item 4.zip").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    
    auto proposed_path = copying::FindNonExistingItemPath(orig_path.native(), *m_NativeHost); 
    
    XCTAssert( proposed_path == (m_TmpDir / "item 5.zip").native() );
}

- (void) testChecksMagnitudesOfTens
{
    auto orig_path = m_TmpDir / "item.zip"; 
    close( open((m_TmpDir / "item.zip").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    for( int i = 2; i <= 9; ++i )
        close( open((m_TmpDir / ("item " + std::to_string(i) + ".zip")).c_str(),
                     O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );    
    
    auto proposed_path = copying::FindNonExistingItemPath(orig_path.native(), *m_NativeHost); 
    
    XCTAssert( proposed_path == (m_TmpDir / "item 10.zip").native() );
}

- (void) testChecksMagnitudesOfHundreds
{
    auto orig_path = m_TmpDir / "item.zip"; 
    close( open((m_TmpDir / "item.zip").c_str(), O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );
    for( int i = 2; i <= 99; ++i )
        close( open((m_TmpDir / ("item " + std::to_string(i) + ".zip")).c_str(),
                    O_WRONLY|O_CREAT, S_IWUSR | S_IRUSR) );    
    
    auto proposed_path = copying::FindNonExistingItemPath(orig_path.native(), *m_NativeHost); 
    
    XCTAssert( proposed_path == (m_TmpDir / "item 100.zip").native() );
}

- (void) testReturnsEmptyStringOnCancellation
{
    auto orig_path = m_TmpDir / "item.zip";
    auto cancel = []{ return true; };
    
    auto proposed_path = copying::FindNonExistingItemPath(orig_path.native(),
                                                          *m_NativeHost,
                                                          cancel); 
    
    XCTAssert( proposed_path == "" );
}

@end
