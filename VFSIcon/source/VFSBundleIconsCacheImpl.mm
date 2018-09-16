// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFSIcon/VFSBundleIconsCacheImpl.h>
#include <Utility/ObjCpp.h>

namespace nc::vfsicon {
    
static NSImage *ProduceBundleIcon(const std::string &_path, VFSHost &_host);
static NSDictionary *ReadDictionary(const std::string &_path, VFSHost &_host);
static NSData *ToTempNSData(const std::optional<std::vector<uint8_t>> &_data);
static NSImage *ReadImageFromFile(const std::string &_path, VFSHost &_host);
static std::optional<std::vector<uint8_t>> ReadEntireFile(const std::string &_path, VFSHost &_host);
    
VFSBundleIconsCacheImpl::VFSBundleIconsCacheImpl()
{        
}
    
VFSBundleIconsCacheImpl::~VFSBundleIconsCacheImpl()
{        
}
        
NSImage *VFSBundleIconsCacheImpl::IconIfHas(const std::string &_file_path, VFSHost &_host)
{   
    auto key = MakeKey(_file_path, _host);
    
    {
        auto lock = std::lock_guard{m_Lock};
        if( m_Icons.count(key) )
            return m_Icons.at(key);
    }
            
    return nil;
}

NSImage *VFSBundleIconsCacheImpl::ProduceIcon(const std::string &_file_path, VFSHost &_host)
{
    auto key = MakeKey(_file_path, _host);
    
    {
        auto lock = std::lock_guard{m_Lock};
        if( m_Icons.count(key) )
            return m_Icons.at(key);
    }
    
    auto image = ProduceBundleIcon(_file_path, _host);
    
    {
        auto lock = std::lock_guard{m_Lock};
        m_Icons.insert(std::move(key), image);
    }
    
    return image; 
}    

std::string VFSBundleIconsCacheImpl::MakeKey(const std::string &_file_path, VFSHost &_host)
{
   return _host.MakePathVerbose(_file_path.c_str());        
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
   
static NSData *ToTempNSData(const std::optional<std::vector<uint8_t>> &_data)
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
    
static NSImage *ProduceBundleIcon(const std::string &_path, VFSHost &_host)
{
    const auto info_plist_path = boost::filesystem::path(_path) / "Contents/Info.plist";
    const auto plist = ReadDictionary(info_plist_path.native(), _host);
    if( !plist )
        return 0;
    
    auto icon_str = objc_cast<NSString>([plist objectForKey:@"CFBundleIconFile"]);
    if( !icon_str )
        return nil;
    if( !icon_str.fileSystemRepresentation )
        return nil;
    
    const auto img_path = boost::filesystem::path(_path) / 
                        "Contents/Resources/" / 
                        icon_str.fileSystemRepresentation;
    return ReadImageFromFile(img_path.native(), _host);
}
    
}
