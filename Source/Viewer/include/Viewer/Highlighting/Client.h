// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "Style.h"
#include <string_view>
#include <expected>
#include <functional>
#include <dispatch/dispatch.h>

namespace nc::viewer::hl {

class Client
{
public:
    // Synchronously highlights the specified text given the specified settings.
    // Returns either styles for the text or an error message.
    static std::expected<std::vector<Style>, std::string> Highlight(std::string_view _text, std::string_view _settings);

    // Asynchronously highlights the specified text given the specified settings.
    // The callback will be executed once the request is fulfilled, providing either styles for the text or an error
    // message. A queue for the callback can be optionally provided, by default the main queue will be used.
    static void HighlightAsync(std::string_view _text,
                               std::string_view _settings,
                               std::function<void(std::expected<std::vector<Style>, std::string>)> _done,
                               dispatch_queue_t _queue = nullptr);
};

} // namespace nc::viewer::hl
