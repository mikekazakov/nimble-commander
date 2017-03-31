#pragma once

@class PanelController;

namespace panel::actions {

// external dependencies:
// config: filePanel.spotlight.format;
// config: filePanel.spotlight.maxCount;

struct SpotlightSearch
{
    static bool Predicate( PanelController *_target );
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

};
