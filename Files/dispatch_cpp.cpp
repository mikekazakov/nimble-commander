#include "dispatch_cpp.h"

namespace __dispatch_cpp {
    
void __dispatch_cpp_exec_delete_callable(void*context)
{
    auto l = reinterpret_cast<__callable_exec_base*>(context);
    l->exec();
    delete l;
}
    
void __dispatch_cpp_apply_lambda(void* context, size_t it)
{
    auto l = reinterpret_cast<__lambda_apply*>(context);
    (*l)(it);
}

}

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
