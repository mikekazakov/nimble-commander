// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

@class PanelController;

namespace nc::panel {
    struct FindFilesSheetViewRequest;
}

namespace nc::panel::actions {

struct FindFiles final : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
private:
    void OnView(const FindFilesSheetViewRequest& _request) const;
};

};
