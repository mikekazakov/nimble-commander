// Copyright (C) 2014-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/dispatch_cpp.h>
#include <stdexcept>

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

namespace nc {

bool dispatch_is_main_queue() noexcept
{
    return pthread_main_np() != 0;
}

}
