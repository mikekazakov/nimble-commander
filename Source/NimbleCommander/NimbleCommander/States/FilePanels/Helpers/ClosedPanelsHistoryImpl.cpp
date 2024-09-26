// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ClosedPanelsHistoryImpl.h"

#include <algorithm>

namespace nc::panel {

ClosedPanelsHistoryImpl::ClosedPanelsHistoryImpl(size_t _max_capacity) : m_MaxCapacity(_max_capacity)
{
    assert(_max_capacity > 0);
}

void ClosedPanelsHistoryImpl::AddListing(ListingPromise _listing)
{
    const auto it = std::ranges::find(m_Entries, _listing);
    if( it != std::end(m_Entries) ) {
        std::rotate(std::begin(m_Entries), it, next(it));
    }
    else {
        if( m_Entries.size() == m_MaxCapacity )
            m_Entries.pop_back();
        m_Entries.emplace(begin(m_Entries), std::move(_listing));
    }
}

void ClosedPanelsHistoryImpl::RemoveListing(ListingPromise _listing)
{
    const auto it = std::ranges::find(m_Entries, _listing);
    if( it != std::end(m_Entries) )
        m_Entries.erase(it);
}

int ClosedPanelsHistoryImpl::Size() const
{
    return static_cast<int>(m_Entries.size());
}

std::vector<ListingPromise> ClosedPanelsHistoryImpl::FrontElements(int _count) const
{
    if( _count <= 0 )
        return {};
    _count = std::min(_count, Size());
    return {std::begin(m_Entries), std::next(std::begin(m_Entries), _count)};
}

} // namespace nc::panel
