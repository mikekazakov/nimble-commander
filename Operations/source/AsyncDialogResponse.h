#pragma once

#include <Cocoa/Cocoa.h>

namespace nc::ops {

struct AsyncDialogResponse
{
    optional<NSModalResponse>   response;
    unordered_map<string, any>  messages;
    mutex                       lock;
    condition_variable          blocker;
    
    void Abort() noexcept;
    void Commit(NSModalResponse _response) noexcept;
    void Wait() noexcept;
};

}
