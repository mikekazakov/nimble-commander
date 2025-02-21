// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
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

static std::vector<VFSListingItem> FetchVFSListingsItemsFromPaths(NSArray *_input, vfs::NativeHost &_native_host)
{
    std::vector<VFSListingItem> result;
    for( NSString *ns_filepath in _input ) {
        if( !objc_cast<NSString>(ns_filepath) )
            continue; // guard against malformed input

        if( const char *filepath = ns_filepath.fileSystemRepresentation ) {
            if( const std::expected<VFSListingPtr, Error> listing = _native_host.FetchSingleItemListing(filepath, 0) )
                result.emplace_back((*listing)->Item(0));
        }
    }
    return result;
}

static std::vector<VFSListingItem> FetchVFSListingsItemsFromPasteboard(vfs::NativeHost &_native_host)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

    // check what's inside pasteboard
    NSPasteboard *const pasteboard = NSPasteboard.generalPasteboard;
    if( [pasteboard availableTypeFromArray:@[NSFilenamesPboardType]] ) {
        // input should be an array of filepaths as NSStrings
        auto filepaths = objc_cast<NSArray>([pasteboard propertyListForType:NSFilenamesPboardType]);

        // currently fetching listings synchronously, which is BAAAD
        // (but we're on native vfs, at least for now)
        return FetchVFSListingsItemsFromPaths(filepaths, _native_host);
    }
    // TODO: reading from URL pasteboard?
    return {};

#pragma clang diagnostic pop
}

static void PasteOrMove(PanelController *_target, bool _paste, vfs::NativeHost &_native_host)
{
    // check if we're on uniform panel with a writeable VFS
    if( !_target.isUniform || !_target.vfs->IsWritable() )
        return;

    auto source_items = FetchVFSListingsItemsFromPasteboard(_native_host);

    if( source_items.empty() )
        return; // errors on fetching listings?

    auto opts = MakeDefaultFileCopyOptions();
    opts.docopy = _paste;
    __weak PanelController *wpc = _target;
    const auto op =
        std::make_shared<nc::ops::Copying>(std::move(source_items), _target.currentDirectoryPath, _target.vfs, opts);
    op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, [=] {
        dispatch_to_main_queue([=] {
            if( PanelController *const pc = wpc )
                [pc refreshPanel];
        });
    });
    [_target.mainWindowController enqueueOperation:op];
}

PasteFromPasteboard::PasteFromPasteboard(nc::vfs::NativeHost &_native_host) : m_NativeHost(_native_host)
{
}

bool PasteFromPasteboard::Predicate(PanelController *_target) const
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return _target.isUniform && _target.vfs->IsWritable() &&
           [NSPasteboard.generalPasteboard availableTypeFromArray:@[NSFilenamesPboardType]];
#pragma clang diagnostic pop
}

void PasteFromPasteboard::Perform(PanelController *_target, [[maybe_unused]] id _sender) const
{
    PasteOrMove(_target, true, m_NativeHost);
}

MoveFromPasteboard::MoveFromPasteboard(nc::vfs::NativeHost &_native_host) : m_NativeHost(_native_host)
{
}

bool MoveFromPasteboard::Predicate(PanelController *_target) const
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return _target.isUniform && _target.vfs->IsWritable() &&
           [NSPasteboard.generalPasteboard availableTypeFromArray:@[NSFilenamesPboardType]];
#pragma clang diagnostic pop
}

void MoveFromPasteboard::Perform(PanelController *_target, [[maybe_unused]] id _sender) const
{
    PasteOrMove(_target, false, m_NativeHost);
}

}; // namespace nc::panel::actions
