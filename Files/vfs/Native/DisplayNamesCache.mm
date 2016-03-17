//
//  DisplayNamesCache.mm
//  Files
//
//  Created by Michael G. Kazakov on 28.06.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "DisplayNamesCache.h"

DisplayNamesCache& DisplayNamesCache::Instance()
{
    static auto inst = new DisplayNamesCache; // never free
    return *inst;
}

bool DisplayNamesCache::TryToFind( const struct stat &_st, const string &_path, const char *&_result ) const noexcept
{
    // just go thru all tags and check if we have the requested one - should be VERY FAST
    ino_t ino = _st.st_ino;
    dev_t dev = _st.st_dev;
    for( size_t i = 0, e = m_Tags.size(); i != e; ++i )
        if( m_Tags[i].ino == ino && m_Tags[i].dev == dev ) {
            _result = m_DisplayNames[i];
            return true;
        }
    return false;
}

const char* DisplayNamesCache::Commit( const struct stat &_st, const char *_dispay_name )
{
    const char *string = _dispay_name ? strdup(_dispay_name) : nullptr; // only allocates memory, never release it
    Tag tag;
    tag.dev = _st.st_dev;
    tag.ino = _st.st_ino;
    
    lock_guard<spinlock> guard(m_WriteLock);
    m_Tags.emplace_back(tag);
    m_DisplayNames.emplace_back(string);
    
    return string;
}

// many readers, one writer | readers preference, based on atomic spinlocks
static NSFileManager *filemanager = NSFileManager.defaultManager;
const char* DisplayNamesCache::DisplayNameByStat( const struct stat &_st, const string &_path )
{
    // FAST PATH BEGINS
    m_ReadLock.lock();
    if( (++m_Readers) == 1 )
        m_WriteLock.lock();
    m_ReadLock.unlock();
    
    const char *result = nullptr;
    bool did_found = TryToFind(_st, _path, result);
    
    m_ReadLock.lock();
    if( (--m_Readers) == 0 )
        m_WriteLock.unlock();
    m_ReadLock.unlock();
    
    if(did_found)
        return result;
    // FAST PATH ENDS
    
    // SLOW PATH BEGINS
    NSString *path = [NSString stringWithUTF8StdStringNoCopy:_path];
    if(path == nil)
        return Commit( _st, nullptr ); // can't create string for this path.
    
    NSString *display_name = [filemanager displayNameAtPath:path];
    if(display_name == nil)
        return Commit( _st, nullptr ); // something strange has happen
    
    display_name = [display_name decomposedStringWithCanonicalMapping];
    const char* display_utf8_name = display_name.UTF8String;
    
    if( strcmp(_path.c_str() + _path.rfind('/') + 1, display_utf8_name) == 0 )
        return Commit( _st, nullptr ); // this display name is exactly like the filesystem one

    result = Commit( _st, display_utf8_name );
    // SLOW PATH ENDS
    
    return result;
}
