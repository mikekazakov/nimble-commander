// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PFMoveToApplicationsShim.h"

#ifdef __NC_VERSION_TRIAL__
#include <LetsMove/PFMoveApplication.h>
#endif

namespace nc::bootstrap {

void PFMoveToApplicationsFolderIfNecessary()
{
#ifdef __NC_VERSION_TRIAL__
    ::PFMoveToApplicationsFolderIfNecessary();
#endif
}

} // namespace nc::bootstrap
