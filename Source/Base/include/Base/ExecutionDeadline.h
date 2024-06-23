// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <chrono>

namespace nc::base {

class ExecutionDeadline
{
public:
    ExecutionDeadline(std::chrono::seconds _execution_limit);
    ~ExecutionDeadline() = default;
};

} // namespace nc::base
