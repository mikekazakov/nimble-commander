// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFSListingInput.h>
#include <NimbleCommander/States/FilePanels/FindFilesSheetController.h>
#include "../PanelController.h"
#include "FindFiles.h"
#include "../PanelView.h"
#include <Habanero/dispatch_cpp.h>

namespace nc::panel::actions {

bool FindFiles::Predicate( PanelController *_target ) const
{
    return _target.isUniform || _target.view.item;
}

static std::shared_ptr<VFSListing>
    FetchSearchResultsAsListing(const std::vector<VFSPath> &_filepaths,
                                unsigned long _fetch_flags,
                                const VFSCancelChecker &_cancel_checker)
{
    std::vector<VFSListingPtr> listings;
    
    for( auto &p: _filepaths ) {
        VFSListingPtr listing;
        int ret = p.Host()->FetchSingleItemListing(p.Path().c_str(),
                                                   listing,
                                                   _fetch_flags,
                                                   _cancel_checker);
        if( ret == 0 )
            listings.emplace_back( listing );

        if( _cancel_checker && _cancel_checker() )
            return {};
    }
    
    return VFSListing::Build( VFSListing::Compose(listings) );
}

void FindFiles::Perform( PanelController *_target, id _sender ) const
{
    FindFilesSheetController *sheet = [FindFilesSheetController new];
    sheet.vfsInstanceManager = &_target.vfsInstanceManager;
    sheet.host = _target.isUniform ?
        _target.vfs :
        _target.view.item.Host();
    sheet.path = _target.isUniform ?
        _target.currentDirectoryPath :
        _target.view.item.Directory();
    __weak PanelController *wp = _target;
    sheet.onPanelize = [wp](const std::vector<VFSPath> &_paths) {
        if( PanelController *panel = wp ) {
            auto task = [=]( const std::function<bool()> &_cancelled ) {
                auto l = FetchSearchResultsAsListing(_paths,
                                                     panel.vfsFetchingFlags,
                                                     _cancelled
                                                     );
                if( l )
                    dispatch_to_main_queue([=]{
                        [panel loadListing:l];
                    });
            };
            [panel commitCancelableLoadingTask:std::move(task)];
        }
    };
    
    auto handler = ^(NSModalResponse returnCode) {
        if( auto item = sheet.selectedItem ) {
            auto request = std::make_shared<DirectoryChangeRequest>();
            request->RequestedDirectory = item->dir_path;
            request->VFS = item->host;
            request->RequestFocusedEntry = item->filename; 
            request->PerformAsynchronous = true;
            request->InitiatedByUser = true;
            [_target GoToDirWithContext:request];
        }
    };
    [sheet beginSheetForWindow:_target.window completionHandler:handler];
}

};
