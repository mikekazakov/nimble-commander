// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <memory>

class NetworkConnectionsManager;

namespace nc {

class AppDelegate
{
public:
    static const std::string &ConfigDirectory();
    static const std::string &StateDirectory();
    static const std::string &SupportDirectory();
    static const std::shared_ptr<NetworkConnectionsManager> &NetworkConnectionsManager();
    
};

}
