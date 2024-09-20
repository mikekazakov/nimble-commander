// Copyright (C) 2021-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CLI.h"
#include <vector>
#include <string_view>
#include <iostream>
#include <cstdlib>
#include <RoutedIO/RoutedIO.h>

namespace nc::bootstrap {

static const auto g_Message = "Command-line options:                                                          \n"
                              "-NCLogLevel <level>   Sets a logging level for all subsystems.                 \n"
                              "                      Levels are: off, trace, debug, info, warn, err, critical.\n"
                              "                                                                               \n"
                              "Command-line commands:                                                         \n"
                              "--help                          Prints this message.                           \n"
                              "--install-privileged-helper     Installs the Admin Mode helper.                \n"
                              "--uninstall-privileged-helper   Stops and uninstalls the Admin Mode helper.    \n";

void ProcessCLIUsage(int argc, char *argv[])
{
    const std::vector<std::string_view> args(argv, argv + argc);
    for( auto arg : args ) {
        if( arg == "--help" ) {
            std::cout << g_Message << std::flush;
            std::exit(0);
        }
        if( arg == "--install-privileged-helper" ) {
            nc::routedio::RoutedIO::InstallViaRootCLI();
            std::exit(0);
        }
        if( arg == "--uninstall-privileged-helper" ) {
            nc::routedio::RoutedIO::UninstallViaRootCLI();
            std::exit(0);
        }
    }
}

} // namespace nc::bootstrap
