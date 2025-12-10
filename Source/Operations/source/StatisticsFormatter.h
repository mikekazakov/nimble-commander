// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Foundation/Foundation.h>
#include <chrono>

namespace nc::ops {
class Statistics;

class StatisticsFormatter
{
public:
    StatisticsFormatter(const Statistics &_stats) noexcept;

    NSString *ProgressCaption() const;

private:
    static NSString *FormatETAString(std::chrono::nanoseconds _eta);

    NSString *WithItems() const;
    NSString *WithBytes() const;
    const Statistics &m_Stats;
};

} // namespace nc::ops
