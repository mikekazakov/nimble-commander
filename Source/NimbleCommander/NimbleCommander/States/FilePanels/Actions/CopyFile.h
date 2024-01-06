// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc {

namespace bootstrap {
class ActivationManager;
}
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
    void AddDeselectorIfNeeded(nc::ops::Operation &_with_operation,
                               PanelController *_to_target) const;

private:
    bool ShouldAutomaticallyDeselect() const;
    nc::config::Config &m_Config;
};

class CopyTo final : public StateAction, CopyBase {
public:
    CopyTo(nc::config::Config &_config, nc::bootstrap::ActivationManager &_ac);
    bool Predicate(MainWindowFilePanelState *_target) const override;
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
private:
    nc::bootstrap::ActivationManager &m_ActivationManager;
};

class CopyAs final : public StateAction, CopyBase {
public:
    CopyAs(nc::config::Config &_config, nc::bootstrap::ActivationManager &_ac);
    bool Predicate(MainWindowFilePanelState *_target) const override;
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
private:
    nc::bootstrap::ActivationManager &m_ActivationManager;
};

class MoveTo final : public StateAction {
public:
    MoveTo(nc::bootstrap::ActivationManager &_ac);
    bool Predicate(MainWindowFilePanelState *_target) const override;
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
private:
    nc::bootstrap::ActivationManager &m_ActivationManager;
};

class MoveAs final : public StateAction {
public:
    MoveAs(nc::bootstrap::ActivationManager &_ac);
    bool Predicate(MainWindowFilePanelState *_target) const override;
    void Perform(MainWindowFilePanelState *_target, id _sender) const override;
public:
    nc::bootstrap::ActivationManager &m_ActivationManager;
};

} // namespace nc::panel::actions
