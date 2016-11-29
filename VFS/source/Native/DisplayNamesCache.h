//
//  DisplayNamesCache.h
//  Files
//
//  Created by Michael G. Kazakov on 28.06.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

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
    
    atomic_int          m_Readers{0};
    spinlock            m_ReadLock;
    spinlock            m_WriteLock;
    vector<dev_t>       m_Devs;
    vector<uint32_t>    m_Inodes; // inodes actually cannot exceed 32bit range
    vector<const char*> m_Filenames;
    vector<const char*> m_DisplayNames;
};
