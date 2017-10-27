// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "StatisticsFormatter.h"
#include <Utility/ByteCountFormatter.h>
#include "Statistics.h"
#include "Internal.h"

namespace nc::ops {

static NSString *FormatETAString( nanoseconds _eta );
  
StatisticsFormatter::StatisticsFormatter(const Statistics&_stats) noexcept:
    m_Stats(_stats)
{
}

NSString *StatisticsFormatter::ProgressCaption() const
{
    if( m_Stats.PreferredSource() == Statistics::SourceType::Bytes )
        return WithBytes();
    else
        return WithItems();
}

NSString *StatisticsFormatter::WithItems() const
{
    const auto volume_total = m_Stats.VolumeTotal(Statistics::SourceType::Items);
    const auto volume_total_str = [NSString stringWithFormat:@"%llu", volume_total];
    
    const auto volume_processed = m_Stats.VolumeProcessed(Statistics::SourceType::Items);
    const auto volume_processed_str = [NSString stringWithFormat:@"%llu", volume_processed];

    if( m_Stats.IsPaused() ) {
        auto fmt = NSLocalizedString(@"%@ of %@ - Paused", "");
        return [NSString localizedStringWithFormat:fmt,
                volume_processed_str,
                volume_total_str];
    }
    else {
        const auto eta = m_Stats.ETA(Statistics::SourceType::Items);
        const auto eta_str = eta ? FormatETAString(*eta) : nil;
        if( eta_str ) {
            auto fmt = NSLocalizedString(@"%@ of %@, %@", "");
            return [NSString localizedStringWithFormat:fmt,
                    volume_processed_str,
                    volume_total_str,
                    eta_str];
        }
        else {
            auto fmt = NSLocalizedString(@"%@ of %@", "");
            return [NSString localizedStringWithFormat:fmt,
                    volume_processed_str,
                    volume_total_str];
        }
    }
}
  
NSString *StatisticsFormatter::WithBytes() const
{
    auto &fmt = ByteCountFormatter::Instance();
    const auto fmt_type = ByteCountFormatter::Adaptive8;

    const auto volume_total = m_Stats.VolumeTotal(Statistics::SourceType::Bytes);
    const auto volume_total_str = fmt.ToNSString(volume_total, fmt_type);
    
    const auto volume_processed = m_Stats.VolumeProcessed(Statistics::SourceType::Bytes);
    const auto volume_processed_str = fmt.ToNSString(volume_processed, fmt_type);

    if( m_Stats.IsPaused() ) {
        auto fmt = NSLocalizedString(@"%@ of %@ - Paused", "");
        return [NSString localizedStringWithFormat:fmt,
                volume_processed_str,
                volume_total_str];
    }
    else {
        const auto speed = m_Stats.SpeedPerSecondDirect(Statistics::SourceType::Bytes);
        if( speed != 0 ) {
            const auto speed_str = fmt.ToNSString(speed, fmt_type);
            const auto eta = m_Stats.ETA(Statistics::SourceType::Bytes);
            const auto eta_str = eta ? FormatETAString(*eta) : nil;
            if( eta_str ) {
                auto fmt = NSLocalizedString(@"%@ of %@ - %@/s, %@", "");
                return [NSString localizedStringWithFormat:fmt,
                        volume_processed_str,
                        volume_total_str,
                        speed_str,
                        eta_str];
            }
            else {
                auto fmt = NSLocalizedString(@"%@ of %@ - %@/s", "");
                return [NSString localizedStringWithFormat:fmt,
                        volume_processed_str,
                        volume_total_str,
                        speed_str];
            }
        }
        else {
            auto fmt = NSLocalizedString(@"%@ of %@", "");
            return [NSString localizedStringWithFormat:fmt,
                    volume_processed_str,
                    volume_total_str];
        }
    }
}

static NSString *FormatETAString( nanoseconds _eta )
{
    static const auto fmt = []{
        NSDateComponentsFormatter *fmt = [[NSDateComponentsFormatter alloc] init];
        fmt.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
        fmt.includesApproximationPhrase = false;
        fmt.includesTimeRemainingPhrase = false;
        fmt.allowedUnits = NSCalendarUnitMinute | NSCalendarUnitSecond;
        return fmt;
    }();
 
    const auto time_interval = double(_eta.count()) / 1000000000.;
    return [fmt stringFromTimeInterval:time_interval];
}

}
