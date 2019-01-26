// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

@class PanelController;
@class BigFileView;
@class InternalViewerController;

namespace nc::panel {
    struct FindFilesSheetViewRequest;
}

namespace nc::panel::actions {

struct FindFiles final : PanelAction
{
    FindFiles( std::function<BigFileView*(NSRect)> _make_viewer,
               std::function<InternalViewerController*()> _make_controller );
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    void OnView(const FindFilesSheetViewRequest& _request) const;
    std::function<BigFileView*(NSRect)> m_MakeViewer;
    std::function<InternalViewerController*()> m_MakeController;
};

};
