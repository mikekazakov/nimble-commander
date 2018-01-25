// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/PathManip.h>
#include "../../3rd_Party/NSFileManagerDirectoryLocations/NSFileManager+DirectoryLocations.h"
#include "AppDelegate.h"
#include "AppDelegateCPP.h"

namespace nc {

const string &AppDelegate::ConfigDirectory()
{
    return NCAppDelegate.me.configDirectory;
}

const string &AppDelegate::StateDirectory()
{
    return NCAppDelegate.me.stateDirectory;
}

const string &AppDelegate::SupportDirectory()
{
    if( NCAppDelegate.me )
        return NCAppDelegate.me.supportDirectory;
    
    static string support_dir = []{
        auto path = NSFileManager.defaultManager.applicationSupportDirectory;
        return EnsureTrailingSlash( path.fileSystemRepresentationSafe );
    }();
    return support_dir;
}

const shared_ptr<NetworkConnectionsManager> &AppDelegate::NetworkConnectionsManager()
{
    return NCAppDelegate.me.networkConnectionsManager;
}

}
