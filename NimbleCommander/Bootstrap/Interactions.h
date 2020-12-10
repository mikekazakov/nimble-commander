// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <optional>
#include <string>

namespace nc::bootstrap {

class ActivationManager;

std::optional<std::string> AskUserForLicenseFile(const ActivationManager &_am);
bool AskUserToResetDefaults();
bool AskUserToProvideUsageStatistics();
bool AskToExitWithRunningOperations();
void ThankUserForBuyingALicense();
void WarnAboutFailingToAccessPriviledgedHelper();
    
}
