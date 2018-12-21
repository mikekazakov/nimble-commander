// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MASAppInstalledChecker.h"
#include <unistd.h>

using namespace std::literals;

MASAppInstalledChecker::MASAppInstalledChecker()
{
}

MASAppInstalledChecker &MASAppInstalledChecker::Instance()
{
    static auto inst = std::make_unique<MASAppInstalledChecker>();
    return *inst;
}

bool MASAppInstalledChecker::Has(const std::string &_app_name, const std::string &_app_id)
{
    // almost dummy now, as intended. will bother with whole validation process later.
    // for real implementation: https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateLocally.html#//apple_ref/doc/uid/TP40010573-CH1-SW16
    
    std::string path = "/Applications/"s + _app_name + "/Contents/_MASReceipt/receipt";
    return access(path.c_str(), R_OK) == 0;
}
