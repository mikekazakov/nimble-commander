#pragma once

#include <VFS/VFS.h>
#include "DefaultAction.h"

namespace nc::panel::actions {

struct OpenFileWithSubmenu : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
};

struct AlwaysOpenFileWithSubmenu : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
};

struct OpenFocusedFileWithDefaultHandler : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct OpenFilesWithDefaultHandler : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

namespace context {

struct OpenFileWithDefaultHandler : PanelAction
{
    OpenFileWithDefaultHandler(const vector<VFSListingItem>& _items);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const vector<VFSListingItem>& m_Items;
};

}

}
