// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Config/Config.h>
#include <Config/ObjCBridge.h>

namespace nc {

// this implementation currently works only in one direction:
// config -> ObjectiveC property
// need to make it work bothways and move it to Config.mm after some using
class ConfigBinder
{
public:
    ConfigBinder(nc::config::Config &_config, const char *_config_path, id _object, NSString *_object_key)
        : m_Config(_config), m_ConfigPath(_config_path),
          m_Token(_config.Observe(_config_path, [this] { ConfigChanged(); })), m_Object(_object),
          m_ObjectKey(_object_key)
    {
        ConfigChanged();
    }

private:
    void ConfigChanged()
    {
        auto bridge = [[NCConfigObjCBridge alloc] initWithConfig:m_Config];
        if( id v = [bridge valueForKeyPath:[NSString stringWithUTF8String:m_ConfigPath]] )
            [m_Object setValue:v forKey:m_ObjectKey];
    }

    nc::config::Config &m_Config;
    const char *m_ConfigPath;
    nc::config::Token m_Token;

    __weak id m_Object;
    NSString *m_ObjectKey;
};

} // namespace nc
