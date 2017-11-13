// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

struct CopyTo final : StateAction
{
    virtual bool Predicate( MainWindowFilePanelState *_target ) const;
    virtual void Perform( MainWindowFilePanelState *_target, id _sender ) const;
};

struct CopyAs final : StateAction
{
    virtual bool Predicate( MainWindowFilePanelState *_target ) const;
    virtual void Perform( MainWindowFilePanelState *_target, id _sender ) const;
};

struct MoveTo final : StateAction
{
    virtual bool Predicate( MainWindowFilePanelState *_target ) const;
    virtual void Perform( MainWindowFilePanelState *_target, id _sender ) const;
};

struct MoveAs final : StateAction
{
    virtual bool Predicate( MainWindowFilePanelState *_target ) const;
    virtual void Perform( MainWindowFilePanelState *_target, id _sender ) const;
};

}
