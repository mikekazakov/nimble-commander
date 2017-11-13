// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

struct RevealInOppositePanel final : StateAction
{
    virtual bool Predicate( MainWindowFilePanelState *_target ) const;
    virtual void Perform( MainWindowFilePanelState *_target, id _sender ) const;
};

struct RevealInOppositePanelTab final : StateAction
{
    virtual bool Predicate( MainWindowFilePanelState *_target ) const;
    virtual void Perform( MainWindowFilePanelState *_target, id _sender ) const;
};

}
