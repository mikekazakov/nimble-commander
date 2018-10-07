// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>
#include <string>
#include <functional>
#include <memory>

namespace nc::utility {
    class NativeFSManager;
}

class FSEventsDirUpdate
{
public:
    static FSEventsDirUpdate &Instance();
 
    // zero returned value means error. any others - valid observation tickets
    uint64_t AddWatchPath(const char *_path, std::function<void()> _handler);
    
    // it's better to use this method
    void RemoveWatchPathWithTicket(uint64_t _ticket);

    static inline const uint64_t no_ticket = 0;
    
private:
    friend class nc::utility::NativeFSManager;
    
    // called exclusevily by NativeFSManager
    void OnVolumeDidUnmount(const std::string &_on_path);
    
    FSEventsDirUpdate();
    struct Impl;
    std::unique_ptr<Impl>   me;
};
