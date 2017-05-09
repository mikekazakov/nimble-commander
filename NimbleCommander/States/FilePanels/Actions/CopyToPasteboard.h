#pragma once

#include "DefaultAction.h"

class VFSListingItem;

namespace nc::panel::actions {

struct CopyToPasteboard : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
protected:
    void PerformWithItems( const vector<VFSListingItem> &_items ) const;
};

namespace context {

struct CopyToPasteboard : panel::actions::CopyToPasteboard
{
    CopyToPasteboard(const vector<VFSListingItem> &_items);
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;    
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const vector<VFSListingItem> &m_Items;
};

}

}
