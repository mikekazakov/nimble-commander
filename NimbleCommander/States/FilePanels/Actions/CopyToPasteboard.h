// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "DefaultAction.h"

namespace nc::panel::actions {

struct CopyToPasteboard : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
protected:
    void PerformWithItems( const std::vector<VFSListingItem> &_items ) const;
};

namespace context {

struct CopyToPasteboard final : panel::actions::CopyToPasteboard
{
    CopyToPasteboard(const std::vector<VFSListingItem> &_items);
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;    
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const std::vector<VFSListingItem> &m_Items;
};

}

}
