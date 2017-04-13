#pragma once

@class PanelController;

namespace panel::actions {

// external dependency: AppDelegate.me.panelLayouts

struct ToggleLayout
{
    ToggleLayout( int _layout_index );
    
    bool Predicate( PanelController *_target );
    bool ValidateMenuItem( PanelController *_target, NSMenuItem *_item );
    void Perform( PanelController *_target, id _sender );
private:
    int m_Index;
};

};
