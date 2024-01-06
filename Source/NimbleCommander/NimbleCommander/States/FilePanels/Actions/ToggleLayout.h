// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace nc::panel::actions {

// external dependency: AppDelegate.me.panelLayouts

struct ToggleLayout final : PanelAction
{
    ToggleLayout( int _layout_index );
    
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
    
private:
    int m_Index;
};

};
