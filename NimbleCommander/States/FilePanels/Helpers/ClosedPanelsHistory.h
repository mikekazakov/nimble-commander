#pragma once

namespace nc::panel {

class ListingPromise;
    
class ClosedPanelsHistory
{
public:
    virtual ~ClosedPanelsHistory() = default;
    virtual void AddListing( ListingPromise _listing ) = 0;
    virtual void RemoveListing( ListingPromise _listing ) = 0;
    virtual int Size() const = 0;
    virtual vector<ListingPromise> FrontElements( int _count ) const = 0;
};
    
}
