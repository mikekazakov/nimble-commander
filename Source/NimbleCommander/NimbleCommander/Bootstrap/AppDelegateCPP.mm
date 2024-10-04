// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AppDelegateCPP.h"
#include <Utility/PathManip.h>
#include <Utility/StringExtras.h>
#include "AppDelegate.h"
#include <fmt/format.h>

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
    [[clang::no_destroy]] static const std::filesystem::path support_dir = [] {
        // Build the path to the support directory
        NSString *const executableName = [NSBundle.mainBundle.infoDictionary objectForKey:@"CFBundleExecutable"];
        NSArray *const paths =
            NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, true);
        if( paths.count == 0 ) {
            fmt::println(stderr, "Unable to locate the Application Support directory");
            exit(-1);
        }
        NSString *const ns_path = [paths objectAtIndex:0];
        const std::filesystem::path path = std::filesystem::path(ns_path.fileSystemRepresentation) /
                                           std::filesystem::path(executableName.fileSystemRepresentation);

        // Create it if it's not there
        std::filesystem::create_directories(path);

        return EnsureTrailingSlash(path);
    }();
    return support_dir;
}

const std::shared_ptr<nc::panel::NetworkConnectionsManager> &AppDelegate::NetworkConnectionsManager()
{
    return NCAppDelegate.me.networkConnectionsManager;
}

} // namespace nc
