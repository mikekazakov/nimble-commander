// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

@class PanelController;
@class NCViewerView;
@class NCViewerViewController;

namespace nc::bootstrap {
class ActivationManager;
}

namespace nc::panel {
struct FindFilesSheetViewRequest;
}

namespace nc::panel::actions {

struct FindFiles final : PanelAction {
    FindFiles(std::function<NCViewerView *(NSRect)> _make_viewer,
              std::function<NCViewerViewController *()> _make_controller,
              nc::bootstrap::ActivationManager &_activation_manager);
    bool Predicate(PanelController *_target) const override;
    void Perform(PanelController *_target, id _sender) const override;

private:
    void OnView(const FindFilesSheetViewRequest &_request) const;
    std::function<NCViewerView *(NSRect)> m_MakeViewer;
    std::function<NCViewerViewController *()> m_MakeController;
    nc::bootstrap::ActivationManager &m_ActivationManager;
};

};
