// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <sys/stat.h>
#include <optional>
#include <unordered_map>
#include <atomic>
#include <Habanero/spinlock.h>

namespace nc::vfs::native {

/**
 * Presumably should be used only on directories.
 */
class DisplayNamesCache
{
public:
    static DisplayNamesCache& Instance();

    // nullptr string means that there's no dispay string for this
    const char* DisplayName( const struct stat &_st, const std::string &_path );
    const char* DisplayName( ino_t _ino, dev_t _dev, const std::string &_path );
    
private:
    std::optional<const char*> Fast_Unlocked(ino_t _ino,
                                             dev_t _dev,
                                             const std::string &_path ) const noexcept;
    void Commit_Locked(ino_t _ino,
                       dev_t _dev, 
                       const std::string &_path,
                       const char *_dispay_name );
    
    struct Filename
    {
        const char* fs_filename;
        const char* display_filename;
    };
    using Inodes = std::unordered_multimap<ino_t, Filename>;
    using Devices = std::unordered_map<dev_t, Inodes>;
    
    std::atomic_int m_Readers{0};
    spinlock   m_ReadLock;
    spinlock   m_WriteLock;
    Devices    m_Devices;
};

}
