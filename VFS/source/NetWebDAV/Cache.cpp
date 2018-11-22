// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Cache.h"
#include <Utility/PathManip.h>
#include "Internal.h"
#include "PathRoutines.h"
#include <Habanero/mach_time.h>
#include <Habanero/spinlock.h>

namespace nc::vfs::webdav {

using namespace std::literals;

static const auto g_ListingTimeout = 60s;

Cache::Cache()
{
}

Cache::~Cache()
{
}

void Cache::CommitListing( const std::string &_at_path, std::vector<PropFindResponse> _items )
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

std::optional<std::vector<PropFindResponse>> Cache::Listing( const std::string &_at_path ) const
{
    const auto path = EnsureTrailingSlash( _at_path );

    LOCK_GUARD(m_Lock) {
        const auto it = m_Dirs.find(path);
        if( it == end(m_Dirs) )
            return std::nullopt;
        const auto &listing = it->second;
        if( listing.has_dirty_items )
            return std::nullopt;
        if( IsOutdated(listing) )
            return std::nullopt;
        return listing.items;
    }
    return std::nullopt;
}

std::pair<std::optional<PropFindResponse>, Cache::E> Cache::Item(const std::string &_at_path) const
{
    const auto [directory, filename] = DeconstructPath(_at_path);
    if( filename.empty() )
        return {std::nullopt, E::NonExist};
    
    LOCK_GUARD(m_Lock) {
        const auto dir_it = m_Dirs.find(directory);
        if( dir_it == end(m_Dirs) )
            return {std::nullopt, E::Unknown};

        const auto &listing = dir_it->second;

        if( IsOutdated(listing) )
            return {std::nullopt, E::Unknown};

        const auto item = std::lower_bound(std::begin(listing.items),
                                           std::end(listing.items),
                                           filename,
                                           []( auto &_1, auto &_2 ){
                                               return _1.filename < _2;
                                           });
        if( item == std::end(listing.items) || item->filename != filename )
            return {std::nullopt, E::NonExist};
        
        const auto index = std::distance(begin(listing.items), item);
        if( listing.dirty_marks[index] )
            return {std::nullopt, E::Unknown};
        
        return {*item, E::Ok};
    }
}

void Cache::DiscardListing( const std::string &_at_path )
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

void Cache::CommitMkDir( const std::string &_at_path )
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
            listing.items.insert( item_it, std::move(r) );
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

void Cache::CommitMkFile( const std::string &_at_path )
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
            listing.items.insert( item_it, std::move(r) );
            listing.dirty_marks.insert(begin(listing.dirty_marks)+index, true);
        }
        else {
            listing.dirty_marks[index] = true;
        }
        
        listing.has_dirty_items = true;
    }

    Notify(directory);
}

void Cache::CommitRmDir( const std::string &_at_path )
{
    CommitUnlink(_at_path);
    DiscardListing(_at_path);
}

void Cache::CommitUnlink( const std::string &_at_path )
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

void Cache::CommitMove( const std::string &_old_path, const std::string &_new_path )
{
    LOCK_GUARD(m_Lock) {
        const auto dir_it = m_Dirs.find(EnsureTrailingSlash(_old_path));
        if( dir_it != end(m_Dirs) ) {
            m_Dirs[EnsureTrailingSlash(_new_path)] = std::move(dir_it->second);
            m_Dirs.erase(dir_it);
        }
    }

    const auto [old_directory, old_filename] = DeconstructPath(_old_path);
    if( old_filename.empty() )
        return;
    
    std::optional<PropFindResponse> entry;
    
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
            entry = std::move(*item_it);
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
            const auto item_it = std::lower_bound(std::begin(listing.items),
                                                  std::end(listing.items),
                                                  new_filename,
                                                  []( auto &_1, auto &_2 ){
                                                      return _1.filename < _2;
                                                  });
            const auto index = std::distance(std::begin(listing.items), item_it);
            if( item_it == std::end(listing.items) || item_it->filename != new_filename  ) {
                listing.items.insert( item_it, std::move(*entry) );
                listing.dirty_marks.insert(std::begin(listing.dirty_marks)+index, true);
            }
            else {
                *item_it = std::move(*entry);
                listing.dirty_marks[index] = true;
            }
        }
    }
    
    Notify(new_directory);
}

void Cache::Notify( const std::string &_changed_dir_path )
{
    LOCK_GUARD(m_ObserversLock) {
        auto [first, last] = m_Observers.equal_range(_changed_dir_path);
        for(; first != last; ++first )
            first->second.callback();
    }
}

unsigned long Cache::Observe(const std::string &_path, std::function<void()> _handler)
{
    if( !_handler )
        return 0;
    
    const auto ticket = m_LastTicket++;
    
    Observer o;
    o.callback = move(_handler);
    o.ticket = ticket;
    
    LOCK_GUARD(m_ObserversLock) {
        m_Observers.emplace( std::make_pair(EnsureTrailingSlash(_path), std::move(o)) );
    }

    return ticket;
}

void Cache::StopObserving(unsigned long _ticket)
{
    if( _ticket == 0 )
        return;
    
    LOCK_GUARD(m_ObserversLock) {
        const auto it = std::find_if(std::begin(m_Observers),
                                     std::end(m_Observers),
                                     [_ticket](const auto &_o){
            return _o.second.ticket == _ticket;
        });
        if( it != end(m_Observers) )
            m_Observers.erase(it);
    }
}

}
