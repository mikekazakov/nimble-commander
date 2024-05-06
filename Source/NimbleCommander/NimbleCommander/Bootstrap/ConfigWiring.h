// Copyright (C) 2017-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Config/Config.h>

namespace nc::ops {
class PoolEnqueueFilter;
}

namespace nc::bootstrap {

class ConfigWiring
{
public:
    ConfigWiring(config::Config &_config, ops::PoolEnqueueFilter &_pool_filter);
    void Wire();

private:
    void SetupOperationsPool();
    void SetupOperationsPoolEnqueFilter();
    void SetupNotification();

    config::Config &m_Config;
    ops::PoolEnqueueFilter &m_PoolFilter;
};

} // namespace nc::bootstrap
