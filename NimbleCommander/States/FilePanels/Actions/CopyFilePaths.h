// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

struct CopyFileName final : PanelAction
{
    bool Predicate( PanelController *_source ) const override;
    void Perform( PanelController *_source, id _sender ) const override;
};

struct CopyFilePath final : PanelAction
{
    bool Predicate( PanelController *_source ) const override;
    void Perform( PanelController *_source, id _sender ) const override;
};
    
}
