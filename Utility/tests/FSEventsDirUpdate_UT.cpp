// Copyright (C) 2019-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FSEventsDirUpdate.h"
#include "UnitTests_main.h"
#include <CoreFoundation/CoreFoundation.h>
#include <fcntl.h>

using nc::utility::FSEventsDirUpdate; 

#define PREFIX "nc::utility::FSEventsDirUpdate "

static void touch(const std::string &_path);
static void run_event_loop();

TEST_CASE(PREFIX"Returns zero on invalid paths")
{
    auto &inst = FSEventsDirUpdate::Instance(); 
    CHECK( inst.AddWatchPath("/asdasd/asdasdsa", []{}) == 0 );
}

TEST_CASE(PREFIX"Registers event listeners")
{
    TempTestDir tmp_dir;
    auto &inst = FSEventsDirUpdate::Instance();
    int call_count[3] = {0, 0, 0}; 
    
    const auto ticket0 = inst.AddWatchPath(tmp_dir.directory.c_str(),
                                           [&]{ ++call_count[0]; });

    touch( tmp_dir.directory + "something.txt" );    
    run_event_loop();    
    CHECK( call_count[0] == 1 );

    const auto ticket1 = inst.AddWatchPath(tmp_dir.directory.c_str(),
                                           [&]{ ++call_count[1]; });

    touch( tmp_dir.directory + "something else.txt" );
    run_event_loop();
    CHECK( call_count[0] == 2 );
    CHECK( call_count[1] == 1 );

    const auto ticket2 = inst.AddWatchPath(tmp_dir.directory.c_str(),
                                           [&]{ ++call_count[2]; });

    touch( tmp_dir.directory + "another something else.txt" );
    run_event_loop();
    CHECK( call_count[0] == 3 );
    CHECK( call_count[1] == 2 );
    CHECK( call_count[2] == 1 );
    
    inst.RemoveWatchPathWithTicket(ticket0);
    inst.RemoveWatchPathWithTicket(ticket1);
    inst.RemoveWatchPathWithTicket(ticket2);
}

TEST_CASE(PREFIX"Removes event listeners")
{
    TempTestDir tmp_dir;
    auto &inst = FSEventsDirUpdate::Instance();
    int call_count[3] = {0, 0, 0}; 
    
    const auto ticket0 = inst.AddWatchPath(tmp_dir.directory.c_str(),
                                           [&]{ ++call_count[0]; });
    
    touch( tmp_dir.directory + "something.txt" );    
    run_event_loop();    
    CHECK( call_count[0] == 1 );
    
    inst.RemoveWatchPathWithTicket(ticket0);    
    const auto ticket1 = inst.AddWatchPath(tmp_dir.directory.c_str(),
                                           [&]{ ++call_count[1]; });
    
    touch( tmp_dir.directory + "something else.txt" );
    run_event_loop();
    CHECK( call_count[0] == 1 );
    CHECK( call_count[1] == 1 );
    
    const auto ticket2 = inst.AddWatchPath(tmp_dir.directory.c_str(),
                                           [&]{ ++call_count[2]; });
    
    touch( tmp_dir.directory + "another something else.txt" );
    run_event_loop();
    CHECK( call_count[0] == 1 );
    CHECK( call_count[1] == 2 );
    CHECK( call_count[2] == 1 );
        
    inst.RemoveWatchPathWithTicket(ticket1);
    inst.RemoveWatchPathWithTicket(ticket2);
}

static void touch(const std::string &_path)
{
    close( open(_path.c_str(), O_CREAT|O_RDWR, S_IRWXU) );
}

static void run_event_loop()
{
    const auto time = 0.05; // 50ms just because I feel adventurous about debugging flaky tests...
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, time, false);
}
