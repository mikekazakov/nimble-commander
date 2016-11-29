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

static bool is_same_filename( const char *_filename, const string &_path )
{
    const auto p = _path.rfind('/');
    return p != string::npos && strcmp( _filename, _path.c_str() + p + 1 ) == 0;
}

optional<const char*> DisplayNamesCache::Fast_Unlocked( ino_t _ino, dev_t _dev, const string &_path ) const noexcept
{
    // just go thru all tags and check if we have the requested one - should be VERY FAST
    const auto e = (int)m_Inodes.size();
    for( int i = 0; i != e; ++i )
        if( m_Inodes[i] == _ino )
            if( m_Devs[i] == _dev )
                if( is_same_filename(m_Filenames[i], _path) )
                    return m_DisplayNames[i];
    return nullopt;
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
    
    lock_guard<spinlock> guard(m_WriteLock);
    m_Inodes.emplace_back( _ino );
    m_Devs.emplace_back( _dev );
    m_Filenames.emplace_back( filename_dup(_path) );
    m_DisplayNames.emplace_back( _dispay_name );
}

const char* DisplayNamesCache::DisplayName( const struct stat &_st, const string &_path )
{
    return DisplayName( _st.st_ino, _st.st_dev, _path );
}

static NSFileManager *filemanager = NSFileManager.defaultManager;
const char* Slow( const string &_path )
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

const char* DisplayNamesCache::DisplayName( ino_t _ino, dev_t _dev, const string &_path )
{
    // many readers, one writer | readers preference, based on atomic spinlocks
    
    // FAST PATH BEGINS
    m_ReadLock.lock();
    if( (++m_Readers) == 1 )
        m_WriteLock.lock();
    m_ReadLock.unlock();
    
    const auto existed = Fast_Unlocked(_ino, _dev, _path);
    
    m_ReadLock.lock();
    if( (--m_Readers) == 0 )
        m_WriteLock.unlock();
    m_ReadLock.unlock();
    
    if( existed )
        return *existed;
    // FAST PATH ENDS
    
    // SLOW PATH BEGINS
    const auto generated_str = Slow( _path );
    Commit_Locked( _ino, _dev, _path, generated_str );
    return generated_str;
    // SLOW PATH ENDS
}
