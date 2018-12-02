// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ModalDialogResponses.h"

namespace nc::ops {

struct AsyncDialogResponse
{
    std::optional<long>              response;
    std::unordered_map<std::string, std::any>  messages;
    std::mutex                       lock;
    std::condition_variable          blocker;
    
    void Abort() noexcept;
    void Commit(long _response) noexcept;
    void Wait() noexcept;
    
    void SetApplyToAll( bool _v = true );
    bool IsApplyToAllSet() noexcept;
};

}
