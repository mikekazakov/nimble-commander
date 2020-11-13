// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::config {
class Config;
}

namespace nc::ops {
class Operation;
}

namespace nc::panel::actions {

class CopyBase
{
public:
    CopyBase(nc::config::Config &_config);

protected:
    void AddDeselectorIfNeeded(nc::ops::Operation &_with_operation,
                               PanelController *_to_target) const;

private:
    bool ShouldAutomaticallyDeselect() const;
    nc::config::Config &m_Config;
};

struct CopyTo final : StateAction, CopyBase {
    CopyTo(nc::config::Config &_config);
    virtual bool Predicate(MainWindowFilePanelState *_target) const;
    virtual void Perform(MainWindowFilePanelState *_target, id _sender) const;
};

struct CopyAs final : StateAction, CopyBase {
    CopyAs(nc::config::Config &_config);
    virtual bool Predicate(MainWindowFilePanelState *_target) const;
    virtual void Perform(MainWindowFilePanelState *_target, id _sender) const;
};

struct MoveTo final : StateAction {
    virtual bool Predicate(MainWindowFilePanelState *_target) const;
    virtual void Perform(MainWindowFilePanelState *_target, id _sender) const;
};

struct MoveAs final : StateAction {
    virtual bool Predicate(MainWindowFilePanelState *_target) const;
    virtual void Perform(MainWindowFilePanelState *_target, id _sender) const;
};

} // namespace nc::panel::actions
