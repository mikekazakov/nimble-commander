#pragma once

namespace nc::ops {
class Statistics;

class StatisticsFormatter
{
public:
    StatisticsFormatter(const Statistics&_stats) noexcept;

    NSString *ProgressCaption() const;

private:
    const Statistics& m_Stats;
};


}
