#pragma once

class GenericConfig;

namespace nc::bootstrap {

class ConfigWiring
{
public:
    ConfigWiring(GenericConfig &_config);
    void Wire();

private:
    void SetupOperationsPool();
    void SetupNotification();
    
    GenericConfig &m_Config;    
};


}
