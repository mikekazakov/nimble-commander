// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "DefaultAction.h"

namespace nc::panel::actions {

struct GoBack final : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

struct GoForward final : PanelAction
{
    bool Predicate( PanelController *_target ) const override;
    void Perform( PanelController *_target, id _sender ) const override;
};

}

namespace nc::panel {

class ListingPromise;
    
class ListingPromiseLoader
{
public:
    void Load( const ListingPromise &_promise, PanelController *_panel );
};
    
}
