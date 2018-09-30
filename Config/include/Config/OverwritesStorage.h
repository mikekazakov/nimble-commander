#pragma once

#include <string>
#include <optional>

namespace nc::config {

class OverwritesStorage
{
public:
    virtual ~OverwritesStorage() = default;
    
    virtual std::optional<std::string> Read() const = 0;
    
    virtual void Write(const std::string &_overwrites_json) = 0;
    
    virtual void SetExternalChangeCallback( std::function<void()> _callback ) = 0;
};

}
