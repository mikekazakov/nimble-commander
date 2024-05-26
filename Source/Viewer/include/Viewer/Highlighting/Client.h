// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "Style.h"
#include <string_view>

namespace nc::viewer::hl {

class Client
{
public:
    std::vector<Style> Highlight(std::string_view _text, std::string_view _settings);
    // TODO: Async API, Sync+Timeout API
};

} // namespace nc::viewer::hl
