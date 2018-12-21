// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>

class MASAppInstalledChecker
{
public:
    MASAppInstalledChecker();
    static MASAppInstalledChecker &Instance();
    
    /**
     * checks if specified is downloaded and has a valid receipt.
     * _app_name - name like "Files Pro.app"
     * _app_id - id like "info.filesmanager.Files-Pro"
     *
     */
    bool Has(const std::string &_app_name,
             const std::string &_app_id);
    
private:
    MASAppInstalledChecker(const MASAppInstalledChecker&) = delete;
    void operator=(const MASAppInstalledChecker&) = delete;
};
