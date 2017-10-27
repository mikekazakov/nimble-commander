// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Cache.h"
#include <Utility/PathManip.h>
#include "Internal.h"
#include "PathRoutines.h"

namespace nc::vfs::webdav {

static const auto g_ListingTimeout = 60s;

Cache::Cache()
{
}

Cache::~Cache()
{
}

void Cache::CommitListing( const string &_at_path, vector<PropFindResponse> _items )
{
    const auto path = EnsureTrailingSlash( _at_path );
    const auto time = machtime();
    
    sort( begin(_items), end(_items), [](const auto &_1st, const auto &_2nd){
        return _1st.filename < _2nd.filename;
    });
    
    LOCK_GUARD(m_Lock) {
        auto &directory = m_Dirs[path];
        directory.fetch_time = time;
        directory.has_dirty_items = false;
        directory.items = move(_items);
        directory.dirty_marks.resize( directory.items.size() );
        fill( begin(directory.dirty_marks), end(directory.dirty_marks), false );
    }
    
    Notify(path);
}

optional<vector<PropFindResponse>> Cache::Listing( const string &_at_path ) const
{
    const auto path = EnsureTrailingSlash( _at_path );

    LOCK_GUARD(m_Lock) {
        const auto it = m_Dirs.find(path);
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

void Cache::DiscardListing( const string &_at_path )
{
    const auto path = EnsureTrailingSlash( _at_path );
    LOCK_GUARD(m_Lock) {
        m_Dirs.erase(path);
    }
}

bool Cache::IsOutdated(const Directory &_listing)
{
    return _listing.fetch_time + g_ListingTimeout < machtime();
}

void Cache::CommitMkDir( const string &_at_path )
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
    
    Notify(directory);
}

void Cache::CommitMkFile( const string &_at_path )
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
        const auto index = distance(begin(listing.items), item_it);
        if( item_it == end(listing.items) || item_it->filename != filename  ) {
            PropFindResponse r;
            r.filename = filename;
            r.is_directory = false;
            listing.items.insert( item_it, move(r) );
            listing.dirty_marks.insert(begin(listing.dirty_marks)+index, true);
        }
        else {
            listing.dirty_marks[index] = true;
        }
        
        listing.has_dirty_items = true;
    }

    Notify(directory);
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
    
    Notify(directory);
}

void Cache::CommitMove( const string &_old_path, const string &_new_path )
{
    LOCK_GUARD(m_Lock) {
        const auto dir_it = m_Dirs.find(EnsureTrailingSlash(_old_path));
        if( dir_it != end(m_Dirs) ) {
            m_Dirs[EnsureTrailingSlash(_new_path)] = move(dir_it->second);
            m_Dirs.erase(dir_it);
        }
    }

    const auto [old_directory, old_filename] = DeconstructPath(_old_path);
    if( old_filename.empty() )
        return;
    
    optional<PropFindResponse> entry;
    
    LOCK_GUARD(m_Lock) {
        const auto dir_it = m_Dirs.find(old_directory);
        if( dir_it == end(m_Dirs) )
            return;
        
        auto &listing = dir_it->second;
        const auto item_it = lower_bound(begin(listing.items),
                                         end(listing.items),
                                         old_filename,
                                         []( auto &_1, auto &_2 ){
                                             return _1.filename < _2;
                                         });
        if( item_it != end(listing.items) && item_it->filename == old_filename ) {
            entry = move(*item_it);
            const auto index = distance(begin(listing.items), item_it);
            listing.items.erase( item_it );
            listing.dirty_marks.erase( begin(listing.dirty_marks) + index );
        }
    }
    Notify(old_directory);
    
    const auto [new_directory, new_filename] = DeconstructPath(_new_path);
    if( new_filename.empty() )
        return;
    
    LOCK_GUARD(m_Lock) {
        const auto dir_it = m_Dirs.find(new_directory);
        if( dir_it == end(m_Dirs) )
            return;
        auto &listing = dir_it->second;
        listing.has_dirty_items = true;
        
        if( entry ) {
            const auto item_it = lower_bound(begin(listing.items),
                                             end(listing.items),
                                             new_filename,
                                             []( auto &_1, auto &_2 ){
                                                 return _1.filename < _2;
                                             });
            const auto index = distance(begin(listing.items), item_it);
            if( item_it == end(listing.items) || item_it->filename != new_filename  ) {
                listing.items.insert( item_it, move(*entry) );
                listing.dirty_marks.insert(begin(listing.dirty_marks)+index, true);
            }
            else {
                *item_it = move(*entry);
                listing.dirty_marks[index] = true;
            }
        }
    }
    
    Notify(new_directory);
}

void Cache::Notify( const string &_changed_dir_path )
{
    LOCK_GUARD(m_ObserversLock) {
        auto [first, last] = m_Observers.equal_range(_changed_dir_path);
        for(; first != last; ++first )
            first->second.callback();
    }
}

unsigned long Cache::Observe(const string &_path, function<void()> _handler)
{
    if( !_handler )
        return 0;
    
    const auto ticket = m_LastTicket++;
    
    Observer o;
    o.callback = move(_handler);
    o.ticket = ticket;
    
    LOCK_GUARD(m_ObserversLock) {
        m_Observers.emplace( make_pair(EnsureTrailingSlash(_path), move(o)) );
    }

    return ticket;
}

void Cache::StopObserving(unsigned long _ticket)
{
    if( _ticket == 0 )
        return;
    
    LOCK_GUARD(m_ObserversLock) {
        const auto it = find_if(begin(m_Observers), end(m_Observers), [_ticket](const auto &_o){
            return _o.second.ticket == _ticket;
        });
        if( it != end(m_Observers) )
            m_Observers.erase(it);
    }
}

}
