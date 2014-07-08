//
//  TermShellTask_Tests.mm
//  Files
//
//  Created by Michael G. Kazakov on 08/07/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "tests_common.h"
#include "TermShellTask.h"
#include "common_paths.h"

@interface TermShellTask_Tests : XCTestCase
@end

@implementation TermShellTask_Tests

- (void)testBasic {
    TermShellTask shell;
    string cwd = CommonPaths::Get(CommonPaths::Home);
    shell.Launch(cwd.c_str(), 100, 100);
    usleep(100000); // 100msec should be enough for init process
    
    // check cwd
    XCTAssert( shell.CWD() == cwd );
    
    // the only task is running is shell itself, and is not returned by ChildrenList
    XCTAssert( shell.ChildrenList().empty() );

    // test executing binaries within a shell
    shell.ExecuteWithFullPath("/usr/bin/top", nullptr);
    usleep(100000);
    XCTAssert( shell.ChildrenList().size() == 1 );
    XCTAssert( shell.ChildrenList()[0] == "top" );
    
    // simulates user press Q to quit top
    shell.WriteChildInput("q", 1);
    usleep(100000);
    XCTAssert( shell.ChildrenList().empty() );
  
    // check chdir
    cwd = CommonPaths::Get(CommonPaths::Home) + "/Downloads";
    shell.ChDir( cwd.c_str() );
    usleep(100000);
    XCTAssert( shell.CWD() == cwd );    
}


@end
