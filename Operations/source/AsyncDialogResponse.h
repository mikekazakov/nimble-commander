#pragma once

#include "ModalDialogResponses.h"

namespace nc::ops {

struct AsyncDialogResponse
{
    optional<long>              response;
    unordered_map<string, any>  messages;
    mutex                       lock;
    condition_variable          blocker;
    
    void Abort() noexcept;
    void Commit(long _response) noexcept;
    void Wait() noexcept;
    
    void SetApplyToAll( bool _v = true );
    bool IsApplyToAllSet() noexcept;
};

}
