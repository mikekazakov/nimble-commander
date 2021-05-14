// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Usage.h"
#include <vector>
#include <string_view>
#include <iostream>
#include <cstdlib>

namespace nc::bootstrap {

static const auto g_Message =
"Command-line options:\n"
"-NCLogLevel <level>   Sets a logging level for all subsystems.\n"
"                      Valid values are: off, trace, debug, info, warn, err, critical.\n";

void ProcessCLIUsage(int argc, char *argv[])
{
    std::vector<std::string_view> args(argv, argv + argc);
    for( auto arg : args ) {
        if( arg == "--help" ) {
            std::cout << g_Message << std::flush;
            std::exit(0);
        }
    }
}

} // namespace nc::bootstrap
