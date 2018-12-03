// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ConfigWiring.h"
#include <Operations/Pool.h>
#include <NimbleCommander/Core/UserNotificationsCenter.h>

namespace nc::bootstrap {

ConfigWiring::ConfigWiring(config::Config &_config):
    m_Config(_config)
{
}

void ConfigWiring::Wire()
{
    SetupOperationsPool();
    SetupNotification();
}

void ConfigWiring::SetupOperationsPool()
{
    static const auto path = "filePanel.operations.concurrencyPerWindow";
    const auto config = &m_Config;
    auto update = [config]{
        ops::Pool::SetConcurrencyPerPool(config->GetInt(path));
    };
    update();
    m_Config.ObserveForever(path, update);
}

void ConfigWiring::SetupNotification()
{
    static const auto path_show_active = "general.notifications.showWhenActive";
    static const auto path_min_op_time = "general.notifications.minElapsedOperationTime";
    using unc = core::UserNotificationsCenter;
    const auto config = &m_Config;

    const auto update_show_active = [config]{
        unc::Instance().SetShowWhenActive( config->GetBool(path_show_active) );
    };
    update_show_active();
    m_Config.ObserveForever(path_show_active, update_show_active);
    
    const auto update_min_op_time = [config]{
        const auto min_time = std::chrono::seconds{config->GetInt(path_min_op_time)};
        unc::Instance().SetMinElapsedOperationTime(min_time);
    };
    update_min_op_time();
    m_Config.ObserveForever(path_min_op_time, update_min_op_time);
}

}
