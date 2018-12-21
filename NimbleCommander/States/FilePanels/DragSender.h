// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSDeclarations.h>
#include <Cocoa/Cocoa.h>
#include <functional>

@class PanelController;

namespace nc::panel {

class DragSender
{
public:
    using IconCallback = std::function<NSImage*(const VFSListingItem &_item)>;
    
    DragSender(PanelController *_panel, IconCallback _icon_callback); 
    ~DragSender();

    void Start(NSView *_from_view,
               NSEvent *_via_event,
               int _dragged_panel_item_sorted_index );

private:
    PanelController *m_Panel;
    IconCallback m_IconCallback;
};

}
