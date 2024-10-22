// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AggregateProgressTracker.h"
#include "Statistics.h"
#include <Base/dispatch_cpp.h>
#include <algorithm>
#include <iostream>
#include <ranges>

namespace nc::ops {

using namespace std::literals;

static const auto g_UpdateDelay = 100ms;

AggregateProgressTracker::AggregateProgressTracker() : m_IsTracking{false}, m_IsUpdateScheduled{false}
{
    SetProgressCallback([](double _progress) { std::cout << _progress << '\n'; });
}

AggregateProgressTracker::~AggregateProgressTracker() = default;

void AggregateProgressTracker::AddPool(Pool &_pool)
{
    Purge();

    const auto p = _pool.shared_from_this();

    const auto lock = std::lock_guard{m_Lock};

    if( std::ranges::any_of(m_Pools, [=](const auto &_i) { return _i.lock() == p; }) )
        return;
    m_Pools.emplace_back(p);

    const auto weak_this = std::weak_ptr<AggregateProgressTracker>(shared_from_this());
    _pool.ObserveUnticketed(Pool::NotifyAboutChange, [weak_this] {
        if( auto me = weak_this.lock() )
            me->PoolsChanged();
    });
}

void AggregateProgressTracker::PoolsChanged()
{
    const auto should_track = !ArePoolsEmpty();
    if( should_track == m_IsTracking )
        return;

    if( should_track ) {
        m_IsTracking = true;
        if( !m_IsUpdateScheduled ) {
            m_IsUpdateScheduled = true;
            const auto weak_this = std::weak_ptr<AggregateProgressTracker>(shared_from_this());
            dispatch_to_main_queue_after(g_UpdateDelay, [weak_this] {
                if( auto me = weak_this.lock() )
                    me->Update();
            });
        }
    }
    else {
        m_IsTracking = false;
        const auto weak_this = std::weak_ptr<AggregateProgressTracker>(shared_from_this());
        dispatch_to_main_queue([weak_this] {
            if( auto me = weak_this.lock() )
                me->Signal(InvalidProgess);
        });
    }
}

bool AggregateProgressTracker::ArePoolsEmpty() const
{
    const auto lock = std::lock_guard{m_Lock};
    return std::ranges::all_of(m_Pools, [](auto &wp) {
        const auto p = wp.lock();
        return p ? p->Empty() : true;
    });
}

std::tuple<int, double> AggregateProgressTracker::OperationsAmountAndProgress() const
{
    int amount = 0;
    double progress = 0.;
    {
        const auto lock = std::lock_guard{m_Lock};
        for( const auto &wp : m_Pools )
            if( const auto p = wp.lock() )
                if( !p->Empty() )
                    for( const auto &op : p->RunningOperations() ) {
                        const auto &stat = op->Statistics();
                        progress += stat.DoneFraction(stat.PreferredSource());
                        ++amount;
                    }
    }
    if( amount )
        progress /= amount;

    return std::make_tuple(amount, progress);
}

void AggregateProgressTracker::Update()
{
    const auto [amount, progress] = OperationsAmountAndProgress();
    m_IsTracking = amount != 0;
    Signal(amount ? progress : InvalidProgess);

    if( m_IsTracking ) {
        const auto weak_this = std::weak_ptr<AggregateProgressTracker>(shared_from_this());
        dispatch_to_main_queue_after(g_UpdateDelay, [weak_this] {
            if( auto me = weak_this.lock() )
                me->Update();
        });
    }
    else {
        m_IsUpdateScheduled = false;
    }
}

void AggregateProgressTracker::Signal(double _progress)
{
    dispatch_assert_main_queue();
    if( m_Callback )
        m_Callback(_progress);
}

void AggregateProgressTracker::SetProgressCallback(std::function<void(double _progress)> _callback)
{
    dispatch_assert_main_queue();
    m_Callback = std::move(_callback);
}

void AggregateProgressTracker::Purge()
{
    const auto lock = std::lock_guard{m_Lock};
    std::erase_if(m_Pools, [](auto &v) { return v.expired(); });
}

} // namespace nc::ops
