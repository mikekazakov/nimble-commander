// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "DefaultAction.h"

namespace nc::panel::actions {

struct OpenFileWithSubmenu final : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
};

struct AlwaysOpenFileWithSubmenu final : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
};

struct OpenFocusedFileWithDefaultHandler final : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenFilesWithDefaultHandler final : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

namespace context {

struct OpenFileWithDefaultHandler final : PanelAction
{
    OpenFileWithDefaultHandler(const std::vector<VFSListingItem>& _items);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const std::vector<VFSListingItem>& m_Items;
};

}

}
