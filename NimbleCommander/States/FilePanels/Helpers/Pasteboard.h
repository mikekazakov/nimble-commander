#pragma once

#include <VFS/VFS.h>

namespace nc::panel {

struct PasteboardSupport {

static bool WriteFilesnamesPBoard( const vector<VFSListingItem>&_items, NSPasteboard *_pasteboard );
static bool WriteURLSPBoard( const vector<VFSListingItem>&_items, NSPasteboard *_pasteboard );

};

}
