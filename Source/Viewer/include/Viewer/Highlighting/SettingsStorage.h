// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <string_view>
#include <memory>

namespace nc::viewer::hl {

class SettingsStorage
{
public:
    virtual ~SettingsStorage() = default;
    
    virtual std::shared_ptr<const std::string> Settings(std::string_view _file_extension) = 0;
};

class DummySettingsStorage : public SettingsStorage
{
public:
    std::shared_ptr<const std::string> Settings(std::string_view _file_extension) override;
};

}
