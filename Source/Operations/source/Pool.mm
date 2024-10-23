// Copyright (C) 2017-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Pool.h"
#include "Operation.h"
#include <Base/dispatch_cpp.h>
#include <thread>

namespace nc::ops {

template <class C, class T>
void erase_from(C &_c, const T &_t)
{
    _c.erase(remove(begin(_c), end(_c), _t), end(_c));
}

std::shared_ptr<Pool> Pool::Make()
{
    struct workaround : public Pool {
    };
    return std::make_shared<workaround>();
}

Pool::Pool() = default;

Pool::~Pool() = default;

void Pool::Enqueue(std::shared_ptr<Operation> _operation)
{
    if( !_operation || _operation->State() != OperationState::Cold )
        return;

    const auto weak_this = std::weak_ptr<Pool>{shared_from_this()};
    const auto weak_operation = std::weak_ptr<Operation>{_operation};
    _operation->ObserveUnticketed(Operation::NotifyAboutFinish, [weak_this, weak_operation] {
        const auto pool = weak_this.lock();
        const auto op = weak_operation.lock();
        if( pool && op )
            pool->OperationDidFinish(op);
    });
    _operation->ObserveUnticketed(Operation::NotifyAboutStart, [weak_this, weak_operation] {
        const auto pool = weak_this.lock();
        const auto op = weak_operation.lock();
        if( pool && op )
            pool->OperationDidStart(op);
    });
    _operation->SetDialogCallback([weak_this](NSWindow *_dlg, std::function<void(NSModalResponse)> _cb) {
        if( const auto pool = weak_this.lock() )
            return pool->ShowDialog(_dlg, _cb);
        return false;
    });

    {
        const auto guard = std::lock_guard{m_Lock};
        m_PendingOperations.push_back(_operation);
    }

    FireObservers(NotifyAboutAddition);
    StartPendingOperations();
}

void Pool::OperationDidStart([[maybe_unused]] const std::shared_ptr<Operation> &_operation)
{
}

void Pool::OperationDidFinish([[maybe_unused]] const std::shared_ptr<Operation> &_operation)
{
    {
        const auto guard = std::lock_guard{m_Lock};
        erase_from(m_RunningOperations, _operation);
        erase_from(m_PendingOperations, _operation);
    }
    FireObservers(NotifyAboutRemoval);
    StartPendingOperations();

    if( _operation->State() == OperationState::Completed && m_OperationCompletionCallback )
        m_OperationCompletionCallback(_operation);
}

void Pool::StartPendingOperations()
{
    std::vector<std::shared_ptr<Operation>> to_start;

    // 1st - gather all pending operations for which the EnqueuingCallback tells 'false'
    if( m_ShouldBeQueuedCallback ) {
        const auto guard = std::lock_guard{m_Lock};
        for( auto &operation : m_PendingOperations ) {
            assert(operation != nullptr);
            if( !m_ShouldBeQueuedCallback(*operation) ) {
                to_start.emplace_back(operation);
                m_RunningOperations.emplace_back(operation);
                operation.reset();
            }
        }
        std::erase_if(m_PendingOperations, [](const auto &_op) { return _op == nullptr; });
    }

    // 2nd - gather any other operations until the pool has enough running operations
    {
        const auto guard = std::lock_guard{m_Lock};
        const auto running_now = static_cast<int>(m_RunningOperations.size());
        auto gathered = 0;
        while( running_now + gathered < m_Concurrency && !m_PendingOperations.empty() ) {
            const auto op = m_PendingOperations.front();
            m_PendingOperations.pop_front();
            to_start.emplace_back(op);
            m_RunningOperations.emplace_back(op);
            ++gathered;
        }
    }

    // now kickstart all these operations
    for( const auto &op : to_start )
        op->Start();
}

Pool::ObservationTicket Pool::Observe(uint64_t _notification_mask, std::function<void()> _callback)
{
    return AddTicketedObserver(std::move(_callback), _notification_mask);
}

void Pool::ObserveUnticketed(uint64_t _notification_mask, std::function<void()> _callback)
{
    AddUnticketedObserver(std::move(_callback), _notification_mask);
}

int Pool::RunningOperationsCount() const
{
    const auto guard = std::lock_guard{m_Lock};
    return static_cast<int>(m_RunningOperations.size());
}

int Pool::OperationsCount() const
{
    const auto guard = std::lock_guard{m_Lock};
    return static_cast<int>(m_RunningOperations.size() + m_PendingOperations.size());
}

std::vector<std::shared_ptr<Operation>> Pool::Operations() const
{
    const auto guard = std::lock_guard{m_Lock};
    auto v = m_RunningOperations;
    v.insert(end(v), begin(m_PendingOperations), end(m_PendingOperations));
    return v;
}

std::vector<std::shared_ptr<Operation>> Pool::RunningOperations() const
{
    const auto guard = std::lock_guard{m_Lock};
    return m_RunningOperations;
}

void Pool::SetDialogCallback(std::function<void(NSWindow *, std::function<void(NSModalResponse)>)> _callback)
{
    m_DialogPresentation = std::move(_callback);
}

void Pool::SetOperationCompletionCallback(std::function<void(const std::shared_ptr<Operation> &)> _callback)
{
    m_OperationCompletionCallback = std::move(_callback);
}

bool Pool::IsInteractive() const
{
    return m_DialogPresentation != nullptr;
}

bool Pool::ShowDialog(NSWindow *_dialog, std::function<void(NSModalResponse)> _callback)
{
    dispatch_assert_main_queue();
    if( !m_DialogPresentation )
        return false;
    m_DialogPresentation(_dialog, std::move(_callback));
    return true;
}

int Pool::Concurrency()
{
    return m_Concurrency;
}

void Pool::SetConcurrency(int _maximum_current_operations)
{
    m_Concurrency = std::max(_maximum_current_operations, 1);
}

void Pool::SetEnqueuingCallback(std::function<bool(const Operation &_operation)> _should_be_queued)
{
    assert(Empty());
    m_ShouldBeQueuedCallback = std::move(_should_be_queued);
}

bool Pool::Empty() const
{
    const auto guard = std::lock_guard{m_Lock};
    return m_RunningOperations.empty() && m_PendingOperations.empty();
}

void Pool::StopAndWaitForShutdown()
{
    {
        const auto guard = std::lock_guard{m_Lock};
        for( auto &o : m_PendingOperations )
            o->Stop();
        for( auto &o : m_RunningOperations )
            o->Stop();
    }

    using namespace std::literals;
    while( !Empty() )
        std::this_thread::sleep_for(10ms); // TODO: wtf is this???
}

} // namespace nc::ops
