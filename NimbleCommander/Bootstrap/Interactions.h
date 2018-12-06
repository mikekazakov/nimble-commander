// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::bootstrap {

std::optional<string> AskUserForLicenseFile();
bool AskUserToResetDefaults();
bool AskUserToProvideUsageStatistics();
bool AskToExitWithRunningOperations();
void ThankUserForBuyingALicense();
void WarnAboutFailingToAccessPriviledgedHelper();
    
}
