// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AsyncDialogResponse.h"
#include "ModalDialogResponses.h"
#include <Habanero/spinlock.h>

namespace nc::ops {

void AsyncDialogResponse::Abort() noexcept
{
    LOCK_GUARD(lock)
        response = NSModalResponseAbort;
    blocker.notify_all();
}

void AsyncDialogResponse::Commit(long _response) noexcept
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
    std::unique_lock<std::mutex> lck{lock};
    blocker.wait(lck, pred);
}

void AsyncDialogResponse::SetApplyToAll( bool _v  )
{
    messages["apply_to_all"] = _v;
}

bool AsyncDialogResponse::IsApplyToAllSet() noexcept
{
    const auto it = messages.find("apply_to_all");
    if( it == end(messages) )
        return false;

    if( const auto v = std::any_cast<bool>(&it->second) )
        return *v;
    
    return false;
}

}
