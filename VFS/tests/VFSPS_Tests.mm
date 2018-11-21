// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "tests_common.h"
#include <VFS/PS.h>

using namespace nc::vfs;
using namespace std;

@interface VFSPS_Tests : XCTestCase
@end

@implementation VFSPS_Tests

- (void)testBasic
{
    auto host = make_shared<PSHost>();
    VFSListingPtr list;
    host->FetchDirectoryListing("/", list, 0, 0);

    bool has_launchd = false;
    bool has_kernel_task = false;
    //    int a =10;
    for(auto &i: *list) {
        if("    0 - kernel_task.txt" == i.Filename())
            has_kernel_task = true;
        if("    1 - launchd.txt" == i.Filename())
            has_launchd = true;
    }

    XCTAssert( has_launchd == true );
    XCTAssert( has_kernel_task == true );
    XCTAssert( list->Count() > 100 ); // presumably any modern OSX will have more than 100 processes
}


@end
