// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "DefaultAction.h"

namespace nc::panel::actions {

struct Duplicate final : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

namespace context {

struct Duplicate final : PanelAction
{
    Duplicate(const std::vector<VFSListingItem> &_items);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const std::vector<VFSListingItem> &m_Items;
};

}

}
