#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace panel::actions {

// external dependency: AppDelegate.me.panelLayouts

struct ToggleLayout : PanelAction
{
    ToggleLayout( int _layout_index );
    
    bool Predicate( PanelController *_target ) override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) override;
    void Perform( PanelController *_target, id _sender ) override;
    
private:
    int m_Index;
};

};
