#pragma once

#include "DefaultAction.h"

namespace panel::actions {

// dependency: NativeFSManager::Instance()

struct Delete : PanelAction
{
    Delete( bool _permanently = false );
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    bool m_Permanently;
};

struct MoveToTrash : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

}
