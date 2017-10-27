// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
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
