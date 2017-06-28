#include "AsyncDialogResponse.h"

namespace nc::ops {

void AsyncDialogResponse::Abort() noexcept
{
    LOCK_GUARD(lock)
    response = NSModalResponseAbort;
    blocker.notify_all();
}

void AsyncDialogResponse::Commit(NSModalResponse _response) noexcept
{
    LOCK_GUARD(lock)
    response = _response;
    blocker.notify_all();
}

void AsyncDialogResponse::Wait() noexcept
{
    const auto pred = [this]{
        return (bool)response;
    };
    if( pred() )
        return;
    unique_lock<mutex> lck{lock};
    blocker.wait(lck, pred);
}
    
}
