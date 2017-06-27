#include "Pool.h"
#include "Operation.h"

namespace nc::ops {

shared_ptr<Pool> Pool::Make()
{
    return shared_ptr<Pool>{new Pool};
}

Pool::Pool():
//    m_ShuttingDown{false},
    m_RunningOperations{0}
//    m_LifetimeTracker{ make_shared<atomic_bool>(true) }
{
}

Pool::~Pool()
{
//    *m_LifetimeTracker = false;
//    LOCK_GUARD(m_Lock) {
//        m_OperationsObservations.clear();
//    }
}

void Pool::Enqueue( shared_ptr<Operation> _operation )
{
    if( !_operation || _operation->State() != OperationState::Cold )
        return;

    const auto weak_this = weak_ptr<Pool>{shared_from_this()};
    const auto weak_operation = weak_ptr<Operation>{_operation};
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
    _operation->SetDialogCallback([weak_this](NSWindow* _dlg, function<void(NSModalResponse)>_cb){
        if( const auto pool = weak_this.lock() )
            return pool->ShowDialog(_dlg, _cb);
        return false;
    });

    
    LOCK_GUARD(m_Lock) {
        m_Operations.emplace_back( _operation );
    }
    
    // + starting logic
    
    _operation->Start();
    FireObservers( NotifyAboutAddition );
}

void Pool::OperationDidStart( const shared_ptr<Operation> &_operation )
{
    m_RunningOperations++;
//    FireObservers( Notify )
    
    LOCK_GUARD(m_Lock) {

    
    }


}

void Pool::OperationDidFinish( const shared_ptr<Operation> &_operation )
{
    m_RunningOperations--;

    LOCK_GUARD(m_Lock) {
        m_Operations.erase(remove( begin(m_Operations), end(m_Operations), _operation ),
                           end(m_Operations));
    }
    FireObservers( NotifyAboutRemoval );
}

Pool::ObservationTicket Pool::Observe( uint64_t _notification_mask, function<void()> _callback )
{
    return AddTicketedObserver( move(_callback), _notification_mask );
}

void Pool::ObserveUnticketed( uint64_t _notification_mask, function<void()> _callback )
{
    AddUnticketedObserver( move(_callback), _notification_mask );
}

int Pool::RunningOperationsCount() const
{
//    return m
    return m_RunningOperations;
}

int Pool::TotalOperationsCount() const
{
    LOCK_GUARD(m_Lock)
        return (int)m_Operations.size();
}

shared_ptr<Operation> Pool::Front() const
{
    LOCK_GUARD(m_Lock)
        return m_Operations.empty() ? nullptr : m_Operations.front();
}

vector<shared_ptr<Operation>> Pool::Operations() const
{
    LOCK_GUARD(m_Lock)
        return m_Operations;
}

void Pool::SetDialogCallback(function<void(NSWindow*, function<void(NSModalResponse)>)> _callback)
{
    m_DialogPresentation = _callback;
}

bool Pool::IsInteractive() const
{
    return m_DialogPresentation != nullptr;
}

bool Pool::ShowDialog(NSWindow *_dialog, function<void (NSModalResponse)> _callback)
{
    dispatch_assert_main_queue();
    if( !m_DialogPresentation  )
        return false;
    m_DialogPresentation(_dialog, move(_callback));
    return true;
}

}
