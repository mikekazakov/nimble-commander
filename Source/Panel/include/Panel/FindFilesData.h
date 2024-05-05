// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Config/Config.h>
#include <string>
#include <string_view>
#include <span>
#include <vector>

namespace nc::panel {

struct FindFilesMask {
    enum Type {
        Classic = 0,
        RegEx = 1
    };
    std::string string;
    Type type = Classic;
    friend bool operator==(const FindFilesMask &lhs, const FindFilesMask &rhs) noexcept;
    friend bool operator!=(const FindFilesMask &lhs, const FindFilesMask &rhs) noexcept;
};

std::vector<FindFilesMask> LoadFindFilesMasks(const nc::config::Config &_source, std::string_view _path);
void StoreFindFilesMasks(nc::config::Config &_dest, std::string_view _path, std::span<const FindFilesMask> _masks);

} // namespace nc::panel
