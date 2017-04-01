#include <VFS/Native.h>
#include <Utility/PathManip.h>
#include <NimbleCommander/Operations/Copy/FileCopyOperation.h>
#include "../PanelController.h"
#include "../PanelAux.h"
#include "../MainWindowFilePanelState.h"
#include "InsertFromPasteboard.h"

namespace panel::actions {

// currently supports only info from NSFilenamesPboardType.
// perhaps it would be good to add support of URLS at least.
// or even with custom NC's structures used in drag&drop system

static vector<VFSListingItem> FetchVFSListingsItemsFromPaths( NSArray *_input )
{
    vector<VFSListingItem> result;
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

static vector<VFSListingItem> FetchVFSListingsItemsFromPasteboard()
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
    if( !_target.isUniform || !_target.vfs->IsWriteable() )
        return;
    
    auto source_items = FetchVFSListingsItemsFromPasteboard();
    
    if( source_items.empty() )
        return; // errors on fetching listings?
    
    FileCopyOperationOptions opts = panel::MakeDefaultFileCopyOptions();
    opts.docopy = _paste;
    auto op = [[FileCopyOperation alloc] initWithItems:move(source_items)
                                       destinationPath:_target.currentDirectoryPath
                                       destinationHost:_target.vfs
                                               options:opts];
    
    __weak PanelController *wpc = _target;
    [op AddOnFinishHandler:^{
        dispatch_to_main_queue( [=]{
            if(PanelController *pc = wpc) [pc refreshPanel];
        });
    }];
    
    [_target.state AddOperation:op];
}

bool PasteFromPasteboard::Predicate( PanelController *_target )
{
    return _target.isUniform &&
        _target.vfs->IsWriteable() &&
        [NSPasteboard.generalPasteboard availableTypeFromArray:@[NSFilenamesPboardType]];
}

bool PasteFromPasteboard::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )
{
    return Predicate( _target );
}

void PasteFromPasteboard::Perform( PanelController *_target, id _sender )
{
    PasteOrMove(_target, true);
}

bool MoveFromPasteboard::Predicate( PanelController *_target )
{
    return PasteFromPasteboard::Predicate(_target);
}

bool MoveFromPasteboard::ValidateMenuItem( PanelController *_target, NSMenuItem *_item )
{
    return Predicate( _target );
}

void MoveFromPasteboard::Perform( PanelController *_target, id _sender )
{
    PasteOrMove(_target, false);
}

};
