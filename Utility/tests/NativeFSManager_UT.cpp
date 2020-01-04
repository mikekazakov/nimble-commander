// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NativeFSManager.h>
#include <Habanero/algo.h>
#include "UnitTests_main.h"

using nc::utility::NativeFSManager;
using nc::utility::NativeFileSystemInfo;
#define PREFIX "nc::utility::NativeFSManager "

TEST_CASE(PREFIX"Fast lookup considers firmlinks")
{
    auto &fsm = NativeFSManager::Instance();
    
    auto root_volume = fsm.VolumeFromPathFast("/");
    REQUIRE( root_volume != nullptr );
    CHECK( root_volume->mounted_at_path == "/" ); 

    auto applications_volume = fsm.VolumeFromPathFast("/Applications/");
    REQUIRE( applications_volume != nullptr );
    CHECK( applications_volume != root_volume ); 
}

TEST_CASE(PREFIX"VolumeFromFD")
{
    const auto p1 = "/bin";
    const auto p2 = "/Users";

    const int fd1 = open(p1, O_RDONLY);
    REQUIRE( fd1 >= 0 );
    auto close_fd1 = at_scope_end([=]{ close(fd1); });

    const int fd2 = open(p2, O_RDONLY);
    REQUIRE( fd2 >= 0 );
    auto close_fd2 = at_scope_end([=]{ close(fd2); });

    auto &fsm = NativeFSManager::Instance();
    const auto info1 = fsm.VolumeFromFD(fd1);
    REQUIRE( info1 != nullptr );
    CHECK( info1->mounted_at_path == "/" );
    
    const auto info2 = fsm.VolumeFromFD(fd2);
    REQUIRE( info2 != nullptr );
    CHECK( info2->mounted_at_path == "/System/Volumes/Data" ); // this can be flaky (?)
    
    const auto info1_p = fsm.VolumeFromPath(p1);
    CHECK( info1_p == info1 );
    
    const auto info2_p = fsm.VolumeFromPath(p2);
    CHECK( info2_p == info2 );
}
