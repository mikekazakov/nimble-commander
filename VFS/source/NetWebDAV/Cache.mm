#include "Cache.h"
#include <Utility/PathManip.h>
#include "Internal.h"

namespace nc::vfs::webdav {

static const auto g_ListingTimeout = 60s;

Cache::Cache()
{
}

Cache::~Cache()
{
}

void Cache::CommitListing( string _at_path, vector<PropFindResponse> _items )
{
    _at_path = EnsureTrailingSlash( move(_at_path) );
    const auto time = machtime();
    
    sort( begin(_items), end(_items), [](const auto &_1st, const auto &_2nd){
        return _1st.filename < _2nd.filename;
    });
    
    LOCK_GUARD(m_Lock) {
        auto &directory = m_Dirs[_at_path];
        directory.fetch_time = time;
        directory.has_dirty_items = false;
        directory.path = _at_path;
        directory.items = move(_items);
        directory.dirty_marks.resize( directory.items.size() );
        fill( begin(directory.dirty_marks), end(directory.dirty_marks), false );
    }
}

optional<vector<PropFindResponse>> Cache::Listing( string _at_path ) const
{
    _at_path = EnsureTrailingSlash( move(_at_path) );

    LOCK_GUARD(m_Lock) {
        const auto it = m_Dirs.find(_at_path);
        if( it == end(m_Dirs) )
            return nullopt;
        const auto &listing = it->second;
        if( listing.has_dirty_items )
            return nullopt;
        if( IsOutdated(listing) )
            return nullopt;
        return listing.items;
    }
    return nullopt;
}

optional<PropFindResponse> Cache::Item(const string &_at_path) const
{
    const auto [directory, filename] = DeconstructPath(_at_path);
    if( filename.empty() )
        return {};
    
    LOCK_GUARD(m_Lock) {
        const auto dir_it = m_Dirs.find(directory);
        if( dir_it == end(m_Dirs) )
            return {};

        const auto &listing = dir_it->second;

        if( IsOutdated(listing) )
            return {};

        const auto item = lower_bound(begin(listing.items),
                                      end(listing.items),
                                      filename,
                                      []( auto &_1, auto &_2 ){
                                          return _1.filename < _2;
                                      });
        if( item == end(listing.items) || item->filename != filename )
            return {};
        
        const auto index = distance(begin(listing.items), item);
        if( listing.dirty_marks[index] )
            return {};
        
        return *item;
    }
    
    return {};
}

void Cache::DiscardListing( string _at_path )
{
    _at_path = EnsureTrailingSlash( move(_at_path) );
    LOCK_GUARD(m_Lock) {
        m_Dirs.erase(_at_path);
    }
}

bool Cache::IsOutdated(const Directory &_listing)
{
    return _listing.fetch_time + g_ListingTimeout < machtime();
}

}
