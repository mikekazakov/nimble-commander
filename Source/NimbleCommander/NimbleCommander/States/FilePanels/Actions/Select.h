// Copyright (C) 2017-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

struct SelectAll final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct DeselectAll final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct InvertSelection final : PanelAction {
    void Perform(PanelController *_target, id _sender) const override;
};

struct SelectAllByExtension final : PanelAction {
    SelectAllByExtension(bool _result_selection);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    bool m_ResultSelection;
};

// TODO: pass the config explicitly, stop lying
// TODO: pass analytics explicitly, stop lying
struct SelectAllByMask final : PanelAction {
    SelectAllByMask(bool _result_selection);
    void Perform(PanelController *_target, id _sender) const override;

private:
    bool m_ResultSelection;
};

}; // namespace nc::panel::actions
