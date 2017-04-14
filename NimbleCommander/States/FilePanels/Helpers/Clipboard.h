#pragma once

class VFSListingItem;
@class PanelController;

namespace panel {

struct ClipboardSupport {
static bool WriteFilesnamesPBoard( const vector<VFSListingItem>&_items, NSPasteboard *_pasteboard );
static bool WriteFilesnamesPBoard( PanelController *_panel, NSPasteboard *_pasteboard );
static bool WriteURLSPBoard( const vector<VFSListingItem>&_items, NSPasteboard *_pasteboard );
static bool WriteURLSPBoard( PanelController *_panel, NSPasteboard *_pasteboard );
};

}
