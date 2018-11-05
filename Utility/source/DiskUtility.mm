#include "DiskUtility.h"
#include <boost/process.hpp>
#include <iostream>
#include "SystemInformation.h"
#include "ObjCpp.h"

static const auto g_APFSListCommand = "/usr/sbin/diskutil apfs list -plist"; 

namespace nc::utility {

static NSDictionary *DictionaryFromString(std::string_view _str);
static std::string Execute(const std::string &_command); 

NSDictionary *DiskUtility::ListAPFSObjects()
{
    if( GetOSXVersion() < OSXVersion::OSX_12 )
        return nil;

    const auto plist = Execute(g_APFSListCommand);
    
    if( plist.empty() )
        return nil;
    
    return DictionaryFromString(plist);
}

APFSTree::APFSTree( NSDictionary *_objects_list_from_disk_utility ) :
    m_Root(_objects_list_from_disk_utility)
{
    if( m_Root == nil )
        throw std::invalid_argument("APFSTree: object list can't be nil");
    m_Containers = objc_cast<NSArray>(m_Root[@"Containers"]);
    if( m_Containers == nil )
        throw std::invalid_argument("APFSTree: invalid objects dictionary");
}

std::optional<std::string> APFSTree::FindContainerOfVolume( std::string_view _bsd_volume_name )
{
    if( _bsd_volume_name.empty() )
        return {};
    
    for( const id container in m_Containers ) {
        const auto dict = objc_cast<NSDictionary>(container);
        if( dict == nil )
            continue;
        
        if( DoesContainerContainVolume(dict, _bsd_volume_name) ) {
            if( const auto reference = objc_cast<NSString>(dict[@"ContainerReference"]) ) {
                return std::make_optional(reference.UTF8String);
            }
            else {
                // broken dictionary?
                return {};
            }
        }
    }    
    
    return {};
}
    
std::optional<std::vector<std::string>>
    APFSTree::FindVolumesOfContainer( std::string_view _bsd_container_name )
{
    if( _bsd_container_name.empty() )
        return {};
    
    for( const id container in m_Containers ) {
        const auto dict = objc_cast<NSDictionary>(container);
        if( dict == nil )
            continue;

        const auto reference = objc_cast<NSString>(dict[@"ContainerReference"]);
        if( reference == nil )
            continue;
        
        if( _bsd_container_name == reference.UTF8String )
            return VolumesOfContainer(dict);
    }

    return {};
}
    
std::optional<std::vector<std::string>>
    APFSTree::FindPhysicalStoresOfContainer( std::string_view _bsd_container_name )
{
    if( _bsd_container_name.empty() )
        return {};
    
    for( const id container in m_Containers ) {
        const auto dict = objc_cast<NSDictionary>(container);
        if( dict == nil )
            continue;
        
        const auto reference = objc_cast<NSString>(dict[@"ContainerReference"]);
        if( reference == nil )
            continue;
        
        if( _bsd_container_name == reference.UTF8String )
            return StoresOfContainer(dict);
    }
    
    return {};        
}

bool APFSTree::DoesContainerContainVolume(NSDictionary *_container,
                                          std::string_view _bsd_volume_name)
{
    if( _bsd_volume_name.empty() || objc_cast<NSDictionary>(_container) == nil )
        return false;
    
    const auto volumes = objc_cast<NSArray>(_container[@"Volumes"]);
    if( volumes == nil )
        return false;
    
    for( const id volume in volumes ) {
        if( const auto volume_dict = objc_cast<NSDictionary>(volume) ) {
            if( const auto identifier = objc_cast<NSString>(volume_dict[@"DeviceIdentifier"]) ) {
                if( _bsd_volume_name == identifier.UTF8String ) {
                    return true;
                }
            }
        }
    } 
    return false;
}

std::vector<std::string> APFSTree::VolumesOfContainer(NSDictionary *_container)
{
    if( objc_cast<NSDictionary>(_container) == nil )
        return {};
    
    const auto volumes = objc_cast<NSArray>(_container[@"Volumes"]);
    if( volumes == nil )
        return {};
    
    std::vector<std::string> volumes_bsd_names;
    for( const id volume in volumes ) {
        if( const auto volume_dict = objc_cast<NSDictionary>(volume) ) {
            if( const auto identifier = objc_cast<NSString>(volume_dict[@"DeviceIdentifier"]) ) {
                volumes_bsd_names.emplace_back(identifier.UTF8String);
            }
        }
    }
    return volumes_bsd_names;
}
    
std::vector<std::string> APFSTree::StoresOfContainer(NSDictionary *_container)
{
    if( objc_cast<NSDictionary>(_container) == nil )
        return {};    

    const auto stores = objc_cast<NSArray>(_container[@"PhysicalStores"]);
    if( stores == nil )
        return {};
    
    std::vector<std::string> stores_bsd_names;
    for( const id store in stores ) {
        if( const auto store_dict = objc_cast<NSDictionary>(store) ) {
            if( const auto identifier = objc_cast<NSString>(store_dict[@"DeviceIdentifier"]) ) {
                stores_bsd_names.emplace_back(identifier.UTF8String);
            }
        }
    }
    return stores_bsd_names;    
}

static NSDictionary *DictionaryFromString(std::string_view _str)
{
    const auto data = [[NSData alloc] initWithBytesNoCopy:(void*)_str.data()
                                                   length:_str.length()
                                             freeWhenDone:false];
    
    const id root = [NSPropertyListSerialization propertyListWithData:data
                                                              options:NSPropertyListImmutable
                                                               format:nil
                                                                error:nil];

    return objc_cast<NSDictionary>(root);
}
    
static std::string Execute(const std::string &_command)
{
    using namespace boost::process;
    
    ipstream pipe_stream;
    child c(_command, std_out > pipe_stream);
    
    std::string buffer;
    std::string line;
    while( c.running() && pipe_stream && std::getline(pipe_stream, line) && !line.empty() ) {
        buffer += line;
        buffer += "\n";
    }
        
    c.wait(); 
    return buffer;
}
    
}
