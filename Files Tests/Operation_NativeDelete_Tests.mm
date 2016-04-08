//
//  Operation_Deletion_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 08.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "tests_common.h"
#include "../Files/VFS/vfs_native.h"
#include "../Files/Operations/Delete/FileDeletionOperation.h"

static vector<VFSListingItem> FetchItems(const string& _directory_path,
                                         const vector<string> &_filenames,
                                         VFSHost &_host)
{
    vector<VFSListingItem> items;
    _host.FetchFlexibleListingItems(_directory_path, _filenames, 0, items, nullptr);
    return items;
}

@interface Operation_Deletion_Tests : XCTestCase

@end

@implementation Operation_Deletion_Tests

- (void)testPermanentDeletion
{
    char dir[MAXPATHLEN];
    sprintf(dir, "%s" "info.filesmanager.files" ".tmp.XXXXXX", NSTemporaryDirectory().fileSystemRepresentation);
    XCTAssert( mkdtemp(dir) != nullptr );
    
    XCTAssert( VFSEasyCopyNode("/Applications/Mail.app",
                               VFSNativeHost::SharedHost(),
                               (path(dir) / "Mail.app").c_str(),
                               VFSNativeHost::SharedHost()) == 0);
    
    FileDeletionOperation *op = [FileDeletionOperation alloc];
    
    op = [op initWithFiles:FetchItems(dir, {"Mail.app"}, *VFSNativeHost::SharedHost())
                      type:FileDeletionOperationType::Delete
          ];
    
    __block bool finished = false;
    [op AddOnFinishHandler:^{ finished = true; }];
    [op Start];
    [self waitUntilFinish:finished];
    
    // check that dir has gone
    VFSStat st;
    XCTAssert( VFSNativeHost::SharedHost()->Stat((path(dir) / "Mail.app").c_str(), st, 0, 0) != 0);
    XCTAssert( VFSNativeHost::SharedHost()->RemoveDirectory(dir, 0) == 0);
}

- (void) waitUntilFinish:(volatile bool&)_finished
{
    microseconds sleeped = 0us, sleep_tresh = 60s;
    while (!_finished)
    {
        this_thread::sleep_for(100us);
        sleeped += 100us;
        XCTAssert( sleeped < sleep_tresh);
        if(sleeped > sleep_tresh)
            break;
    }
}

@end
