// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <vector>
#include <string>
#include "Style.h"

namespace nc::viewer::hl {

struct LexerSettings {
    struct Property {
        std::string key;
        std::string value;
    };

    std::string name;
    std::vector<Property> properties;
    std::vector<std::string> wordlists;
    StyleMapper mapping;
};

} // namespace nc::viewer::hl
