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



@end
