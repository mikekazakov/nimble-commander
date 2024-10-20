// Copyright (C) 2018-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Foundation/Foundation.h>
#include <string>
#include <optional>

namespace nc::utility {

class DiskUtility
{
public:
    static NSDictionary *ListAPFSObjects();

    static NSDictionary *DiskUtilityOutputToDictionary(std::string_view _text);
};

// RTFM: https://developer.apple.com/support/downloads/Apple-File-System-Reference.pdf
class APFSTree
{
public:
    APFSTree(NSDictionary *_objects_list_from_disk_utility);

    enum class Role {
        None = 0x0000,
        System = 0x0001,
        User = 0x0002,
        Recovery = 0x0004,
        VM = 0x0008,
        Preboot = 0x0010,
        Installer = 0x0020,
        Data = 0x0040,
        Baseband = 0x0080
    };

    /**
     * Returns an unordered list of APFS containers.
     */
    std::vector<std::string> ContainersNames() const;

    /**
     * Returns BSD name if was found.
     */
    std::optional<std::string> FindContainerOfVolume(std::string_view _bsd_volume_name) const;

    /**
     * Returns BSD names if were found.
     * Volumes are returned in the order of their appearance in the dictionary, not sorting is
     * applied.
     */
    std::optional<std::vector<std::string>> FindVolumesOfContainer(std::string_view _container_name) const;

    /**
     * Returns BSD names if were found.
     */
    std::optional<std::vector<std::string>> FindPhysicalStoresOfContainer(std::string_view _container_name) const;

    /**
     * Returns BSD names if were found.
     */
    std::optional<std::vector<std::string>> FindVolumesInContainerWithRole(std::string_view _container_name,
                                                                           Role _role) const;

private:
    static bool DoesContainerContainVolume(NSDictionary *_container, std::string_view _bsd_volume_name);
    static std::vector<std::string> VolumesOfContainer(NSDictionary *_container);
    static std::vector<std::string> StoresOfContainer(NSDictionary *_container);
    static std::vector<std::string> VolumesOfContainerWithRole(NSDictionary *_container, Role _role);

    NSDictionary *m_Root;
    NSArray *m_Containers;
};

} // namespace nc::utility
