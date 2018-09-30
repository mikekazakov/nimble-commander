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
    
private:
    std::optional<std::string> Read() const override;
    void Write(const std::string &_overwrites_json) override;
    void SetExternalChangeCallback( std::function<void()> ) override;
    
    std::string m_Data;
    std::function<void()> m_Callback;
};
    
}

