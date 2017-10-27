#import <XCTest/XCTest.h>
#include <VFS/Native.h>
#include <VFS/ArcLA.h>
#include "../source/Copying/Copying.h"
#include "../source/Compression/Compression.h"

using namespace nc;
using namespace nc::ops;

static const string g_Preffix = string(NCE(nc::env::test::ext_data_prefix)) + "archives/";
static const string g_XNU   = g_Preffix + "xnu-2050.18.24.tar";
static const string g_XNU2  = g_Preffix + "xnu-3248.20.55.tar";
static const string g_Adium = g_Preffix + "adium.app.zip";
static const string g_Angular = g_Preffix + "angular-1.4.0-beta.4.zip";
static const string g_Files = g_Preffix + "files-1.1.0(1341).zip";
static const string g_Encrypted = g_Preffix + "encrypted_archive_pass1.zip";
static const string g_FileWithXAttr = "Leopard WaR3z.icns";

@interface Archive_Tests : XCTestCase
@end

static int VFSCompareEntries(const path& _file1_full_path,
                             const VFSHostPtr& _file1_host,
                             const path& _file2_full_path,
                             const VFSHostPtr& _file2_host,
                             int &_result);

static vector<VFSListingItem> FetchItems(const string& _directory_path,
                                         const vector<string> &_filenames,
                                         VFSHost &_host)
{
    vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}

@implementation Archive_Tests
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

- (void)testAdiumZip_CopyFromVFS
{
    shared_ptr<vfs::ArchiveHost> host;
    try {
        host = make_shared<vfs::ArchiveHost>(g_Adium.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    CopyingOptions opts;
    Copying op(FetchItems("/", {"Adium.app"}, *host),
               m_TmpDir.native(),
               m_NativeHost,
               opts);
    op.Start();
    op.Wait();
    
    int result = 0;
    XCTAssert( VFSCompareEntries("/Adium.app", host, m_TmpDir / "Adium.app", VFSNativeHost::SharedHost(), result) == 0);
    XCTAssert( result == 0 );
}

- (void)testExtractedFilesSignature
{
    shared_ptr<vfs::ArchiveHost> host;
    try {
        host = make_shared<vfs::ArchiveHost>(g_Files.c_str(), VFSNativeHost::SharedHost());
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    CopyingOptions opts;
    Copying op(FetchItems("/", {"Files.app"}, *host),
               m_TmpDir.native(),
               m_NativeHost,
               opts);
    op.Start();
    op.Wait();
    
    const auto command = "/usr/bin/codesign --verify "s + (m_TmpDir/"Files.app").native();
    XCTAssert( system( command.c_str() ) == 0);
}

- (void) testCompressingItemsWithBigXAttrs
{    
    auto item = FetchItems(g_Preffix, {g_FileWithXAttr}, *m_NativeHost);
    
    Compression operation{item, m_TmpDir.native(), m_NativeHost };
    operation.Start();
    operation.Wait();

    shared_ptr<vfs::ArchiveHost> host;
    try {
        host = make_shared<vfs::ArchiveHost>( operation.ArchivePath().c_str(), m_NativeHost);
    } catch (VFSErrorException &e) {
        XCTAssert( e.code() == 0 );
        return;
    }
    
    int result = 0;
    XCTAssert( VFSCompareEntries( "/" + g_FileWithXAttr, host,
                                 g_Preffix + g_FileWithXAttr, VFSNativeHost::SharedHost(),
                                 result)
              == 0);
    XCTAssert( result == 0 );
}

- (path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" "info.filesmanager.files" ".tmp.XXXXXX", NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

@end


static int VFSCompareEntries(const path& _file1_full_path,
                             const VFSHostPtr& _file1_host,
                             const path& _file2_full_path,
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
