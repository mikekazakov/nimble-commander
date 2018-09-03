// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "QLVFSThumbnailsCacheImpl.h"
#include <Quartz/Quartz.h>

namespace nc::utility {

static NSImage *ProduceThumbnailForTempFile(const string &_path, CGSize _px_size);
static optional<vector<uint8_t>> ReadEntireFile(const string &_path, VFSHost &_host);
static NSDictionary *ReadDictionary(const std::string &_path, VFSHost &_host);
static NSData *ToTempNSData(const optional<vector<uint8_t>> &_data);
static NSImage *ReadImageFromFile(const std::string &_path, VFSHost &_host);
static NSImage *ProduceBundleIcon(const string &_path, VFSHost &_host);
    
QLVFSThumbnailsCacheImpl::QLVFSThumbnailsCacheImpl
    (const std::shared_ptr<BriefOnDiskStorage> &_temp_storage):
    m_TempStorage(_temp_storage)
{
}

QLVFSThumbnailsCacheImpl::~QLVFSThumbnailsCacheImpl()
{        
}
    
NSImage *QLVFSThumbnailsCacheImpl::ProduceFileThumbnail(const std::string &_file_path,
                                                        VFSHost &_host,
                                                        int _px_size)
{
    return ProduceThumbnail(_file_path,
                            path(_file_path).extension().native(),
                            _host,
                            CGSizeMake(double(_px_size), double(_px_size)));
}

NSImage *QLVFSThumbnailsCacheImpl::ProduceBundleThumbnail(const std::string &_file_path,
                                                          VFSHost &_host,
                                                          int _px_size)
{
    return ProduceBundleIcon(_file_path, _host);
}

NSImage *QLVFSThumbnailsCacheImpl::ProduceThumbnail(const string &_path,
                                                    const string &_ext,
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
    
static NSImage *ProduceThumbnailForTempFile(const string &_path, CGSize _px_size)
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

static optional<vector<uint8_t>> ReadEntireFile(const string &_path, VFSHost &_host)
{
    VFSFilePtr vfs_file;
    
    if( _host.CreateFile(_path.c_str(), vfs_file, 0) < 0 )
        return nullopt;
    
    if( vfs_file->Open(VFSFlags::OF_Read) < 0)
        return nullopt;
    
    return vfs_file->ReadFile(); 
}

static NSData *ToTempNSData(const optional<vector<uint8_t>> &_data)
{
    if( _data.has_value() == false )
        return nil;        
    return [NSData dataWithBytesNoCopy:(void*)_data->data()
                                length:_data->size()
                          freeWhenDone:false];
}
    
static NSDictionary *ReadDictionary(const std::string &_path, VFSHost &_host)
{
    const auto data = ReadEntireFile(_path, _host);
    if( data.has_value() == false )
        return nil;
    
    const auto objc_data = ToTempNSData(data);
    if( objc_data == nil )
        return nil;

    id dictionary = [NSPropertyListSerialization propertyListWithData:objc_data
                                                              options:NSPropertyListImmutable
                                                               format:nil
                                                                error:nil];
    return objc_cast<NSDictionary>(dictionary);
}
    
static NSImage *ReadImageFromFile(const std::string &_path, VFSHost &_host)
{
    const auto data = ReadEntireFile(_path, _host);
    if( data.has_value() == false )
        return nil;
    
    const auto objc_data = ToTempNSData(data);
    if( objc_data == nil )
        return nil;
    
    return [[NSImage alloc] initWithData:objc_data];
}
    
static NSImage *ProduceBundleIcon(const string &_path, VFSHost &_host)
{
    const auto info_plist_path = path(_path) / "Contents/Info.plist";
    const auto plist = ReadDictionary(info_plist_path.native(), _host);
    if(!plist)
        return 0;
    
    auto icon_str = objc_cast<NSString>([plist objectForKey:@"CFBundleIconFile"]);
    if( !icon_str )
        return nil;
    if( !icon_str.fileSystemRepresentation )
        return nil;
    
    const auto img_path = path(_path) / "Contents/Resources/" / icon_str.fileSystemRepresentation;
    return ReadImageFromFile(img_path.native(), _host);
}

}







    

    

//
//static NSImage *ProduceThumbnailForVFS_Cached(const string &_path, const string &_ext, const VFSHostPtr &_host, CGSize _sz)
//{
//    // for immutable vfs we can cache generated thumbnails for some time
//    pair<bool, NSImage *> thumbnail = {false, nil}; // found -> value
//    
//    if( _host->IsImmutableFS() )
//        thumbnail = QLVFSThumbnailsCache::Instance().Get(_path, _host);
//    
//    if( !thumbnail.first ) {
//        thumbnail.second = ProduceThumbnailForVFS(_path, _ext, _host, _sz);
//        if( _host->IsImmutableFS() )
//            QLVFSThumbnailsCache::Instance().Put(_path, _host, thumbnail.second);
//    }
//    
//    return thumbnail.second;
//}
//

//


//
//static NSImage *ProduceBundleThumbnailForVFS_Cached(const string &_path, const VFSHostPtr &_host)
//{
//    // for immutable vfs we can cache generated thumbnails for some time
//    pair<bool, NSImage*> thumbnail = {false, nil}; // found -> value
//    
//    if( _host->IsImmutableFS() )
//        thumbnail = QLVFSThumbnailsCache::Instance().Get(_path, _host);
//    
//    if( !thumbnail.first ) {
//        thumbnail.second = ProduceBundleThumbnailForVFS(_path, _host);
//        if( _host->IsImmutableFS() )
//            QLVFSThumbnailsCache::Instance().Put(_path, _host, thumbnail.second);
//    }
//    
//    return thumbnail.second;
//}
