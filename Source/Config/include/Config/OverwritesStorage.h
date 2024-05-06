// Copyright (C) 2018-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <optional>
#include <functional>

namespace nc::config {

class OverwritesStorage
{
public:
    virtual ~OverwritesStorage() = default;

    virtual std::optional<std::string> Read() const = 0;

    virtual void Write(std::string_view _overwrites_json) = 0;

    virtual void SetExternalChangeCallback(std::function<void()> _callback) = 0;
};

} // namespace nc::config
