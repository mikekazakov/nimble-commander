// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSDeclarations.h>
#include <VFS/Native.h>
#include <Cocoa/Cocoa.h>
#include <functional>

@class PanelController;

namespace nc::panel {

namespace data {
class Model;
}

class DragSender
{
public:
    using IconCallback = std::function<NSImage *(const VFSListingItem &_item)>;

    DragSender(PanelController *_panel, IconCallback _icon_callback, nc::vfs::NativeHost &_native_vfs);
    ~DragSender();

    void Start(NSView *_from_view, NSEvent *_via_event, int _dragged_panel_item_sorted_index);

    struct Impl {
        static std::vector<VFSListingItem> ComposeItemsForDragging(int _sorted_pos, const data::Model &_data);
    };

private:
    PanelController *m_Panel;
    IconCallback m_IconCallback;
    nc::vfs::NativeHost &m_NativeHost;
};

} // namespace nc::panel
