// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Pasteboard.h"
#include <VFS/VFS.h>
#include <Utility/StringExtras.h>

namespace nc::panel {

bool PasteboardSupport::WriteFilesnamesPBoard(const std::vector<VFSListingItem> &_items, NSPasteboard *_pasteboard)
{
    if( !_pasteboard )
        return false;

    auto filepaths = [[NSMutableArray alloc] initWithCapacity:_items.size()];
    for( auto &i : _items )
        if( i.Host()->IsNativeFS() )
            if( auto path = [NSString stringWithUTF8StdString:i.Path()] )
                [filepaths addObject:path];

    if( filepaths.count == 0 )
        return false;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [_pasteboard clearContents];
    [_pasteboard declareTypes:@[NSFilenamesPboardType] owner:nil];
    return [_pasteboard setPropertyList:filepaths forType:NSFilenamesPboardType];
#pragma clang diagnostic pop
}

bool PasteboardSupport::WriteURLSPBoard(const std::vector<VFSListingItem> &_items, NSPasteboard *_pasteboard)
{
    if( !_pasteboard )
        return false;

    auto urls = [[NSMutableArray alloc] initWithCapacity:_items.size()];
    for( auto &i : _items )
        if( i.Host()->IsNativeFS() )
            if( auto path = [NSString stringWithUTF8StdString:i.Path()] )
                if( auto url = [NSURL fileURLWithPath:path] )
                    [urls addObject:url];

    [_pasteboard clearContents];
    [_pasteboard declareTypes:@[(__bridge NSString *)kUTTypeFileURL] owner:nil];
    return [_pasteboard writeObjects:urls];
}

} // namespace nc::panel
