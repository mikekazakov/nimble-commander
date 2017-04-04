#include "tests_common.h"
#include <VFS/NetDropbox.h>

static const auto g_Token = "-chTBf0f5HAAAAAAAAAACybjBH4SYO9sh3HrD_TtKyUusrLu0yWYustS3CdlqYkN";

@interface VFSDropbox_Tests : XCTestCase
@end

@implementation VFSDropbox_Tests

- (void)testStatfs
{
    shared_ptr<VFSHost> host = make_shared<VFSNetDropboxHost>(g_Token);

    VFSStatFS statfs;
    XCTAssert( host->StatFS( "/", statfs ) == 0 );
    XCTAssert( statfs.total_bytes == 2147483648 );
    XCTAssert( statfs.free_bytes > 0 && statfs.free_bytes < statfs.total_bytes );
}


- (void)testStatOnExistingFile
{
    auto filepath = "/TestSet01/11778860-R3L8T8D-650-funny-jumping-cats-51__880.jpg";

    shared_ptr<VFSHost> host = make_shared<VFSNetDropboxHost>(g_Token);
    
    VFSStat stat;
    XCTAssert( host->Stat( filepath, stat, 0 ) == 0 );
    XCTAssert( stat.mode_bits.reg == true );
    XCTAssert( stat.mode_bits.dir == false );
    XCTAssert( stat.size == 190892 );
    
    auto date = [[NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian ]
        components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay
        fromDate:[NSDate dateWithTimeIntervalSince1970:stat.mtime.tv_sec]];
    XCTAssert(date.year == 2017 && date.month == 4 && date.day == 3);
}

- (void)testStatOnExistingFolder
{
    auto filepath = "/TestSet01/";

    shared_ptr<VFSHost> host = make_shared<VFSNetDropboxHost>(g_Token);
    
    VFSStat stat;
    XCTAssert( host->Stat( filepath, stat, 0 ) == 0 );
    XCTAssert( stat.mode_bits.dir == true );
    XCTAssert( stat.mode_bits.reg == false );
}

- (void)testDirectoryIterating
{
    auto filepath = "/TestSet01/";
    auto must_be = set<string>{ {"1ee0209db65d40d68277687017871bda.gif", "5465bdfd6afa44288520f2c84d2bb011.jpg",
    "11778860-R3L8T8D-650-funny-jumping-cats-51__880.jpg", "11779310-R3L8T8D-650-funny-jumping-cats-91__880.jpg",
    "BsQMH1kCUAALgMC.jpg", "f447bd6f4f6a47e6a355b7b44f2a326f.jpg", "kvxnws0o3i3g.jpg", "vw1yzox23csh.jpg"
    }  };
    shared_ptr<VFSHost> host = make_shared<VFSNetDropboxHost>(g_Token);
    
    set<string> filenames;
    int rc = host->IterateDirectoryListing(filepath, [&](const VFSDirEnt &_e){
        filenames.emplace( _e.name );
        return true;
    });
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( filenames == must_be );
}

- (void)testLargeDirectoryIterating
{
    auto filepath = "/TestSet02/";
    shared_ptr<VFSHost> host = make_shared<VFSNetDropboxHost>(g_Token);
    set<string> filenames;
    int rc = host->IterateDirectoryListing(filepath, [&](const VFSDirEnt &_e){
        filenames.emplace( _e.name );
        return true;
    });
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( filenames.count("ActionShortcut.h") );
    XCTAssert( filenames.count("xattr.h") );
    XCTAssert( filenames.size() == 501 );
}

- (void)testDirectoryListing
{
    shared_ptr<VFSHost> host = make_shared<VFSNetDropboxHost>(g_Token);
    VFSListingPtr listing;
    int rc = host->FetchDirectoryListing("/", listing, 0);
    XCTAssert( rc == VFSError::Ok );
}

- (void)testBasicFileRead
{
    auto filepath = "/TestSet01/11778860-R3L8T8D-650-funny-jumping-cats-51__880.jpg";
    shared_ptr<VFSHost> host = make_shared<VFSNetDropboxHost>(g_Token);
    shared_ptr<VFSFile> file;
    int rc = host->CreateFile(filepath, file);
    XCTAssert( rc == VFSError::Ok );

    rc = file->Open( VFSFlags::OF_Read );
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( file->Size() == 190892 );
    
    auto data = file->ReadFile();
    XCTAssert( data );
    XCTAssert( data->size() == 190892 );
    XCTAssert( data->back() == 0xD9 );
}

- (void)testReadingOfFileWithNonASCIISymbols
{
    auto filepath = @"/TestSet03/Это фотка котега $о ВСЯкими #\"символами\"!!!.jpg";
    shared_ptr<VFSHost> host = make_shared<VFSNetDropboxHost>(g_Token);
    shared_ptr<VFSFile> file;
    int rc = host->CreateFile(filepath.UTF8String, file);
    XCTAssert( rc == VFSError::Ok );

    rc = file->Open( VFSFlags::OF_Read );
    XCTAssert( rc == VFSError::Ok );
    XCTAssert( file->Size() == 253899 );
    
    auto data = file->ReadFile();
    XCTAssert( data );
    XCTAssert( data->size() == 253899 );
    XCTAssert( data->front() == 0xFF );
    XCTAssert( data->back() == 0xD9 );
}



@end
