// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../PanelController.h"
#include "../PanelViewLayoutSupport.h"
#include "ToggleLayout.h"

namespace nc::panel::actions {

ToggleLayout::ToggleLayout( int _layout_index ):
    m_Index(_layout_index)
{
}

bool ToggleLayout::Predicate( PanelController *_target ) const
{
    if( auto l = _target.layoutStorage.GetLayout(m_Index) )
        return !l->is_disabled();
    return false;
}

bool ToggleLayout::ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const
{
    _item.state = _target.layoutIndex == m_Index;
    return Predicate(_target);
}

void ToggleLayout::Perform( PanelController *_target, id _sender ) const
{
    [_target setLayoutIndex:m_Index];
}

}
