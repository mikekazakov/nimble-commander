// Copyright (C) 2017-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>

namespace nc::term {

// NB! Persistence-bound
enum class CursorMode : int8_t {
    BlinkingBlock = 0,
    BlinkingUnderline = 1,
    BlinkingBar = 2,
    SteadyBlock = 3,
    SteadyUnderline = 4,
    SteadyBar = 5
};

constexpr inline bool IsSteady(CursorMode _mode) noexcept
{
    return _mode == CursorMode::SteadyBar || _mode == CursorMode::SteadyBlock || _mode == CursorMode::SteadyUnderline;
}

using TermViewCursor = CursorMode;

} // namespace nc::term
