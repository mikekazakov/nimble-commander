// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <optional>
#include <string>

namespace nc::bootstrap {

bool AskUserToResetDefaults();
bool AskToExitWithRunningOperations();
void WarnAboutFailingToAccessPrivilegedHelper();

} // namespace nc::bootstrap
