#pragma once

#include "Operation.h"

namespace nc::ops {


class Pool : public enable_shared_from_this<Pool>, private ScopedObservableBase
{
    Pool();
public:
    static shared_ptr<Pool> Make();
    ~Pool();
    
    void Enqueue( shared_ptr<Operation> _operation );


    enum {
        NotifyAboutAddition = 1<<0,
        NotifyAboutRemoval  = 1<<1,
        NotifyAboutChange   = NotifyAboutAddition | NotifyAboutRemoval
    };

    using ObservationTicket = ScopedObservableBase::ObservationTicket;
    ObservationTicket Observe( uint64_t _notification_mask, function<void()> _callback );
    void ObserveUnticketed( uint64_t _notification_mask, function<void()> _callback );
    
    int TotalOperationsCount() const;
    int RunningOperationsCount() const;

    shared_ptr<Operation> Front() const;
    vector<shared_ptr<Operation>> Operations() const;

private:
    Pool(const Pool&) = delete;
    void operator=(const Pool&) = delete;
    void OperationDidStart( const shared_ptr<Operation> &_operation );
    void OperationDidFinish( const shared_ptr<Operation> &_operation );
    

    vector<shared_ptr<Operation>>           m_Operations;
    mutable mutex                           m_Lock;
    atomic_int  m_RunningOperations;
};

}
