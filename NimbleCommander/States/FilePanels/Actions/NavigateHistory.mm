#include "NavigateHistory.h"
#include "../PanelController.h"
#include "../PanelHistory.h"

namespace nc::panel::actions {

bool GoBack::Predicate( PanelController *_target ) const
{
    const auto &history = _target.history;
    return history.CanMoveBack() || ( !history.Empty() && !_target.isUniform );
}

void GoBack::Perform( PanelController *_target, id _sender ) const
{
    auto &history = _target.history;
    if( _target.isUniform ) {
        if( !history.CanMoveBack() )
            return;
        history.MoveBack();
    }
    else {
        // a different logic here, since non-uniform listings like search results
        // (and temporary panels later) are not written into history
        if( history.Empty() )
            return;
        history.RewindAt( history.Length()-1 );
    }
    
    [_target GoToVFSPromise:history.Current()->vfs
                     onPath:history.Current()->path];
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
    [_target GoToVFSPromise:history.Current()->vfs
                     onPath:history.Current()->path];
}

}
