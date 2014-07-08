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
    XCTAssert( shell.State() == TermShellTask::StateInactive );
    
    string cwd = CommonPaths::Get(CommonPaths::Home);
    shell.Launch(cwd.c_str(), 100, 100);
    usleep(100000); // 100msec should be enough for init process
    
    // check cwd
    XCTAssert( shell.CWD() == cwd );
    XCTAssert( shell.State() == TermShellTask::StateShell);
    
    // the only task is running is shell itself, and is not returned by ChildrenList
    XCTAssert( shell.ChildrenList().empty() );

    // test executing binaries within a shell
    shell.ExecuteWithFullPath("/usr/bin/top", nullptr);
    usleep(100000);
    XCTAssert( shell.ChildrenList().size() == 1 );
    XCTAssert( shell.ChildrenList()[0] == "top" );
    XCTAssert( shell.State() == TermShellTask::StateProgramExternal);
    
    // simulates user press Q to quit top
    shell.WriteChildInput("q", 1);
    usleep(100000);
    XCTAssert( shell.ChildrenList().empty() );
    XCTAssert( shell.State() == TermShellTask::StateShell);
  
    // check chdir
    cwd = CommonPaths::Get(CommonPaths::Home) + "/Downloads";
    shell.ChDir( cwd.c_str() );
    usleep(100000);
    XCTAssert( shell.CWD() == cwd );
    XCTAssert( shell.State() == TermShellTask::StateShell);
    
    // test chdir in the middle of some typing
    shell.WriteChildInput("ls ", 3);
    cwd = CommonPaths::Get(CommonPaths::Home);
    shell.ChDir( cwd.c_str() );
    usleep(100000);
    XCTAssert( shell.CWD() == cwd );
    XCTAssert( shell.State() == TermShellTask::StateShell);

    // check internal program state
    shell.WriteChildInput("top\r", 4);
    usleep(100000);
    XCTAssert( shell.ChildrenList().size() == 1 );
    XCTAssert( shell.ChildrenList()[0] == "top" );
    XCTAssert( shell.State() == TermShellTask::StateProgramInternal );

    // check termination
    shell.Terminate();
    XCTAssert( shell.ChildrenList().empty() );
    XCTAssert( shell.State() == TermShellTask::StateInactive );
    
    // check execution with short path in different directory
    shell.Launch(CommonPaths::Get(CommonPaths::Home).c_str(), 100, 100);
    usleep(100000); // 100msec should be enough for init process
    shell.Execute("top", "/usr/bin/", nullptr);
    usleep(100000);
    XCTAssert( shell.ChildrenList().size() == 1 );
    XCTAssert( shell.ChildrenList()[0] == "top" );
    XCTAssert( shell.State() == TermShellTask::StateProgramExternal );
}

@end
