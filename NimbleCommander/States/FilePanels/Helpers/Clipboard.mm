#include "Clipboard.h"
#include "../PanelController.h"

namespace panel {

bool ClipboardSupport::WriteFilesnamesPBoard(const vector<VFSListingItem> &_items,
                                             NSPasteboard *_pasteboard )
{
    if( !_pasteboard )
        return false;

    auto filepaths = [[NSMutableArray alloc] initWithCapacity:_items.size()];
    for( auto &i: _items  )
        if( i.Host()->IsNativeFS() )
            if( auto path = [NSString stringWithUTF8StdString:i.Path()] )
                [filepaths addObject:path];
    
    if( filepaths.count == 0 )
        return false;
    
    [_pasteboard clearContents];
    [_pasteboard declareTypes:@[NSFilenamesPboardType]
                        owner:nil];
    return [_pasteboard setPropertyList:filepaths
                                forType:NSFilenamesPboardType];
}

bool ClipboardSupport::WriteFilesnamesPBoard( PanelController *_panel, NSPasteboard *_pasteboard )
{
    if( !_panel || !_pasteboard )
        return false;

    return WriteFilesnamesPBoard(_panel.selectedEntriesOrFocusedEntry, _pasteboard);
}

bool ClipboardSupport::WriteURLSPBoard(const vector<VFSListingItem> &_items,
                                       NSPasteboard *_pasteboard )
{
    if( !_pasteboard )
        return false;

    auto urls = [[NSMutableArray alloc] initWithCapacity:_items.size()];
    for( auto &i: _items  )
        if( i.Host()->IsNativeFS() )
            if( auto path = [NSString stringWithUTF8StdString:i.Path()] )
                if( auto url = [NSURL fileURLWithPath:path])
                    [urls addObject:url];

    [_pasteboard clearContents];
    [_pasteboard declareTypes:@[(__bridge NSString *)kUTTypeFileURL]
                        owner:nil];
    return [_pasteboard writeObjects:urls];
}

bool ClipboardSupport::WriteURLSPBoard( PanelController *_panel, NSPasteboard *_pasteboard )
{
    if( !_panel || !_pasteboard )
        return false;

    return WriteURLSPBoard(_panel.selectedEntriesOrFocusedEntry, _pasteboard);
}


}
