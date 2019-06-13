// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/Native.h>
#include <Utility/PathManip.h>
#include "../PanelController.h"
#include "../PanelAux.h"
#include "../MainWindowFilePanelState.h"
#include "InsertFromPasteboard.h"
#include <Operations/Copying.h>
#include "../../MainWindowController.h"
#include <Utility/ObjCpp.h>

namespace nc::panel::actions {

// currently supports only info from NSFilenamesPboardType.
// perhaps it would be good to add support of URLS at least.
// or even with custom NC's structures used in drag&drop system

static std::vector<VFSListingItem> FetchVFSListingsItemsFromPaths( NSArray *_input )
{
    std::vector<VFSListingItem> result;
    auto &host = VFSNativeHost::SharedHost();
    for( NSString *ns_filepath in _input ) {
        if( !objc_cast<NSString>(ns_filepath) )
            continue; // guard against malformed input
        
        if( const char *filepath = ns_filepath.fileSystemRepresentation ) {
            VFSListingPtr listing;
            int rc = host->FetchSingleItemListing( filepath, listing, 0, nullptr );
            if( rc == 0 )
                result.emplace_back( listing->Item(0) );
        }
    }
    return result;
}

static std::vector<VFSListingItem> FetchVFSListingsItemsFromPasteboard()
{
    // check what's inside pasteboard
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    if( [pasteboard availableTypeFromArray:@[NSFilenamesPboardType]] ) {
        // input should be an array of filepaths as NSStrings
        auto filepaths = objc_cast<NSArray>([pasteboard propertyListForType:NSFilenamesPboardType]);
    
        // currently fetching listings synchronously, which is BAAAD
        // (but we're on native vfs, at least for now)
        return FetchVFSListingsItemsFromPaths(filepaths);
    }
    // TODO: reading from URL pasteboard?
    return {};
}

static void PasteOrMove( PanelController *_target, bool _paste)
{
    // check if we're on uniform panel with a writeable VFS
    if( !_target.isUniform || !_target.vfs->IsWritable() )
        return;
    
    auto source_items = FetchVFSListingsItemsFromPasteboard();
    
    if( source_items.empty() )
        return; // errors on fetching listings?
    
    auto opts = MakeDefaultFileCopyOptions();
    opts.docopy = _paste;
    __weak PanelController *wpc = _target;
    const auto op = std::make_shared<nc::ops::Copying>(move(source_items),
                                                  _target.currentDirectoryPath,
                                                  _target.vfs,
                                                  opts
                                                  );
    op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, [=]{
        dispatch_to_main_queue( [=]{
            if(PanelController *pc = wpc)
                [pc refreshPanel];
        });
    });
    [_target.mainWindowController enqueueOperation:op];

}

bool PasteFromPasteboard::Predicate( PanelController *_target ) const
{
    return _target.isUniform &&
        _target.vfs->IsWritable() &&
        [NSPasteboard.generalPasteboard availableTypeFromArray:@[NSFilenamesPboardType]];
}

void PasteFromPasteboard::Perform( PanelController *_target, [[maybe_unused]] id _sender ) const
{
    PasteOrMove(_target, true);
}

bool MoveFromPasteboard::Predicate( PanelController *_target ) const
{
    return _target.isUniform &&
        _target.vfs->IsWritable() &&
        [NSPasteboard.generalPasteboard availableTypeFromArray:@[NSFilenamesPboardType]];
}

void MoveFromPasteboard::Perform( PanelController *_target, [[maybe_unused]] id _sender ) const
{
    PasteOrMove(_target, false);
}

};
