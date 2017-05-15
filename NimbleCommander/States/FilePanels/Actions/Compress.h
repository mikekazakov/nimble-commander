#pragma once

#include "DefaultAction.h"

class VFSListingItem;

namespace nc::panel::actions {

struct CompressHere : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct CompressToOpposite : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

namespace context {

struct CompressHere : PanelAction
{
    CompressHere(const vector<VFSListingItem>&_items);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const vector<VFSListingItem> &m_Items;
};

struct CompressToOpposite : PanelAction
{
    CompressToOpposite(const vector<VFSListingItem>&_items);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const vector<VFSListingItem> &m_Items;
};

}

}
