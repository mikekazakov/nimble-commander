// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Config/Config.h>

namespace nc::bootstrap {

class ConfigWiring
{
public:
    ConfigWiring(config::Config &_config);
    void Wire();

private:
    void SetupOperationsPool();
    void SetupNotification();
    
    config::Config &m_Config;    
};


}
