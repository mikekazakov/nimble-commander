#include "ClosedPanelsHistoryImpl.h"

namespace nc::panel {
    
ClosedPanelsHistoryImpl::ClosedPanelsHistoryImpl(size_t _max_capacity):
    m_MaxCapacity(_max_capacity)
{
    assert( _max_capacity > 0 );
}
    
void ClosedPanelsHistoryImpl::AddListing( ListingPromise _listing )
{
    const auto it = find( begin(m_Entries), end(m_Entries), _listing );
    if( it != end(m_Entries) ) {
        rotate( begin(m_Entries), it, next(it) );
    }
    else {
        if( m_Entries.size() == m_MaxCapacity )
            m_Entries.pop_back();
        m_Entries.emplace(begin(m_Entries), move(_listing) );
    }
}
    
void ClosedPanelsHistoryImpl::RemoveListing( ListingPromise _listing )
{
    const auto it = find( begin(m_Entries), end(m_Entries), _listing );
    if( it != end(m_Entries) )
        m_Entries.erase(it);
}
    
int ClosedPanelsHistoryImpl::Size() const
{
    return (int)m_Entries.size();
}
    
vector<ListingPromise> ClosedPanelsHistoryImpl::FrontElements( int _count ) const
{
    if( _count <= 0 )
        return {};
    _count = min( _count, Size() );
    return { begin(m_Entries), next(begin(m_Entries), _count) };
}
    
}
