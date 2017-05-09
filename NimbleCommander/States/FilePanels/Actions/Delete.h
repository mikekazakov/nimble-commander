#pragma once

#include "DefaultAction.h"

class VFSListingItem;

namespace nc::panel::actions {

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

namespace context {

struct DeletePermanently : PanelAction
{
   DeletePermanently(const vector<VFSListingItem> &_items);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const vector<VFSListingItem> &m_Items;
    bool m_AllWriteable;
};

struct MoveToTrash : PanelAction
{
    MoveToTrash(const vector<VFSListingItem> &_items);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const vector<VFSListingItem> &m_Items;
    bool m_AllAreNative;
};

}

}
