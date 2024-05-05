// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::vfs {
class NativeHost;
}

namespace nc::panel::actions {

// extract additional state from NSPasteboard.generalPasteboard

struct PasteFromPasteboard final : PanelAction {
    PasteFromPasteboard(nc::vfs::NativeHost &_native_host);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    nc::vfs::NativeHost &m_NativeHost;
};

struct MoveFromPasteboard final : PanelAction {
    MoveFromPasteboard(nc::vfs::NativeHost &_native_host);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    nc::vfs::NativeHost &m_NativeHost;
};

}; // namespace nc::panel::actions
