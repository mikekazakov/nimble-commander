// Copyright (C) 2013-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>
#include <string>
#include <functional>
#include <memory>

class FSEventsDirUpdate
{
public:
    static FSEventsDirUpdate &Instance();
 
    // zero returned value means error. any others - valid observation tickets
    uint64_t AddWatchPath(const char *_path, std::function<void()> _handler);
    
    // it's better to use this method
    bool RemoveWatchPathWithTicket(uint64_t _ticket);
    
private:
    friend class NativeFSManager;
    
    // called exclusevily by NativeFSManager
    void OnVolumeDidUnmount(const std::string &_on_path);
    
    FSEventsDirUpdate();
    struct Impl;
    std::unique_ptr<Impl>   me;
};
