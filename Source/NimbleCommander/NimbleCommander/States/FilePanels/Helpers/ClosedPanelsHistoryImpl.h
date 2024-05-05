// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include "ClosedPanelsHistory.h"
#include "../ListingPromise.h"

namespace nc::panel {

// not a thread-safe implementation
class ClosedPanelsHistoryImpl : public ClosedPanelsHistory
{
public:
    ClosedPanelsHistoryImpl(size_t _max_capacity = 32);
    void AddListing(ListingPromise _listing) override;
    void RemoveListing(ListingPromise _listing) override;
    int Size() const override;
    std::vector<ListingPromise> FrontElements(int _count) const override;

private:
    size_t m_MaxCapacity;
    std::vector<ListingPromise> m_Entries;
};

} // namespace nc::panel
