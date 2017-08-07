#import <XCTest/XCTest.h>
#include <sys/stat.h>
#include <VFS/Native.h>
#include "../source/Copying/Copying.h"

using namespace nc::ops;
static const path g_DataPref = "/.FilesTestingData";

static vector<VFSListingItem> FetchItems(const string& _directory_path,
                                                 const vector<string> &_filenames,
                                                 VFSHost &_host)
{
    vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}


@interface CopyingTests : XCTestCase
@end

@implementation CopyingTests

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

- (path)makeTmpDir
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" "info.filesmanager.files" ".tmp.XXXXXX", NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    return dir;
}

- (void) waitUntilFinish:(volatile bool&)_finished
{
    microseconds sleeped = 0us, sleep_tresh = 60s;
    while (!_finished) {
        this_thread::sleep_for(100us);
        sleeped += 100us;
        XCTAssert( sleeped < sleep_tresh);
        if(sleeped > sleep_tresh)
            break;
    }
}

@end
