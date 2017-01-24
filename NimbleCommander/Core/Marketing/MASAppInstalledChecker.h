//
//  MASAppInstalledChecker.h
//  Files
//
//  Created by Michael G. Kazakov on 27/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

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
    bool Has(const string &_app_name,
             const string &_app_id);
    
private:
    MASAppInstalledChecker(const MASAppInstalledChecker&) = delete;
    void operator=(const MASAppInstalledChecker&) = delete;
};
