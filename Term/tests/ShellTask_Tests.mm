//
//  TermShellTask_Tests.mm
//  Files
//
//  Created by Michael G. Kazakov on 08/07/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/CommonPaths.h>
#import <XCTest/XCTest.h>
#include "ShellTask.h"
#include "Screen.h"
#include "Parser.h"

using namespace nc::term;

static void testSleep(microseconds _us)
{
    if( dispatch_is_main_queue() ) {
        NSDate *when = [NSDate dateWithTimeIntervalSinceNow:double(_us.count()) / USEC_PER_SEC];
        do {
            [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:when];
            if( when.timeIntervalSinceNow < 0.0 )
                break;
        } while(1);
    }
    else
        this_thread::sleep_for(_us);
}


static string ToRealPath(const string &_from)
{
    int tfd = open(_from.c_str(), O_RDONLY);
    if(tfd == -1)
        return _from;
    char path_out[MAXPATHLEN];
    int ret = fcntl(tfd, F_GETPATH, path_out);
    close(tfd);
    if(ret == -1)
        return _from;
    return path_out;
}

@interface TermShellTask_Tests : XCTestCase
@end

@implementation TermShellTask_Tests

- (void)testBasic {
    ShellTask shell;
    XCTAssert( shell.State() == ShellTask::TaskState::Inactive );
    
    string cwd = CommonPaths::Home();
    shell.ResizeWindow(100, 100);
    shell.Launch(cwd.c_str());
    testSleep( 5s );
    
    // check cwd
    XCTAssert( ToRealPath(shell.CWD()) == ToRealPath(cwd) );
    XCTAssert( shell.State() == ShellTask::TaskState::Shell);
    
    // the only task is running is shell itself, and is not returned by ChildrenList
    XCTAssert( shell.ChildrenList().empty() );

    // test executing binaries within a shell
    shell.ExecuteWithFullPath("/usr/bin/top", nullptr);
    testSleep( 1s );
    XCTAssert( shell.ChildrenList().size() == 1 );
    XCTAssert( shell.ChildrenList()[0] == "top" );
    XCTAssert( shell.State() == ShellTask::TaskState::ProgramExternal);
    
    // simulates user press Q to quit top
    shell.WriteChildInput("q");
    testSleep( 1s );
    XCTAssert( shell.ChildrenList().empty() );
    XCTAssert( shell.State() == ShellTask::TaskState::Shell);
  
    // check chdir
    cwd = CommonPaths::Home() + "Downloads/";
    shell.ChDir( cwd.c_str() );
    testSleep( 1s );
    XCTAssert( shell.CWD() == cwd );
    XCTAssert( shell.State() == ShellTask::TaskState::Shell);
    
    // test chdir in the middle of some typing
    shell.WriteChildInput("ls ");
    cwd = CommonPaths::Home();
    shell.ChDir( cwd.c_str() );
    testSleep( 1s );
    XCTAssert( shell.CWD() == cwd );
    XCTAssert( shell.State() == ShellTask::TaskState::Shell);

    // check internal program state
    shell.WriteChildInput("top\r");
    testSleep( 1s );
    XCTAssert( shell.ChildrenList().size() == 1 );
    XCTAssert( shell.ChildrenList()[0] == "top" );
    XCTAssert( shell.State() == ShellTask::TaskState::ProgramInternal );

    // check termination
    shell.Terminate();
    XCTAssert( shell.ChildrenList().empty() );
    XCTAssert( shell.State() == ShellTask::TaskState::Inactive );
    
    // check execution with short path in different directory
    shell.Launch(CommonPaths::Home().c_str());
    testSleep( 1s );
    shell.Execute("top", "/usr/bin/", nullptr);
    testSleep( 1s );
    XCTAssert( shell.ChildrenList().size() == 1 );
    XCTAssert( shell.ChildrenList()[0] == "top" );
    XCTAssert( shell.State() == ShellTask::TaskState::ProgramExternal );
    
    shell.Terminate();
    XCTAssert( shell.ChildrenList().empty() );
}

- (void)testVim1
{
    auto shell = make_shared<ShellTask>();
    auto screen = make_shared<Screen>(40, 10);
    auto parser = make_shared<Parser>(*screen,
                                          [&](const void* _d, int _sz){
                                              shell->WriteChildInput( string_view((const char*)_d, _sz) );
                                          });

    shell->SetOnChildOutput([&](const void* _d, int _sz){
        auto lock = screen->AcquireLock();
        parser->EatBytes((const unsigned char*)_d, _sz);
    });
    
    unlink((CommonPaths::Home() + ".vim_test.swp").c_str());
    shell->ResizeWindow(40, 10);
    shell->Launch(CommonPaths::Home().c_str());
    testSleep( 5s );

    shell->WriteChildInput("vim vim_test\r");
    testSleep( 1s );
    {
        auto l = screen->AcquireLock();
        XCTAssert( screen->Buffer().DumpScreenAsANSI() ==
                  "                                        "
                  "~                                       "
                  "~                                       "
                  "~                                       "
                  "~                                       "
                  "~                                       "
                  "~                                       "
                  "~                                       "
                  "~                                       "
                  "\"vim_test\" [New File]                   " );
    }
    
    shell->WriteChildInput("i1\r2\r3\r4\r5\r");
    testSleep( 1s );
    
    shell->WriteChildInput("\eOA");
    testSleep( 1s );
    shell->WriteChildInput("\eOA");
    testSleep( 1s );
    shell->WriteChildInput("\r");
    testSleep( 1s );
    
    {
        auto l = screen->AcquireLock();
        XCTAssert( screen->Buffer().DumpScreenAsANSI() ==
                  "1                                       "
                  "2                                       "
                  "3                                       "
                  "                                        "
                  "4                                       "
                  "5                                       "
                  "                                        "
                  "~                                       "
                  "~                                       "
                  "-- INSERT --                            ");
    
    }
    
    shell->WriteChildInput("\x1b");
    testSleep( 1s );
    shell->WriteChildInput(":q!");
    testSleep( 1s );
}

@end
