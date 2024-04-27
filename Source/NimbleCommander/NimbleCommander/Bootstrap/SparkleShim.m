// Copyright (C) 2020-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "SparkleShim.h"
#include <Sparkle/Sparkle.h>

SPUStandardUpdaterController *NCBootstrapSharedSUUpdaterInstance(void)
{
#ifdef __NC_VERSION_NONMAS__
    static SPUStandardUpdaterController *ctrl = nil;
    if( !ctrl )
        ctrl = [[SPUStandardUpdaterController alloc] initWithUpdaterDelegate:nil userDriverDelegate:nil];
    return ctrl;
#else
    return nil;
#endif
}

SEL NCBootstrapSUUpdaterAction(void)
{
    return @selector(checkForUpdates:);
}
