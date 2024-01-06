// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel {
    class FileOpener;
}

namespace nc::panel::actions {

// has en external dependency: AppDelegate.me.externalEditorsStorage
struct OpenWithExternalEditor final : PanelAction
{
    OpenWithExternalEditor(FileOpener &_file_opener);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    FileOpener &m_FileOpener;
};

};
