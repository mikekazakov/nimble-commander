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
#pragma pack(1)
    struct Tag
    {
        ino_t ino;
        dev_t dev;
        const char *filename;
    };
#pragma pack()
    static_assert( sizeof(Tag) == 20 );

    bool Fast_Unlocked( ino_t _ino, dev_t _dev, const string &_path, const char *&_result ) const noexcept;
    static const char* Slow( const string &_path );
    void Commit_Locked( ino_t _ino, dev_t _dev, const string &_path, const char *_dispay_name );
    
    atomic_int          m_Readers{0};
    spinlock            m_ReadLock;
    spinlock            m_WriteLock;
    vector<Tag>         m_Tags;
    vector<const char*> m_DisplayNames;
};
