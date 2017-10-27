// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Pool.h"

namespace nc::ops {

class AggregateProgressTracker : public enable_shared_from_this<AggregateProgressTracker>
{
public:
    AggregateProgressTracker();
    ~AggregateProgressTracker();
    void AddPool( Pool &_pool );
    void SetProgressCallback( function<void(double _progress)> _callback );

    static constexpr auto InvalidProgess = -1.;
private:
    AggregateProgressTracker(const AggregateProgressTracker&) = delete;
    void operator=(const AggregateProgressTracker&) = delete;
    void PoolsChanged();
    bool ArePoolsEmpty() const;
    tuple<int, double> OperationsAmountAndProgress() const;
    void Update();
    void Purge();
    void Signal( double _progress );
    atomic_bool m_IsTracking;
    atomic_bool m_IsUpdateScheduled;
    mutable mutex m_Lock;
    vector<weak_ptr<Pool>> m_Pools;
    function<void(double _progress)> m_Callback;
};

}
