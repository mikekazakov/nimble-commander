// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ConfigWiring.h"
#include <Operations/Pool.h>
#include <Operations/PoolEnqueueFilter.h>
#include <NimbleCommander/Core/UserNotificationsCenter.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <boost/algorithm/string.hpp>

namespace nc::bootstrap {

ConfigWiring::ConfigWiring(config::Config &_config, ops::PoolEnqueueFilter &_pool_filter)
    : m_Config(_config), m_PoolFilter(_pool_filter)
{
}

void ConfigWiring::Wire()
{
    SetupOperationsPool();
    SetupOperationsPoolEnqueFilter();
    SetupNotification();
}

void ConfigWiring::SetupOperationsPool()
{
    constexpr auto path = "filePanel.operations.concurrencyPerWindow";
    const auto config = &m_Config;
    auto update = [config] {
        const auto new_limit = config->GetInt(path);
        dispatch_to_main_queue([new_limit] {
            for( auto wnd : NCAppDelegate.me.mainWindowControllers )
                wnd.operationsPool.SetConcurrency(new_limit);
        });
    };
    update();
    m_Config.ObserveForever(path, update);
}

void ConfigWiring::SetupOperationsPoolEnqueFilter()
{
    constexpr auto path = "filePanel.operations.concurrencyPerWindowDoesntApplyTo";
    auto update = [this] {
        const auto new_list = m_Config.GetString(path);
        std::vector<std::string> entries;
        boost::split(
            entries, new_list, [](char _c) { return _c == ','; }, boost::token_compress_on);
        for( auto &entry : entries )
            boost::trim(entry);
        m_PoolFilter.Reset();
        for( auto &entry : entries )
            m_PoolFilter.Set(entry, false);
    };
    update();
    m_Config.ObserveForever(path, update);
}

void ConfigWiring::SetupNotification()
{
    constexpr auto path_show_active = "general.notifications.showWhenActive";
    constexpr auto path_min_op_time = "general.notifications.minElapsedOperationTime";
    using unc = core::UserNotificationsCenter;
    const auto config = &m_Config;

    const auto update_show_active = [config] {
        unc::Instance().SetShowWhenActive(config->GetBool(path_show_active));
    };
    update_show_active();
    m_Config.ObserveForever(path_show_active, update_show_active);

    const auto update_min_op_time = [config] {
        const auto min_time = std::chrono::seconds{config->GetInt(path_min_op_time)};
        unc::Instance().SetMinElapsedOperationTime(min_time);
    };
    update_min_op_time();
    m_Config.ObserveForever(path_min_op_time, update_min_op_time);
}

} // namespace nc::bootstrap
