// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/QLVFSThumbnailsCacheImpl.h>
#include <Quartz/Quartz.h>
#include <boost/filesystem/path.hpp>

namespace nc::vfsicon {

static NSImage *ProduceThumbnailForTempFile(const std::string &_path, CGSize _px_size);
static std::optional<std::vector<uint8_t>> ReadEntireFile(const std::string &_path, VFSHost &_host);
    
QLVFSThumbnailsCacheImpl::QLVFSThumbnailsCacheImpl
    (const std::shared_ptr<utility::BriefOnDiskStorage> &_temp_storage):
    m_TempStorage(_temp_storage)
{
}

QLVFSThumbnailsCacheImpl::~QLVFSThumbnailsCacheImpl()
{        
}

NSImage *QLVFSThumbnailsCacheImpl::ThumbnailIfHas(const std::string &_file_path,
                                                  VFSHost &_host,
                                                  int _px_size)
{
    auto key = MakeKey(_file_path, _host, _px_size);
    
    {
        auto lock = std::lock_guard{m_Lock};
        if( m_Thumbnails.count(key) )
            return m_Thumbnails.at(key);
    }
            
    return nil;
}
    
NSImage *QLVFSThumbnailsCacheImpl::ProduceThumbnail(const std::string &_file_path,
                                                    VFSHost &_host,
                                                    int _px_size)
{
    auto key = MakeKey(_file_path, _host, _px_size);
    
    {
        auto lock = std::lock_guard{m_Lock};
        if( m_Thumbnails.count(key) )
            return m_Thumbnails.at(key);
    }
    
    auto image = ProduceThumbnail(_file_path,
                                  boost::filesystem::path(_file_path).extension().native(),
                                  _host,
                                  CGSizeMake(double(_px_size), double(_px_size))); 
    
    {
        auto lock = std::lock_guard{m_Lock};
        m_Thumbnails.insert(std::move(key), image);
    }
    
    return image; 
}

NSImage *QLVFSThumbnailsCacheImpl::ProduceThumbnail(const std::string &_path,
                                                    const std::string &_ext,
                                                    VFSHost &_host,
                                                    CGSize _sz)
{    
    auto data = ReadEntireFile(_path, _host);
    if( data.has_value() == false )
        return nil;
    
    auto placement_result = m_TempStorage->PlaceWithExtension(data->data(), data->size(), _ext);
    if( placement_result.has_value() == false )
        return nil;
        
    return ProduceThumbnailForTempFile(placement_result->Path(), _sz);
}
    
std::string QLVFSThumbnailsCacheImpl::MakeKey(const std::string &_file_path,
                                              VFSHost &_host,
                                              int _px_size)
{
    auto key = _host.MakePathVerbose(_file_path.c_str());
    key += "\x01";
    key += std::to_string(_px_size);
    return key;
}
    
static NSImage *ProduceThumbnailForTempFile(const std::string &_path, CGSize _px_size)
{

    CFURLRef url = CFURLCreateFromFileSystemRepresentation(nullptr,
                                                           (const UInt8 *)_path.c_str(),
                                                           _path.length(),
                                                           false);
    static void *keys[] = {(void*)kQLThumbnailOptionIconModeKey};
    static void *values[] = {(void*)kCFBooleanTrue};
    static CFDictionaryRef dict = CFDictionaryCreate(0,
                                                     (const void**)keys,
                                                     (const void**)values, 1, 0, 0);
    NSImage *result = 0;
    if( CGImageRef thumbnail = QLThumbnailImageCreate(0, url, _px_size, dict) ) {
        result = [[NSImage alloc] initWithCGImage:thumbnail size:_px_size];
        CGImageRelease(thumbnail);
    }
    CFRelease(url);        
    return result;
}

static std::optional<std::vector<uint8_t>> ReadEntireFile(const std::string &_path, VFSHost &_host)
{
    VFSFilePtr vfs_file;
    
    if( _host.CreateFile(_path.c_str(), vfs_file, 0) < 0 )
        return std::nullopt;
    
    if( vfs_file->Open(VFSFlags::OF_Read) < 0)
        return std::nullopt;
    
    return vfs_file->ReadFile(); 
}

}
