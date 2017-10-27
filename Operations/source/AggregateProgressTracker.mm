// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AggregateProgressTracker.h"
#include "Statistics.h"

namespace nc::ops {

static const auto g_UpdateDelay = 100ms;

AggregateProgressTracker::AggregateProgressTracker():
    m_IsTracking{false},
    m_IsUpdateScheduled{false}
{
    SetProgressCallback([](double _progress){
        cout << _progress << endl;
    });
}
    
AggregateProgressTracker::~AggregateProgressTracker()
{
}

void AggregateProgressTracker::AddPool( Pool &_pool )
{
    Purge();

    const auto p = _pool.shared_from_this();
    LOCK_GUARD(m_Lock) {
        if( any_of( begin(m_Pools), end(m_Pools), [=](const auto &_i){ return _i.lock() == p; } ) )
            return;
        m_Pools.emplace_back(p);
        
        const auto weak_this = weak_ptr<AggregateProgressTracker>(shared_from_this());
        _pool.ObserveUnticketed(Pool::NotifyAboutChange, [weak_this]{
            if( auto me = weak_this.lock() )
                me->PoolsChanged();
        });
    }
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
            const auto weak_this = weak_ptr<AggregateProgressTracker>(shared_from_this());
            dispatch_to_main_queue_after(g_UpdateDelay, [weak_this]{
                if( auto me = weak_this.lock() )
                    me->Update();
            });
        }
    }
    else {
        m_IsTracking = false;
        const auto weak_this = weak_ptr<AggregateProgressTracker>(shared_from_this());
        dispatch_to_main_queue([weak_this]{
            if( auto me = weak_this.lock() )
                me->Signal(InvalidProgess);
        });
    }
}

bool AggregateProgressTracker::ArePoolsEmpty() const
{
    LOCK_GUARD(m_Lock)
        for( const auto &wp: m_Pools )
            if( const auto p = wp.lock() )
                if( !p->Empty() )
                    return false;
    return true;
}

tuple<int, double> AggregateProgressTracker::OperationsAmountAndProgress() const
{
    int amount = 0;
    double progress = 0.;
    LOCK_GUARD(m_Lock)
        for( const auto &wp: m_Pools )
            if( const auto p = wp.lock() )
                if( !p->Empty() )
                    for( const auto &op: p->RunningOperations() ) {
                        const auto &stat = op->Statistics();
                        progress += stat.DoneFraction( stat.PreferredSource() );
                        ++amount;
                    }
    if( amount )
        progress /= amount;

    return make_tuple(amount, progress);
}

void AggregateProgressTracker::Update()
{
    const auto [amount, progress] = OperationsAmountAndProgress();
    m_IsTracking = amount != 0;
    Signal( amount ? progress : InvalidProgess );

    if( m_IsTracking ) {
        const auto weak_this = weak_ptr<AggregateProgressTracker>(shared_from_this());
        dispatch_to_main_queue_after(g_UpdateDelay, [weak_this]{
            if( auto me = weak_this.lock() )
                me->Update();
        });
    }
    else {
        m_IsUpdateScheduled = false;
    }
}

void AggregateProgressTracker::Signal( double _progress )
{
    dispatch_assert_main_queue();
    if( m_Callback )
        m_Callback(_progress);
}

void AggregateProgressTracker::SetProgressCallback( function<void(double _progress)> _callback )
{
    dispatch_assert_main_queue();
    m_Callback = move(_callback);
}

void AggregateProgressTracker::Purge()
{
    LOCK_GUARD(m_Lock)
        m_Pools.erase(remove_if(begin(m_Pools),
                                end(m_Pools),
                                [](auto &v){ return v.expired(); }),
                      end(m_Pools));
}

}
