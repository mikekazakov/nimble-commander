#pragma once

@class PanelController;

namespace panel::actions {

// has en external dependency: AppDelegate.me.externalEditorsStorage
struct OpenWithExternalEditor
{
    static bool Predicate( PanelController *_target );
    static bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    static void Perform( PanelController *_target, id _sender );
};

};
