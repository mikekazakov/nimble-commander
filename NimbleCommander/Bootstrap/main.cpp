// Copyright (C) 2013-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Usage.h"

extern "C" int NSApplicationMain(int argc, const char *argv[]);

int main(int argc, char *argv[])
{
    nc::bootstrap::ProcessCLIUsage(argc, argv);
    return NSApplicationMain(argc, const_cast<const char **>(argv));
}
