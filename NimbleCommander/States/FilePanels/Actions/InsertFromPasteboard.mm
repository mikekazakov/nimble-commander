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

static vector<VFSListingItem> FetchVFSListingsItemsFromDirectories(
    const unordered_map<string, vector<string>>& _input, VFSHost& _host )
{
    vector<VFSListingItem> source_items;
    for( auto &dir: _input ) {
        vector<VFSListingItem> items_for_dir;
        if( _host.FetchFlexibleListingItems(dir.first, dir.second, 0, items_for_dir, nullptr) ==
            VFSError::Ok )
            move( begin(items_for_dir), end(items_for_dir), back_inserter(source_items) );
    }
    return source_items;
}

static unordered_map<string, vector<string>> LayoutPathsByContainingDirectories( NSArray *_input ) // array of NSStrings
{
    if(!_input)
        return {};
    unordered_map<string, vector<string>> filenames; // root directory to containing filenames map
    for( NSString *ns_filename in _input ) {
        if( !objc_cast<NSString>(ns_filename) )
            continue; // guard against malformed input
        // filenames are without trailing slashes for dirs here
        char dir[MAXPATHLEN], fn[MAXPATHLEN];
        if( !GetDirectoryContainingItemFromPath([ns_filename fileSystemRepresentation], dir) )
            continue;
        if( !GetFilenameFromPath([ns_filename fileSystemRepresentation], fn) )
            continue;
        filenames[dir].push_back(fn);
    }
    return filenames;
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
        auto items = FetchVFSListingsItemsFromDirectories(
            LayoutPathsByContainingDirectories(filepaths),
            *VFSNativeHost::SharedHost()
            );
        
        return items;
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
