// Copyright (C) 2013-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CLI.h"
#include <Habanero/SysLocale.h>

extern "C" int NSApplicationMain(int argc, const char *argv[]);

int main(int argc, char *argv[])
{
    nc::bootstrap::ProcessCLIUsage(argc, argv);
    nc::base::SetSystemLocaleAsCLocale();
    return NSApplicationMain(argc, const_cast<const char **>(argv));
}
