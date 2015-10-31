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

    const char* DisplayNameByStat( const struct stat &_st, const string &_path ); // nullptr string means that there's no dispay string for this
    
private:
#pragma pack(1)
    struct Tag
    {
        ino_t ino;
        dev_t dev;
    };
#pragma pack()
    static_assert( sizeof(Tag) == 12, "" );

    bool TryToFind( const struct stat &_st, const string &_path, const char *&_result ) const noexcept;
    const char* Commit( const struct stat &_st, const char *_dispay_name );
    
    atomic_int          m_Readers{0};
    spinlock            m_ReadLock;
    spinlock            m_WriteLock;
    vector<Tag>         m_Tags;
    vector<const char*> m_DisplayNames;
};
