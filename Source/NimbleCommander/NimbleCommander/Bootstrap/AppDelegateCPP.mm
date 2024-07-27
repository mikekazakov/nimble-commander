// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AppDelegateCPP.h"
#include <Utility/PathManip.h>
#include <Utility/StringExtras.h>
#include "../../3rd_Party/NSFileManagerDirectoryLocations/NSFileManager+DirectoryLocations.h"
#include "AppDelegate.h"

namespace nc {

const std::filesystem::path &AppDelegate::ConfigDirectory()
{
    return NCAppDelegate.me.configDirectory;
}

const std::filesystem::path &AppDelegate::StateDirectory()
{
    return NCAppDelegate.me.stateDirectory;
}

const std::filesystem::path &AppDelegate::SupportDirectory()
{
    // this is a duplicate of NCAppDelegate.supportDirectory,
    // but it has to be here to break down an initialization dependency circle
    [[clang::no_destroy]] static const std::filesystem::path support_dir = [] {
        auto path = NSFileManager.defaultManager.applicationSupportDirectory;
        return EnsureTrailingSlash(path.fileSystemRepresentationSafe);
    }();
    return support_dir;
}

const std::shared_ptr<NetworkConnectionsManager> &AppDelegate::NetworkConnectionsManager()
{
    return NCAppDelegate.me.networkConnectionsManager;
}

} // namespace nc
