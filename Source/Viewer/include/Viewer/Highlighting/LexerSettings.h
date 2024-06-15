// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Style.h"
#include <vector>
#include <string>
#include <string_view>
#include <expected>
#include <compare>

namespace nc::viewer::hl {

struct LexerSettings {
    struct Property {
        std::string key;
        std::string value;
        auto operator<=>(const Property &) const noexcept = default;
    };

    std::string name;
    std::vector<Property> properties;
    std::vector<std::string> wordlists;
    StyleMapper mapping;
};

std::expected<LexerSettings, std::string> ParseLexerSettings(std::string_view _json) noexcept;

} // namespace nc::viewer::hl
