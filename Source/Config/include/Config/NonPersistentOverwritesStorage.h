// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "OverwritesStorage.h"
#include <string_view>

namespace nc::config {
    
class NonPersistentOverwritesStorage : public OverwritesStorage
{
public:
    NonPersistentOverwritesStorage(std::string_view _initial_value);
    ~NonPersistentOverwritesStorage();

    void ExternalWrite( const std::string &_new_value );
    
    std::optional<std::string> Read() const override;
    void Write(std::string_view _overwrites_json) override;
    void SetExternalChangeCallback( std::function<void()> ) override;
    
private:
    std::string m_Data;
    std::function<void()> m_Callback;
};
    
}

