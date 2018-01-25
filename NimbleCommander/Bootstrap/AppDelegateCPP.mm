// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/PathManip.h>
#include "../../3rd_Party/NSFileManagerDirectoryLocations/NSFileManager+DirectoryLocations.h"
#include "AppDelegate.h"
#include "AppDelegateCPP.h"

const string &AppDelegateCPP::ConfigDirectory()
{
    return NCAppDelegate.me.configDirectory;
}

const string &AppDelegateCPP::StateDirectory()
{
    return NCAppDelegate.me.stateDirectory;
}

const string &AppDelegateCPP::SupportDirectory()
{
    if( NCAppDelegate.me )
        return NCAppDelegate.me.supportDirectory;
    
    static string support_dir = EnsureTrailingSlash( NSFileManager.defaultManager.applicationSupportDirectory.fileSystemRepresentationSafe );
    return support_dir;
}

const shared_ptr<NetworkConnectionsManager> &AppDelegateCPP::NetworkConnectionsManager()
{
    return NCAppDelegate.me.networkConnectionsManager;
}
