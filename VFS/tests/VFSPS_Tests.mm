//
//  VFSPS_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 26.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "tests_common.h"
#include <VFS/PS.h>

@interface VFSPS_Tests : XCTestCase
@end

@implementation VFSPS_Tests

- (void)testBasic
{
    auto host = make_shared<VFSPSHost>();
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
