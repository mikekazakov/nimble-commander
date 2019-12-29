// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "NativeFSManager.h"
#include <memory>
#include <atomic>
#include <string_view>

namespace nc::utility {

struct NativeFileSystemInfo;

class NativeFSManager::VolumeLookup
{
public:
    // expects absolute paths ending with a trailing slash
    void Insert( const std::shared_ptr<const NativeFileSystemInfo> &_volume, std::string_view _at );
    
    void Remove( std::string_view _from );
    std::shared_ptr<const NativeFileSystemInfo>
        FindVolumeForLocation( std::string_view _location ) const noexcept;
    static std::atomic_int64_t LookupCount;
private:
    // this is a semi-dummy implementation with a linear complexity,
    // something more efficient can be written instead.
    // However, with N low enough this might be absolutely ok.
    std::vector<std::string> m_Targets;
    std::vector<std::shared_ptr<const NativeFileSystemInfo>> m_Sources;
};

}
