#include <stdexcept>
#include <Habanero/dispatch_cpp.h>

dispatch_queue::dispatch_queue(const char *label, bool concurrent):
    m_queue(dispatch_queue_create(label,
                                  concurrent ? DISPATCH_QUEUE_CONCURRENT : DISPATCH_QUEUE_SERIAL))
{
}

dispatch_queue::~dispatch_queue()
{
    dispatch_release(m_queue);
}

dispatch_queue::dispatch_queue(const dispatch_queue& rhs):
    m_queue(rhs.m_queue)
{
    dispatch_retain(m_queue);
}

const dispatch_queue &dispatch_queue::operator=(const dispatch_queue& rhs)
{
    dispatch_release(m_queue);
    m_queue = rhs.m_queue;
    dispatch_retain(m_queue);
    return *this;
}

////////////////////////////////////////////////////////////////////////////////
// DispatchGroup implementation
////////////////////////////////////////////////////////////////////////////////
DispatchGroup::DispatchGroup(Priority _priority):
    m_Queue(dispatch_get_global_queue(_priority, 0)),
    m_Group(dispatch_group_create())
{
    if( !m_Queue || !m_Group )
        throw std::runtime_error("DispatchGroup::DispatchGroup(): can't create libdispatch objects");
}

DispatchGroup::~DispatchGroup()
{
    Wait();
    dispatch_release(m_Group);
}

void DispatchGroup::Wait() const noexcept
{
    dispatch_group_wait(m_Group, DISPATCH_TIME_FOREVER);
}

int DispatchGroup::Count() const noexcept
{
    return m_Count;
}

void DispatchGroup::SetOnDry( std::function<void()> _cb )
{
    std::shared_ptr<std::function<void()>> cb = std::make_shared<std::function<void()>>( move(_cb) );
    LOCK_GUARD(m_CBLock) {
        m_OnDry = cb;
    }
}

void DispatchGroup::Increment() const
{
    ++m_Count;
}

void DispatchGroup::Decrement() const
{
    if( --m_Count == 0 ) {
        std::shared_ptr<std::function<void()>> cb;
        LOCK_GUARD(m_CBLock) {
            cb = m_OnDry;
        }

        if( cb && *cb )
            (*cb)();
    }
}
