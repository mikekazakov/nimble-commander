// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"
#include <Utility/NativeFSManager.h>

namespace nc::panel::actions {

struct EjectVolume final : PanelAction
{
    EjectVolume(utility::NativeFSManager &_native_fs_manager);
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    utility::NativeFSManager &m_NativeFSManager;
};

};
