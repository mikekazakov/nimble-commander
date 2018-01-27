// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NavigateHistory.h"
#include "../PanelController.h"
#include "../PanelHistory.h"
#include <NimbleCommander/Core/VFSInstanceManager.h>

namespace nc::panel::actions {

bool GoBack::Predicate( PanelController *_target ) const
{
    return _target.history.CanMoveBack();
}
    
void GoBack::Perform( PanelController *_target, id _sender ) const
{
    auto &history = _target.history;
    if( !history.CanMoveBack() )
        return;
    history.MoveBack();
    
    if( auto listing_promise = history.CurrentPlaying() )
        ListingPromiseLoader{}.Load( *listing_promise, _target );
}

bool GoForward::Predicate( PanelController *_target ) const
{
    return _target.history.CanMoveForth();
}

void GoForward::Perform( PanelController *_target, id _sender ) const
{
    auto &history = _target.history;
    if( !history.CanMoveForth() )
        return;
    history.MoveForth();

    if( auto listing_promise = history.CurrentPlaying() )
        ListingPromiseLoader{}.Load( *listing_promise, _target );
}

}

namespace nc::panel {

void ListingPromiseLoader::Load( const ListingPromise &_promise, PanelController *_panel )
{
    auto task = [=]( const function<bool()> &_cancelled ) {
        const auto vfs_adapter = [&](const core::VFSInstancePromise& _promise){
            return _panel.vfsInstanceManager.RetrieveVFS(_promise, _cancelled );
        };
        
        try {
            const auto listing = _promise.Restore(_panel.vfsFetchingFlags,
                                                  vfs_adapter,
                                                  _cancelled);
            if( listing )
                dispatch_to_main_queue([=]{
                    [_panel loadListing:listing];
                });
        }
        catch(...){
            //...
        }
    };
    [_panel commitCancelableLoadingTask:move(task)];
}

}
