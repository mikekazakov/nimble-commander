// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NativeFSManager.h>
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

