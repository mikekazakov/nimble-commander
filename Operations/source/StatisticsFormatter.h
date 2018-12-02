// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Foundation/Foundation.h>

namespace nc::ops {
class Statistics;

class StatisticsFormatter
{
public:
    StatisticsFormatter(const Statistics&_stats) noexcept;

    NSString *ProgressCaption() const;

private:
    NSString *WithItems() const;
    NSString *WithBytes() const;
    const Statistics& m_Stats;
};


}
