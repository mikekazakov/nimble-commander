// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <vector>

namespace nc::panel {

class ListingPromise;
    
class ClosedPanelsHistory
{
public:
    virtual ~ClosedPanelsHistory() = default;
    virtual void AddListing( ListingPromise _listing ) = 0;
    virtual void RemoveListing( ListingPromise _listing ) = 0;
    virtual int Size() const = 0;
    virtual std::vector<ListingPromise> FrontElements( int _count ) const = 0;
};
    
}
