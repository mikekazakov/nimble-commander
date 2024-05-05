// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc {

namespace config {
class Config;
}
namespace ops {
class Operation;
}
} // namespace nc

namespace nc::panel::actions {

class CopyBase
{
public:
    CopyBase(nc::config::Config &_config);

protected:
    void AddDeselectorIfNeeded(nc::ops::Operation &_with_operation, PanelController *_to_target) const;

private:
    bool ShouldAutomaticallyDeselect() const;
    nc::config::Config &m_Config;
};

class CopyTo final : public StateAction, CopyBase
{
public:
    CopyTo(nc::config::Config &_config);
    bool Predicate(MainWindowFilePanelState *_target) const override;
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

class CopyAs final : public StateAction, CopyBase
{
public:
    CopyAs(nc::config::Config &_config);
    bool Predicate(MainWindowFilePanelState *_target) const override;
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

class MoveTo final : public StateAction
{
public:
    bool Predicate(MainWindowFilePanelState *_target) const override;
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

class MoveAs final : public StateAction
{
public:
    bool Predicate(MainWindowFilePanelState *_target) const override;
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
};

} // namespace nc::panel::actions
