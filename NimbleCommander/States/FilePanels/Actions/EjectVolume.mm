// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFS.h>
#include "../PanelController.h"
#include "EjectVolume.h"

namespace nc::panel::actions {

EjectVolume::EjectVolume(utility::NativeFSManager &_native_fs_manager):
    m_NativeFSManager{_native_fs_manager}
{
}
    
bool EjectVolume::Predicate( PanelController *_target ) const
{
    return _target.isUniform &&
        _target.vfs->IsNativeFS() &&
        m_NativeFSManager.IsVolumeContainingPathEjectable( _target.currentDirectoryPath );
}

void EjectVolume::Perform( PanelController *_target, id _sender ) const
{
    if( _target.vfs->IsNativeFS() )
        if( m_NativeFSManager.IsVolumeContainingPathEjectable(_target.currentDirectoryPath) )
            m_NativeFSManager.EjectVolumeContainingPath(_target.currentDirectoryPath);
}

};
