// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@class PanelController;

namespace nc::panel {

class DragSender
{
public:
    DragSender( PanelController *_panel );
    ~DragSender();

    void Start(NSView *_from_view,
               NSEvent *_via_event,
               int _dragged_panel_item_sorted_index );

    void SetIconCallback( function<NSImage*(int _item_index)> _callback);

private:
    PanelController *m_Panel;
    function<NSImage*(int _item_index)> m_IconCallback;
};

}
