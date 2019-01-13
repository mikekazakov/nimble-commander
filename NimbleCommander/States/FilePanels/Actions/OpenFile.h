// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "DefaultAction.h"

@class NCPanelOpenWithMenuDelegate;

namespace nc::panel {
    class FileOpener;
}

namespace nc::panel::actions {

struct OpenFileWithSubmenu final : PanelAction
{
    OpenFileWithSubmenu(NCPanelOpenWithMenuDelegate *_menu_delegate);
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
private:
    NCPanelOpenWithMenuDelegate *m_MenuDelegate;
};

struct AlwaysOpenFileWithSubmenu final : PanelAction
{
    AlwaysOpenFileWithSubmenu(NCPanelOpenWithMenuDelegate *_menu_delegate);
    bool Predicate( PanelController *_target ) const override;
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item ) const override;
private:
    NCPanelOpenWithMenuDelegate *m_MenuDelegate;
};

struct OpenFilesWithDefaultHandler final : PanelAction
{
    OpenFilesWithDefaultHandler(FileOpener &_file_opener);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    FileOpener &m_FileOpener;
};

namespace context {

struct OpenFileWithDefaultHandler final : PanelAction
{
    OpenFileWithDefaultHandler(const std::vector<VFSListingItem>& _items,
                               FileOpener &_file_opener);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    const std::vector<VFSListingItem>& m_Items;
    FileOpener &m_FileOpener;
};

}

}
