#pragma once

#include "OverwritesStorage.h"
#include <string_view>

namespace nc::config {
    
class FileOverwritesStorage : public OverwritesStorage
{
public:
    FileOverwritesStorage(std::string_view _file_path);

    std::optional<std::string> Read() const override;
    void Write(std::string_view _overwrites_json) override;
    void SetExternalChangeCallback( std::function<void()> _callback ) override;

private:
    std::string m_Path;    
};

}
