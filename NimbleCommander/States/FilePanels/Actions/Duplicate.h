#pragma once

#include "DefaultAction.h"

class VFSListingItem;

namespace nc::panel::actions {

struct Duplicate : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

namespace context {

struct Duplicate : PanelAction
{
    Duplicate(const vector<VFSListingItem> &_items);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const vector<VFSListingItem> &m_Items;
};

}

}
