#include <Utility/NativeFSManager.h>
#include "../PanelController.h"
#include "EjectVolume.h"

namespace panel::actions {

bool EjectVolume::Predicate( PanelController *_target )
{
    return _target.isUniform &&
        _target.vfs->IsNativeFS() &&
        NativeFSManager::Instance().IsVolumeContainingPathEjectable( _target.currentDirectoryPath );
}

bool EjectVolume::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )
{
    return Predicate( _target );
}

void EjectVolume::Perform( PanelController *_target, id _sender )
{
    auto &nfsm = NativeFSManager::Instance();
    if( _target.vfs->IsNativeFS() )
        if( nfsm.IsVolumeContainingPathEjectable(_target.currentDirectoryPath) )
            nfsm.EjectVolumeContainingPath(_target.currentDirectoryPath);
}

};
