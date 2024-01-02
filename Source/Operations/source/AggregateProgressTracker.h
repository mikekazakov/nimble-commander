// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Pool.h"

namespace nc::ops {

class AggregateProgressTracker : public std::enable_shared_from_this<AggregateProgressTracker>
{
public:
    AggregateProgressTracker();
    ~AggregateProgressTracker();
    void AddPool( Pool &_pool );
    void SetProgressCallback( std::function<void(double _progress)> _callback );

    static constexpr auto InvalidProgess = -1.;
private:
    AggregateProgressTracker(const AggregateProgressTracker&) = delete;
    void operator=(const AggregateProgressTracker&) = delete;
    void PoolsChanged();
    bool ArePoolsEmpty() const;
    std::tuple<int, double> OperationsAmountAndProgress() const;
    void Update();
    void Purge();
    void Signal( double _progress );
    std::atomic_bool m_IsTracking;
    std::atomic_bool m_IsUpdateScheduled;
    mutable std::mutex m_Lock;
    std::vector<std::weak_ptr<Pool>> m_Pools;
    std::function<void(double _progress)> m_Callback;
};

}
