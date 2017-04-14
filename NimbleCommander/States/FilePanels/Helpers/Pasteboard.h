#pragma once

class VFSListingItem;

namespace panel {

struct PasteboardSupport {

static bool WriteFilesnamesPBoard( const vector<VFSListingItem>&_items, NSPasteboard *_pasteboard );
static bool WriteURLSPBoard( const vector<VFSListingItem>&_items, NSPasteboard *_pasteboard );

};

}
