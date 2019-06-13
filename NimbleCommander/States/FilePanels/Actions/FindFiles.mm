// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFSListingInput.h>
#include <NimbleCommander/States/FilePanels/FindFilesSheetController.h>
#include "../PanelController.h"
#include "FindFiles.h"
#include "../PanelView.h"
#include <Habanero/dispatch_cpp.h>
#include <Viewer/ViewerSheet.h>
#include <Viewer/ViewerViewController.h>
#include <Viewer/InternalViewerWindowController.h>

// TEMP - need to refactor this bullcrap!
#include <NimbleCommander/Bootstrap/Config.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>

static const auto g_ConfigModalInternalViewer = "viewer.modalMode";

namespace nc::panel::actions {

FindFiles::FindFiles(std::function<NCViewerView*(NSRect)> _make_viewer,
                     std::function<NCViewerViewController*()> _make_controller) :
    m_MakeViewer{ std::move(_make_viewer) },
    m_MakeController{ std::move(_make_controller) }
{
}

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

void FindFiles::Perform( PanelController *_target, id ) const
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
    sheet.onView = [this](const FindFilesSheetViewRequest& _request) {
        OnView(_request);
    };
    auto handler = ^([[maybe_unused]] NSModalResponse returnCode) {
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

void FindFiles::OnView(const FindFilesSheetViewRequest& _request) const
{    
    if( GlobalConfig().GetBool(g_ConfigModalInternalViewer) ) { // as a sheet
        const auto sheet = [[NCViewerSheet alloc]
                            initWithFilepath:_request.path
                            at:_request.vfs
                            viewerFactory:m_MakeViewer
                            viewerController:m_MakeController()];
        dispatch_to_background([=]{
            const auto success = [sheet open];
            dispatch_to_main_queue([=]{
                // make sure that 'sheet' will be destroyed in main queue
                if( success ) {
                    [sheet beginSheetForWindow:_request.sender.window];
                    if( _request.content_mark ) {
                        auto range = CFRangeMake(_request.content_mark->bytes_offset,
                                                 _request.content_mark->bytes_length);
                        [sheet markInitialSelection:range
                                         searchTerm:_request.content_mark->search_term];
                    }
                }
            });
        });
    }
    else { // as a window
        auto window = [NCAppDelegate.me retrieveInternalViewerWindowForPath:_request.path
                                                                      onVFS:_request.vfs];
        if( window.internalViewerController.isOpened ) {
            [window showWindow:_request.sender];
            if( _request.content_mark ) {
                auto range = CFRangeMake(_request.content_mark->bytes_offset,
                                         _request.content_mark->bytes_length);
                [window markInitialSelection:range
                                  searchTerm:_request.content_mark->search_term];
            }
        }
        else {
            dispatch_to_background([=]{
                const auto opening_result = [window performBackgrounOpening];
                dispatch_to_main_queue([=]{
                    if( opening_result ) {
                        [window showAsFloatingWindow];
                        if( _request.content_mark ) {
                            auto range = CFRangeMake(_request.content_mark->bytes_offset,
                                                     _request.content_mark->bytes_length);
                            [window markInitialSelection:range
                                              searchTerm:_request.content_mark->search_term];
                        }
                    }
                });
            });
        }
    }
}
    
};
