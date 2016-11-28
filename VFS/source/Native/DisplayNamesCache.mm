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

bool DisplayNamesCache::Fast_Unlocked( ino_t _ino, dev_t _dev, const string &_path, const char *&_result ) const noexcept
{
    // just go thru all tags and check if we have the requested one - should be VERY FAST
    for( size_t i = 0, e = m_Tags.size(); i != e; ++i )
        if( m_Tags[i].ino == _ino && m_Tags[i].dev == _dev ) {
            // same ino-dev pair, need to check filename
            auto i = _path.rfind('/');
            if( i != string::npos &&
               strcmp( m_Tags[i].filename, _path.c_str() + i + 1 ) == 0 ) {
                _result = m_DisplayNames[i];
                return true;
            }
        }
    
    return false;
}

static const char *filename_dup( const string &_path )
{
    auto i = _path.rfind('/');
    if( i == string::npos )
        return "";
    return strdup( _path.c_str() + i + 1 );
}

void DisplayNamesCache::Commit_Locked(ino_t _ino,
                                      dev_t _dev,
                                      const string &_path,
                                      const char *_dispay_name )
{
    Tag tag;
    tag.dev = _dev;
    tag.ino = _ino;
    tag.filename = filename_dup(_path);
    
    lock_guard<spinlock> guard(m_WriteLock);
    m_Tags.emplace_back(tag);
    m_DisplayNames.emplace_back(_dispay_name);
}

// many readers, one writer | readers preference, based on atomic spinlocks
static NSFileManager *filemanager = NSFileManager.defaultManager;
const char* DisplayNamesCache::DisplayName( const struct stat &_st, const string &_path )
{
    return DisplayName( _st.st_ino, _st.st_dev, _path );
}

const char* DisplayNamesCache::DisplayName( ino_t _ino, dev_t _dev, const string &_path )
{
    // FAST PATH BEGINS
    m_ReadLock.lock();
    if( (++m_Readers) == 1 )
        m_WriteLock.lock();
    m_ReadLock.unlock();
    
    const char *result = nullptr;
    bool did_found = Fast_Unlocked( _ino, _dev, _path, result );
    
    m_ReadLock.lock();
    if( (--m_Readers) == 0 )
        m_WriteLock.unlock();
    m_ReadLock.unlock();
    
    if( did_found )
        return result;
    // FAST PATH ENDS
    
    // SLOW PATH BEGINS
    const auto generated_str = Slow( _path );
    Commit_Locked( _ino, _dev, _path, generated_str );
    return generated_str;
    // SLOW PATH ENDS
}

const char* DisplayNamesCache::Slow( const string &_path )
{
    NSString *path = [NSString stringWithUTF8StdStringNoCopy:_path];
    if( path == nil )
        return nullptr; // can't create string for this path.
    
    NSString *display_name = [filemanager displayNameAtPath:path];
    if( display_name == nil )
        return nullptr; // something strange has happen
    
    display_name = [display_name decomposedStringWithCanonicalMapping];
    const char* display_utf8_name = display_name.UTF8String;
    
    if( strcmp(_path.c_str() + _path.rfind('/') + 1, display_utf8_name) == 0 )
        return nullptr; // this display name is exactly like the filesystem one
    
    return strdup( display_utf8_name );
}
