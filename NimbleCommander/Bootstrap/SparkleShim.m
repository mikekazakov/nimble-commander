// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.

#include "SparkleShim.h"
#include <Sparkle/Sparkle.h>

SUUpdater *NCBootstrapSharedSUUpdaterInstance()
{
    return [SUUpdater sharedUpdater];
}

SEL NCBootstrapSUUpdaterAction()
{
    return @selector(checkForUpdates:);
}
