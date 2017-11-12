// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "DefaultAction.h"

namespace nc::panel::actions {

// dependency: NativeFSManager::Instance()

struct Delete final : PanelAction
{
    Delete( bool _permanently = false );
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    bool m_Permanently;
};

struct MoveToTrash final : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

namespace context {

struct DeletePermanently final : PanelAction
{
   DeletePermanently(const vector<VFSListingItem> &_items);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const vector<VFSListingItem> &m_Items;
    bool m_AllWriteable;
};

struct MoveToTrash final : PanelAction
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
