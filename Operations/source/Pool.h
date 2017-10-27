// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Operation.h"
#include <Cocoa/Cocoa.h>

namespace nc::ops {

class Pool : public enable_shared_from_this<Pool>, private ScopedObservableBase
{
    Pool();
public:
    static shared_ptr<Pool> Make();
    ~Pool();
    
    void Enqueue( shared_ptr<Operation> _operation );
    static int ConcurrencyPerPool();
    static void SetConcurrencyPerPool( int _maximum_current_operations );

    enum {
        NotifyAboutAddition = 1<<0,
        NotifyAboutRemoval  = 1<<1,
        NotifyAboutChange   = NotifyAboutAddition | NotifyAboutRemoval
    };

    using ObservationTicket = ScopedObservableBase::ObservationTicket;
    ObservationTicket Observe( uint64_t _notification_mask, function<void()> _callback );
    void ObserveUnticketed( uint64_t _notification_mask, function<void()> _callback );
    
    bool Empty() const;
    int OperationsCount() const;
    int RunningOperationsCount() const;
    vector<shared_ptr<Operation>> Operations() const;
    vector<shared_ptr<Operation>> RunningOperations() const;

    void StopAndWaitForShutdown();

    bool IsInteractive() const;
    void SetDialogCallback(function<void(NSWindow*, function<void(NSModalResponse)>)> _callback);
    void SetOperationCompletionCallback(function<void(const shared_ptr<Operation>&)> _callback);

private:
    Pool(const Pool&) = delete;
    void operator=(const Pool&) = delete;
    void OperationDidStart( const shared_ptr<Operation> &_operation );
    void OperationDidFinish( const shared_ptr<Operation> &_operation );
    bool ShowDialog(NSWindow *_dialog, function<void (NSModalResponse)> _callback);
    void StartPendingOperations();
    
    vector<shared_ptr<Operation>>           m_RunningOperations;
    deque<shared_ptr<Operation>>            m_PendingOperations;
    mutable mutex                           m_Lock;
    
    function<void(NSWindow *dialog, function<void(NSModalResponse response)>)> m_DialogPresentation;
    function<void(const shared_ptr<Operation>&)> m_OperationCompletionCallback;
    static atomic_int m_ConcurrencyPerPool;
};

}
