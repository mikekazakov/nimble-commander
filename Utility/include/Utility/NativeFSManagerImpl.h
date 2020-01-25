// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "NativeFSManager.h"

namespace nc::utility {

class NativeFSManagerImpl : public NativeFSManager 
{
public:
    NativeFSManagerImpl();
    NativeFSManagerImpl(const NativeFSManagerImpl&) = delete;
    ~NativeFSManagerImpl();
    NativeFSManagerImpl& operator=(const NativeFSManagerImpl&) = delete;
    
    class VolumeLookup;
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
    void InsertNewVolume_Unlocked( const std::shared_ptr<NativeFileSystemInfo> &_volume );
    void PerformUnmounting(const Info &_volume);
    void PerformGenericUnmounting(const Info &_volume);    
    void PerformAPFSUnmounting(const Info &_volume);
    void SubscribeToWorkspaceNotifications();
    void UnsubscribeFromWorkspaceNotifications();

    struct Impl;
    std::unique_ptr<Impl> I;
};


}
