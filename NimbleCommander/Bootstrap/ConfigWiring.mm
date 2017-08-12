#include "ConfigWiring.h"
#include "Config.h"
#include <Operations/Pool.h>

namespace nc::bootstrap {

ConfigWiring::ConfigWiring(GenericConfig &_config):
    m_Config(_config)
{
}

void ConfigWiring::Wire()
{
    SetupPoolConcurrency();
}

void ConfigWiring::SetupPoolConcurrency()
{
    static const auto path = "filePanel.operations.concurrencyPerWindow";
    const auto config = &m_Config;
    auto update = [config]{
        ops::Pool::SetConcurrencyPerPool(config->GetInt(path));
    };
    update();
    m_Config.ObserveUnticketed(path, update);
}

}
