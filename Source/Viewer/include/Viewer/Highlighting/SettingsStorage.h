// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <string_view>
#include <memory>
#include <optional>

namespace nc::viewer::hl {

class SettingsStorage
{
public:
    virtual ~SettingsStorage() = default;

    // Returns a name of a predicted language for the given filename.
    virtual std::optional<std::string> Language(std::string_view _filename) = 0;

    // Returns the syntax settings of the given language name or nullptr if no such language is defined
    virtual std::shared_ptr<const std::string> Settings(std::string_view _lang) = 0;
};

class DummySettingsStorage : public SettingsStorage
{
public:
    std::optional<std::string> Language(std::string_view _filename) override;

    std::shared_ptr<const std::string> Settings(std::string_view _lang) override;
};

} // namespace nc::viewer::hl
