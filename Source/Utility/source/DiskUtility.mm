// Copyright (C) 2018-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DiskUtility.h"
#include "ObjCpp.h"
#include <algorithm>
#include <boost/process.hpp>
#include <iostream>

static const auto g_APFSListCommand = "/usr/sbin/diskutil apfs list -plist";

namespace nc::utility {

static std::string Execute(const std::string &_command);
static std::string_view RoleToDiskUtilRepr(APFSTree::Role _role) noexcept;

NSDictionary *DiskUtility::ListAPFSObjects()
{
    const auto plist = Execute(g_APFSListCommand);

    if( plist.empty() )
        return nil;

    return DiskUtilityOutputToDictionary(plist);
}

APFSTree::APFSTree(NSDictionary *_objects_list_from_disk_utility) : m_Root(_objects_list_from_disk_utility)
{
    if( m_Root == nil )
        throw std::invalid_argument("APFSTree: object list can't be nil");
    m_Containers = objc_cast<NSArray>(m_Root[@"Containers"]);
    if( m_Containers == nil )
        throw std::invalid_argument("APFSTree: invalid objects dictionary");
}

std::vector<std::string> APFSTree::ContainersNames() const
{
    std::vector<std::string> names;

    for( const id container in m_Containers ) {
        const auto dict = objc_cast<NSDictionary>(container);
        if( dict == nil )
            continue;

        const auto reference = objc_cast<NSString>(dict[@"ContainerReference"]);
        if( reference == nil )
            continue;

        names.emplace_back(reference.UTF8String);
    }

    return names;
}

std::optional<std::string> APFSTree::FindContainerOfVolume(std::string_view _bsd_volume_name) const
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

std::optional<std::vector<std::string>> APFSTree::FindVolumesOfContainer(std::string_view _container_name) const
{
    if( _container_name.empty() )
        return {};

    for( const id container in m_Containers ) {
        const auto dict = objc_cast<NSDictionary>(container);
        if( dict == nil )
            continue;

        const auto reference = objc_cast<NSString>(dict[@"ContainerReference"]);
        if( reference == nil )
            continue;

        if( _container_name == reference.UTF8String )
            return VolumesOfContainer(dict);
    }

    return {};
}

std::optional<std::vector<std::string>> APFSTree::FindPhysicalStoresOfContainer(std::string_view _container_name) const
{
    if( _container_name.empty() )
        return {};

    for( const id container in m_Containers ) {
        const auto dict = objc_cast<NSDictionary>(container);
        if( dict == nil )
            continue;

        const auto reference = objc_cast<NSString>(dict[@"ContainerReference"]);
        if( reference == nil )
            continue;

        if( _container_name == reference.UTF8String )
            return StoresOfContainer(dict);
    }

    return {};
}

bool APFSTree::DoesContainerContainVolume(NSDictionary *_container, std::string_view _bsd_volume_name)
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

std::optional<std::vector<std::string>> APFSTree::FindVolumesInContainerWithRole(std::string_view _container_name,
                                                                                 Role _role) const
{
    if( _container_name.empty() )
        return {};

    for( const id container in m_Containers ) {
        const auto dict = objc_cast<NSDictionary>(container);
        if( dict == nil )
            continue;

        const auto reference = objc_cast<NSString>(dict[@"ContainerReference"]);
        if( reference == nil )
            continue;

        if( _container_name == reference.UTF8String )
            return VolumesOfContainerWithRole(dict, _role);
    }

    return {};
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

std::vector<std::string> APFSTree::VolumesOfContainerWithRole(NSDictionary *_container, Role _role)
{
    if( objc_cast<NSDictionary>(_container) == nil )
        return {};

    const auto volumes = objc_cast<NSArray>(_container[@"Volumes"]);
    if( volumes == nil )
        return {};

    std::vector<std::string> volumes_bsd_names;
    for( const id volume in volumes ) {
        if( const auto volume_dict = objc_cast<NSDictionary>(volume) ) {
            const auto identifier = objc_cast<NSString>(volume_dict[@"DeviceIdentifier"]);
            if( identifier == nil ) {
                continue;
            }

            const std::string bsd_id = identifier.UTF8String;

            if( const auto roles = objc_cast<NSArray>(volume_dict[@"Roles"]) ) {
                if( _role == Role::None ) {
                    if( roles.count == 0 ) {
                        volumes_bsd_names.emplace_back(bsd_id);
                    }
                }
                else {
                    for( const id role in roles ) {
                        if( const auto role_str = objc_cast<NSString>(role) ) {
                            const auto utf8 = role_str.UTF8String;
                            if( RoleToDiskUtilRepr(_role) == utf8 ) {
                                volumes_bsd_names.emplace_back(bsd_id);
                            }
                        }
                    }
                }
            }
        }
    }

    std::ranges::sort(volumes_bsd_names);
    volumes_bsd_names.erase(std::ranges::unique(volumes_bsd_names).begin(), volumes_bsd_names.end());
    return volumes_bsd_names;
}

NSDictionary *DiskUtility::DiskUtilityOutputToDictionary(std::string_view _text)
{
    const auto data = [[NSData alloc] initWithBytesNoCopy:const_cast<void *>(static_cast<const void *>(_text.data()))
                                                   length:_text.length()
                                             freeWhenDone:false];

    NSError *error = nil;
    const id root = [NSPropertyListSerialization propertyListWithData:data
                                                              options:NSPropertyListImmutable
                                                               format:nil
                                                                error:&error];

    return objc_cast<NSDictionary>(root);
}

static std::string Execute(const std::string &_command)
{
    using namespace boost::process;

    ipstream pipe_stream;
    child c(_command, std_out > pipe_stream);

    std::string buffer;
    std::string line;
    while( c.running() && pipe_stream ) {
        while( std::getline(pipe_stream, line) && !line.empty() ) {
            buffer += line;
            buffer += "\n";
        }
    }

    c.wait();
    return buffer;
}

static std::string_view RoleToDiskUtilRepr(APFSTree::Role _role) noexcept
{
    static const std::string_view none;
    static const std::string_view system = "System";
    static const std::string_view user = "User";
    static const std::string_view recovery = "Recovery";
    static const std::string_view vm = "VM";
    static const std::string_view preboot = "Preboot";
    static const std::string_view installer = "Installer";
    static const std::string_view data = "Data";
    static const std::string_view baseband = "Baseband";
    using _ = APFSTree::Role;
    switch( _role ) {
        case _::System:
            return system;
        case _::User:
            return user;
        case _::Recovery:
            return recovery;
        case _::VM:
            return vm;
        case _::Preboot:
            return preboot;
        case _::Installer:
            return installer;
        case _::Data:
            return data;
        case _::Baseband:
            return baseband;
        default:
            return none;
    }
}

} // namespace nc::utility
