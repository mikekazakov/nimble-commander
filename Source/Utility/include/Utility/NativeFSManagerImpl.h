// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#ifndef __OBJC__
#error this file must be compiled as ObjC++
#endif

#include "NativeFSManager.h"
#include "NativeFSManagerVolumeLookup.h"
#include "DiskUtility.h"
#include "FirmlinksMappingParser.h"

#include <mutex>

@class NCUtilityNativeFSManagerNotificationsReceiver;

namespace nc::utility {

class NativeFSManagerImpl : public NativeFSManager
{
public:
    NativeFSManagerImpl();
    NativeFSManagerImpl(const NativeFSManagerImpl &) = delete;
    ~NativeFSManagerImpl();
    NativeFSManagerImpl &operator=(const NativeFSManagerImpl &) = delete;

    using NativeFSManager::Info;

    std::vector<Info> Volumes() const override;

    Info VolumeFromFD(int _fd) const noexcept override;

    Info VolumeFromPath(std::string_view _path) const noexcept override;

    Info VolumeFromPathFast(std::string_view _path) const noexcept override;

    Info VolumeFromMountPoint(std::string_view _mount_point) const noexcept override;

    void UpdateSpaceInformation(const Info &_volume) override;

    void EjectVolumeContainingPath(const std::string &_path) override;

    bool IsVolumeContainingPathEjectable(const std::string &_path) override;

private:
    void OnDidMount(const std::string &_on_path);
    void OnWillUnmount(const std::string &_on_path);
    void OnDidUnmount(const std::string &_on_path);
    void OnDidRename(const std::string &_old_path, const std::string &_new_path);
    void InsertNewVolume_Unlocked(const std::shared_ptr<NativeFileSystemInfo> &_volume);
    Info VolumeFromMountPoint_Unlocked(std::string_view _mount_point) const noexcept;
    Info VolumeFromBSDName_Unlocked(std::string_view _bsd_name) const noexcept;
    static void PerformUnmounting(const Info &_volume);
    static void PerformGenericUnmounting(const Info &_volume);
    static void PerformAPFSUnmounting(const Info &_volume);
    void SubscribeToWorkspaceNotifications();
    void UnsubscribeFromWorkspaceNotifications();
    void InjectRootFirmlinks(const APFSTree &_tree);

    mutable std::mutex m_Lock;
    std::vector<std::shared_ptr<NativeFileSystemInfo>> m_Volumes;
    NativeFSManagerVolumeLookup m_VolumeLookup;
    std::optional<APFSTree> m_StartupAPFSTree;
    std::vector<FirmlinksMappingParser::Firmlink> m_RootFirmlinks;
    NCUtilityNativeFSManagerNotificationsReceiver *m_NotificationsReceiver;
};

} // namespace nc::utility
