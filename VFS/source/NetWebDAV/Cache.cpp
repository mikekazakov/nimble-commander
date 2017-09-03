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

// better to tell if the listing is valid but the item doesn't exist
pair<optional<PropFindResponse>, Cache::E> Cache::Item(const string &_at_path) const
{
    const auto [directory, filename] = DeconstructPath(_at_path);
    if( filename.empty() )
        return {nullopt, E::NonExist};
    
    LOCK_GUARD(m_Lock) {
        const auto dir_it = m_Dirs.find(directory);
        if( dir_it == end(m_Dirs) )
            return {nullopt, E::Unknown};

        const auto &listing = dir_it->second;

        if( IsOutdated(listing) )
            return {nullopt, E::Unknown};

        const auto item = lower_bound(begin(listing.items),
                                      end(listing.items),
                                      filename,
                                      []( auto &_1, auto &_2 ){
                                          return _1.filename < _2;
                                      });
        if( item == end(listing.items) || item->filename != filename )
            return {nullopt, E::NonExist};
        
        const auto index = distance(begin(listing.items), item);
        if( listing.dirty_marks[index] )
            return {nullopt, E::Unknown};
        
        return {*item, E::Ok};
    }
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

void Cache::CommitMkDir( string _at_path )
{
    _at_path = EnsureNoTrailingSlash( move(_at_path) );
    const auto [directory, filename] = DeconstructPath(_at_path);
    if( filename.empty() )
        return;

    LOCK_GUARD(m_Lock) {
        const auto dir_it = m_Dirs.find(directory);
        if( dir_it == end(m_Dirs) )
            return;

        auto &listing = dir_it->second;
        const auto item_it = lower_bound(begin(listing.items),
                                         end(listing.items),
                                         filename,
                                         []( auto &_1, auto &_2 ){
                                             return _1.filename < _2;
                                         });
        if( item_it == end(listing.items) || item_it->filename != filename  ) {
            PropFindResponse r;
            r.filename = filename;
            r.is_directory = true;
            const auto index = distance(begin(listing.items), item_it);
            listing.items.insert( item_it, move(r) );
            listing.dirty_marks.insert(begin(listing.dirty_marks)+index, true);
        }
        else {
            const auto index = distance(begin(listing.items), item_it);
            listing.dirty_marks[index] = true;
        }
        
        listing.has_dirty_items = true;
    }
}

void Cache::CommitMkFile( string _at_path )
{
    _at_path = EnsureNoTrailingSlash( move(_at_path) );
    const auto [directory, filename] = DeconstructPath(_at_path);
    if( filename.empty() )
        return;

    LOCK_GUARD(m_Lock) {
        const auto dir_it = m_Dirs.find(directory);
        if( dir_it == end(m_Dirs) )
            return;

        auto &listing = dir_it->second;
        const auto item_it = lower_bound(begin(listing.items),
                                         end(listing.items),
                                         filename,
                                         []( auto &_1, auto &_2 ){
                                             return _1.filename < _2;
                                         });
        if( item_it == end(listing.items) || item_it->filename != filename  ) {
            PropFindResponse r;
            r.filename = filename;
            r.is_directory = false;
            const auto index = distance(begin(listing.items), item_it);
            listing.items.insert( item_it, move(r) );
            listing.dirty_marks.insert(begin(listing.dirty_marks)+index, true);
        }
        else {
            const auto index = distance(begin(listing.items), item_it);
            listing.dirty_marks[index] = true;
        }
        
        listing.has_dirty_items = true;
    }
}

void Cache::CommitRmDir( const string &_at_path )
{
    CommitUnlink(_at_path);
    DiscardListing(_at_path);
}

void Cache::CommitUnlink( const string &_at_path )
{
    const auto [directory, filename] = DeconstructPath(_at_path);
    if( filename.empty() )
        return;
    
    LOCK_GUARD(m_Lock) {
        const auto dir_it = m_Dirs.find(directory);
        if( dir_it == end(m_Dirs) )
            return;

        auto &listing = dir_it->second;
        const auto item_it = lower_bound(begin(listing.items),
                                         end(listing.items),
                                         filename,
                                         []( auto &_1, auto &_2 ){
                                             return _1.filename < _2;
                                         });
        if( item_it != end(listing.items) && item_it->filename == filename  ) {
            const auto index = distance(begin(listing.items), item_it);
            listing.items.erase( item_it );
            listing.dirty_marks.erase( begin(listing.dirty_marks) + index );
        }
        listing.has_dirty_items = true;
    }
}

}
