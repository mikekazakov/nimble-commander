// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/Tags.h>
#include <vector>
#include <span>
#include <mutex>
#include <string_view>

namespace nc::config {
class Config;
}

namespace nc::panel {

class TagsStorage
{
public:
    TagsStorage(config::Config &_persistant_storage, std::string_view _path);

    bool Initialized() const noexcept;
    std::vector<utility::Tags::Tag> Get() const;
    void Set(std::span<const utility::Tags::Tag> _tags);

private:
    bool Load();
    void Store();

    mutable std::mutex m_Mut;
    std::vector<utility::Tags::Tag> m_Tags;
    config::Config &m_Storage;
    const std::string m_PathV1;
    bool m_Initialized = false;
};

} // namespace nc::panel
