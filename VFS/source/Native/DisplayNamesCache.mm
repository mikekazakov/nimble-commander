// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DisplayNamesCache.h"
#include <Foundation/Foundation.h>
#include <Utility/StringExtras.h>

namespace nc::vfs::native {

DisplayNamesCache& DisplayNamesCache::Instance()
{
    static auto inst = new DisplayNamesCache; // never free
    return *inst;
}

static bool is_same_filename( const char *_filename, const std::string &_path )
{
    const auto p = _path.rfind('/');
    return p != std::string::npos && strcmp( _filename, _path.c_str() + p + 1 ) == 0;
}

std::optional<const char*> DisplayNamesCache::Fast_Unlocked(ino_t _ino,
                                                            dev_t _dev,
                                                            const std::string &_path ) const noexcept
{
    const auto inodes = m_Devices.find(_dev);
    if( inodes == end(m_Devices) )
        return std::nullopt;

    const auto range = inodes->second.equal_range(_ino);
    for( auto i = range.first; i != range.second; ++i )
        if( is_same_filename( i->second.fs_filename, _path) )
            return i->second.display_filename;

    return std::nullopt;
}

static const char *filename_dup( const std::string &_path )
{
    auto i = _path.rfind('/');
    if( i == std::string::npos )
        return "";
    return strdup( _path.c_str() + i + 1 );
}

void DisplayNamesCache::Commit_Locked(ino_t _ino,
                                      dev_t _dev,
                                      const std::string &_path,
                                      const char *_dispay_name )
{
    Filename f;
    f.fs_filename = filename_dup(_path);
    f.display_filename = _dispay_name;
    std::lock_guard<spinlock> guard(m_WriteLock);
    m_Devices[_dev].insert( std::make_pair(_ino, f) );
}

const char* DisplayNamesCache::DisplayName( const struct stat &_st, const std::string &_path )
{
    return DisplayName( _st.st_ino, _st.st_dev, _path );
}

static NSFileManager *filemanager = NSFileManager.defaultManager;
static const char* Slow( const std::string &_path )
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

const char* DisplayNamesCache::DisplayName( ino_t _ino, dev_t _dev, const std::string &_path )
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

}
