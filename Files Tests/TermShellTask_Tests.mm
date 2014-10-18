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
#include "common.h"

static void testMicrosleep(uint64_t _microseconds)
{
    if( dispatch_is_main_queue() ) {
        double secs = double(_microseconds) / USEC_PER_SEC;
        NSDate *when = [NSDate dateWithTimeIntervalSinceNow:secs];
        do {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:when];
            if ([when timeIntervalSinceNow] < 0.0)
                break;
        } while(1);
    }
    else
        this_thread::sleep_for(microseconds(_microseconds));
}

@interface TermShellTask_Tests : XCTestCase
@end

@implementation TermShellTask_Tests

- (void)testBasic {
    TermShellTask shell;
    XCTAssert( shell.State() == TermShellTask::StateInactive );
    
    string cwd = CommonPaths::Get(CommonPaths::Home);
    shell.Launch(cwd.c_str(), 100, 100);
    testMicrosleep( microseconds(5s).count() );
    
    // check cwd
    NSLog(@"%s | %s", shell.CWD().c_str(), cwd.c_str());
    XCTAssert( shell.CWD() == cwd );
    XCTAssert( shell.State() == TermShellTask::StateShell);
    
    // the only task is running is shell itself, and is not returned by ChildrenList
    XCTAssert( shell.ChildrenList().empty() );

    // test executing binaries within a shell
    shell.ExecuteWithFullPath("/usr/bin/top", nullptr);
    testMicrosleep( microseconds(1s).count() );
    XCTAssert( shell.ChildrenList().size() == 1 );
    XCTAssert( shell.ChildrenList()[0] == "top" );
    XCTAssert( shell.State() == TermShellTask::StateProgramExternal);
    
    // simulates user press Q to quit top
    shell.WriteChildInput("q", 1);
    testMicrosleep( microseconds(1s).count() );
    XCTAssert( shell.ChildrenList().empty() );
    XCTAssert( shell.State() == TermShellTask::StateShell);
  
    // check chdir
    cwd = CommonPaths::Get(CommonPaths::Home) + "/Downloads";
    shell.ChDir( cwd.c_str() );
    testMicrosleep( microseconds(1s).count() );
    XCTAssert( shell.CWD() == cwd );
    XCTAssert( shell.State() == TermShellTask::StateShell);
    
    // test chdir in the middle of some typing
    shell.WriteChildInput("ls ", 3);
    cwd = CommonPaths::Get(CommonPaths::Home);
    shell.ChDir( cwd.c_str() );
    testMicrosleep( microseconds(1s).count() );
    XCTAssert( shell.CWD() == cwd );
    XCTAssert( shell.State() == TermShellTask::StateShell);

    // check internal program state
    shell.WriteChildInput("top\r", 4);
    testMicrosleep( microseconds(1s).count() );
    XCTAssert( shell.ChildrenList().size() == 1 );
    XCTAssert( shell.ChildrenList()[0] == "top" );
    XCTAssert( shell.State() == TermShellTask::StateProgramInternal );

    // check termination
    shell.Terminate();
    XCTAssert( shell.ChildrenList().empty() );
    XCTAssert( shell.State() == TermShellTask::StateInactive );
    
    // check execution with short path in different directory
    shell.Launch(CommonPaths::Get(CommonPaths::Home).c_str(), 100, 100);
    testMicrosleep( microseconds(1s).count() );
    shell.Execute("top", "/usr/bin/", nullptr);
    testMicrosleep( microseconds(1s).count() );
    XCTAssert( shell.ChildrenList().size() == 1 );
    XCTAssert( shell.ChildrenList()[0] == "top" );
    XCTAssert( shell.State() == TermShellTask::StateProgramExternal );
    
    shell.Terminate();
    XCTAssert( shell.ChildrenList().empty() );
}

@end
