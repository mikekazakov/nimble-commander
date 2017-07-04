#pragma once

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
};

}
