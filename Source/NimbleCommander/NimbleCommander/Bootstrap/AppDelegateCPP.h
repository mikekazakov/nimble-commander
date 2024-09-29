// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <filesystem>
#include <memory>

namespace nc::panel {
class NetworkConnectionsManager;
}

namespace nc {

class AppDelegate
{
public:
    static const std::filesystem::path &ConfigDirectory();
    static const std::filesystem::path &StateDirectory();
    static const std::filesystem::path &SupportDirectory();
    static const std::shared_ptr<panel::NetworkConnectionsManager> &NetworkConnectionsManager();
};

} // namespace nc
