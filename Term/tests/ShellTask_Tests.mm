// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/CommonPaths.h>
#include <Habanero/dispatch_cpp.h>
#import <XCTest/XCTest.h>
#include "ShellTask.h"
#include "Screen.h"
#include "Parser.h"

using namespace nc::term;
using nc::base::CommonPaths;
using namespace std;
using namespace std::chrono;

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
        const auto dump = screen->Buffer().DumpScreenAsANSI();
        const auto expected_dump = 
        "                                        "
        "~                                       "
        "~                                       "
        "~                                       "
        "~                                       "
        "~                                       "
        "~                                       "
        "~                                       "
        "~                                       "
        "\"vim_test\" [New File]                   "; 
        XCTAssert( dump == expected_dump );
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
