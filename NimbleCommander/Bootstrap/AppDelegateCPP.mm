// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AppDelegateCPP.h"
#include <Utility/PathManip.h>
#include <Utility/StringExtras.h>
#include "../../3rd_Party/NSFileManagerDirectoryLocations/NSFileManager+DirectoryLocations.h"
#include "AppDelegate.h"

namespace nc {

const std::string &AppDelegate::ConfigDirectory()
{
    return NCAppDelegate.me.configDirectory;
}

const std::string &AppDelegate::StateDirectory()
{
    return NCAppDelegate.me.stateDirectory;
}

const std::string &AppDelegate::SupportDirectory()
{
    if( NCAppDelegate.me )
        return NCAppDelegate.me.supportDirectory;
    
    static std::string support_dir = []{
        auto path = NSFileManager.defaultManager.applicationSupportDirectory;
        return EnsureTrailingSlash( path.fileSystemRepresentationSafe );
    }();
    return support_dir;
}

const std::shared_ptr<NetworkConnectionsManager> &AppDelegate::NetworkConnectionsManager()
{
    return NCAppDelegate.me.networkConnectionsManager;
}

}
