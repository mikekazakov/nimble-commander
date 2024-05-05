// Copyright (C) 2017-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Operation.h"
#include <Cocoa/Cocoa.h>
#include <deque>

namespace nc::ops {

class Pool : public std::enable_shared_from_this<Pool>, private base::ScopedObservableBase
{
    Pool();

public:
    static std::shared_ptr<Pool> Make();
    ~Pool();

    // Operations and requests
    void Enqueue(std::shared_ptr<Operation> _operation);
    void StopAndWaitForShutdown();

    // Notifications
    enum {
        NotifyAboutAddition = 1 << 0,
        NotifyAboutRemoval = 1 << 1,
        NotifyAboutChange = NotifyAboutAddition | NotifyAboutRemoval
    };
    using ObservationTicket = ScopedObservableBase::ObservationTicket;
    ObservationTicket Observe(uint64_t _notification_mask, std::function<void()> _callback);
    void ObserveUnticketed(uint64_t _notification_mask, std::function<void()> _callback);

    // Queries
    bool Empty() const;
    int OperationsCount() const;
    int RunningOperationsCount() const;
    std::vector<std::shared_ptr<Operation>> Operations() const;
    std::vector<std::shared_ptr<Operation>> RunningOperations() const;

    // Concurrency settings
    int Concurrency();
    void SetConcurrency(int _maximum_current_operations);
    // By default all operation are assumed to be queued and obey the concurrency limits.
    // A client can customise this behaviour and decide it on a per-operation level.
    void SetEnqueuingCallback(std::function<bool(const Operation &_operation)> _should_be_queued);

    bool IsInteractive() const;
    void SetDialogCallback(std::function<void(NSWindow *, std::function<void(NSModalResponse)>)> _callback);
    void SetOperationCompletionCallback(std::function<void(const std::shared_ptr<Operation> &)> _callback);

private:
    Pool(const Pool &) = delete;
    void operator=(const Pool &) = delete;
    void OperationDidStart(const std::shared_ptr<Operation> &_operation);
    void OperationDidFinish(const std::shared_ptr<Operation> &_operation);
    bool ShowDialog(NSWindow *_dialog, std::function<void(NSModalResponse)> _callback);
    void StartPendingOperations();

    std::vector<std::shared_ptr<Operation>> m_RunningOperations;
    std::deque<std::shared_ptr<Operation>> m_PendingOperations;
    mutable std::mutex m_Lock;
    std::atomic_int m_Concurrency{5};

    std::function<bool(const Operation &_operation)> m_ShouldBeQueuedCallback;

    std::function<void(NSWindow *dialog, std::function<void(NSModalResponse response)>)> m_DialogPresentation;
    std::function<void(const std::shared_ptr<Operation> &)> m_OperationCompletionCallback;
};

} // namespace nc::ops
