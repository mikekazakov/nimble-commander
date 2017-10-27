// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::vfs::native {

/**
 * Presumably should be used only on directories.
 */
class DisplayNamesCache
{
public:
    static DisplayNamesCache& Instance();

    // nullptr string means that there's no dispay string for this
    const char* DisplayName( const struct stat &_st, const string &_path );
    const char* DisplayName( ino_t _ino, dev_t _dev, const string &_path );
    
private:
    optional<const char*> Fast_Unlocked( ino_t _ino, dev_t _dev, const string &_path ) const noexcept;
    void Commit_Locked( ino_t _ino, dev_t _dev, const string &_path, const char *_dispay_name );
    
    struct Filename
    {
        const char* fs_filename;
        const char* display_filename;
    };
    using Inodes = unordered_multimap<ino_t, Filename>;
    using Devices = unordered_map<dev_t, Inodes>;
    
    atomic_int m_Readers{0};
    spinlock   m_ReadLock;
    spinlock   m_WriteLock;
    Devices    m_Devices;
};

}
