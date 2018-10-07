#pragma once

#include <Foundation/Foundation.h>
#include <string>
#include <optional>

namespace nc::utility {

class DiskUtility
{
public: 
    NSDictionary *ListAPFSObjects();
    
};
    
class APFSTree
{
public:
    APFSTree( NSDictionary *_objects_list_from_disk_utility );

    /**
     * Returns BSD name if was found.
     */
    std::optional<std::string> FindContainerOfVolume( std::string_view _bsd_volume_name );
    
    /**
     * Returns BSD names if were found.
     * Volumes are returned in the order of their appearance in the dictionary, not sorting is 
     * applied.
     */    
    std::optional<std::vector<std::string>>
        FindVolumesOfContainer( std::string_view _bsd_container_name );

    /**
     * Returns BSD names if were found.
     */    
    std::optional<std::vector<std::string>>
        FindPhysicalStoresOfContainer( std::string_view _bsd_container_name );
        
private:
    static bool DoesContainerContainVolume(NSDictionary *_container,
                                           std::string_view _bsd_volume_name);
    static std::vector<std::string> VolumesOfContainer(NSDictionary *_container);
    static std::vector<std::string> StoresOfContainer(NSDictionary *_container);
    
    NSDictionary *m_Root;
    NSArray *m_Containers;
};
    
}
