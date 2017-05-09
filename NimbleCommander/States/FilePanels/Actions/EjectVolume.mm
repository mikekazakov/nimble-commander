#include <Utility/NativeFSManager.h>
#include "../PanelController.h"
#include "EjectVolume.h"

namespace nc::panel::actions {

bool EjectVolume::Predicate( PanelController *_target ) const
{
    return _target.isUniform &&
        _target.vfs->IsNativeFS() &&
        NativeFSManager::Instance().IsVolumeContainingPathEjectable( _target.currentDirectoryPath );
}

void EjectVolume::Perform( PanelController *_target, id _sender ) const
{
    auto &nfsm = NativeFSManager::Instance();
    if( _target.vfs->IsNativeFS() )
        if( nfsm.IsVolumeContainingPathEjectable(_target.currentDirectoryPath) )
            nfsm.EjectVolumeContainingPath(_target.currentDirectoryPath);
}

};
