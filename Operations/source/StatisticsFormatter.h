#pragma once

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
