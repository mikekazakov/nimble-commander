// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Pool.h"
#include "Operation.h"
#include <Habanero/dispatch_cpp.h>
#include <thread>

namespace nc::ops {

std::atomic_int Pool::m_ConcurrencyPerPool{5};

template <class C, class T>
void erase_from(C &_c, const T& _t)
{
    _c.erase( remove( begin(_c), end(_c), _t ), end(_c) );
}

std::shared_ptr<Pool> Pool::Make()
{
    return std::shared_ptr<Pool>{new Pool};
}

Pool::Pool()
{
}

Pool::~Pool()
{
}

void Pool::Enqueue( std::shared_ptr<Operation> _operation )
{
    if( !_operation || _operation->State() != OperationState::Cold )
        return;

    const auto weak_this = std::weak_ptr<Pool>{shared_from_this()};
    const auto weak_operation = std::weak_ptr<Operation>{_operation};
    _operation->ObserveUnticketed(Operation::NotifyAboutFinish, [weak_this, weak_operation]{
        const auto pool = weak_this.lock();
        const auto op = weak_operation.lock();
        if( pool && op )
            pool->OperationDidFinish(op);
    });
    _operation->ObserveUnticketed(Operation::NotifyAboutStart, [weak_this, weak_operation]{
        const auto pool = weak_this.lock();
        const auto op = weak_operation.lock();
        if( pool && op )
            pool->OperationDidStart(op);
    });
    _operation->SetDialogCallback([weak_this](NSWindow* _dlg, std::function<void(NSModalResponse)>_cb){
        if( const auto pool = weak_this.lock() )
            return pool->ShowDialog(_dlg, _cb);
        return false;
    });

    LOCK_GUARD(m_Lock)
        m_PendingOperations.push_back( _operation );
    
    FireObservers( NotifyAboutAddition );
    StartPendingOperations();
}

void Pool::OperationDidStart( const std::shared_ptr<Operation> &_operation )
{
}

void Pool::OperationDidFinish( const std::shared_ptr<Operation> &_operation )
{
    LOCK_GUARD(m_Lock) {
        erase_from(m_RunningOperations, _operation);
        erase_from(m_PendingOperations, _operation);
    }
    FireObservers( NotifyAboutRemoval );
    StartPendingOperations();
    
    if( _operation->State() == OperationState::Completed && m_OperationCompletionCallback )
        m_OperationCompletionCallback(_operation);
}

void Pool::StartPendingOperations()
{
    std::vector<std::shared_ptr<Operation>> to_start;

    LOCK_GUARD(m_Lock) {
        const auto running_now = m_RunningOperations.size();
        while( running_now + to_start.size() < m_ConcurrencyPerPool &&
               !m_PendingOperations.empty() ) {
            const auto op = m_PendingOperations.front();
            m_PendingOperations.pop_front();
            to_start.emplace_back( op  );
            m_RunningOperations.emplace_back( op );
        }
    }
    
    for( const auto &op: to_start )
        op->Start();
}

Pool::ObservationTicket Pool::Observe( uint64_t _notification_mask, std::function<void()> _callback )
{
    return AddTicketedObserver( move(_callback), _notification_mask );
}

void Pool::ObserveUnticketed( uint64_t _notification_mask, std::function<void()> _callback )
{
    AddUnticketedObserver( move(_callback), _notification_mask );
}

int Pool::RunningOperationsCount() const
{
    LOCK_GUARD(m_Lock)
        return (int)m_RunningOperations.size();
}

int Pool::OperationsCount() const
{
    LOCK_GUARD(m_Lock)
        return (int)m_RunningOperations.size() + (int)m_PendingOperations.size();
}

std::vector<std::shared_ptr<Operation>> Pool::Operations() const
{
    LOCK_GUARD(m_Lock) {
        auto v = m_RunningOperations;
        v.insert( end(v), begin(m_PendingOperations), end(m_PendingOperations) );
        return v;
    }
}

std::vector<std::shared_ptr<Operation>> Pool::RunningOperations() const
{
    LOCK_GUARD(m_Lock)
        return m_RunningOperations;
}

void Pool::SetDialogCallback(std::function<void(NSWindow*, std::function<void(NSModalResponse)>)> _callback)
{
    m_DialogPresentation = std::move(_callback);
}

void Pool::SetOperationCompletionCallback(std::function<void(const std::shared_ptr<Operation>&)> _callback)
{
    m_OperationCompletionCallback = std::move(_callback);
}

bool Pool::IsInteractive() const
{
    return m_DialogPresentation != nullptr;
}

bool Pool::ShowDialog(NSWindow *_dialog, std::function<void (NSModalResponse)> _callback)
{
    dispatch_assert_main_queue();
    if( !m_DialogPresentation  )
        return false;
    m_DialogPresentation(_dialog, move(_callback));
    return true;
}

int Pool::ConcurrencyPerPool()
{
    return m_ConcurrencyPerPool;
}

void Pool::SetConcurrencyPerPool( int _maximum_current_operations )
{
    if( _maximum_current_operations < 1 )
        _maximum_current_operations = 1;
    m_ConcurrencyPerPool = _maximum_current_operations;
}

bool Pool::Empty() const
{
    LOCK_GUARD(m_Lock)
        return m_RunningOperations.empty() && m_PendingOperations.empty();
}

void Pool::StopAndWaitForShutdown()
{
    LOCK_GUARD(m_Lock) {
        for( auto &o: m_PendingOperations )
            o->Stop();
        for( auto &o: m_RunningOperations )
            o->Stop();
    }

    using namespace std::literals;
    while( !Empty() )
        std::this_thread::sleep_for(10ms);
}

}
