// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ListingPromise.h"
#include <VFS/VFSListingInput.h>

namespace nc::panel {

ListingPromise::ListingPromise( const VFSListing &_listing, const VFSPromiseAdapter &_adapter )
{
    assert( _adapter );
    if( _listing.IsUniform() )
        m_Storage = std::make_shared<StorageT>( FromUniformListing(_listing, _adapter) );
    else
        m_Storage = std::make_shared<StorageT>( FromNonUniformListing(_listing, _adapter) );
}
    
ListingPromise::UniformListing ListingPromise::FromUniformListing(const VFSListing &_listing,
                                                                  const VFSPromiseAdapter &_adapter)
{
    assert( _listing.IsUniform() );
    
    UniformListing path;
    path.promise = _adapter( _listing.Host() );
    path.directory = _listing.Directory();
    
    return path;
}
    
ListingPromise::NonUniformListing ListingPromise::FromNonUniformListing
    (const VFSListing &_listing, const VFSPromiseAdapter &_adapter)
{
    assert( !_listing.IsUniform() );
    
    // memory massacre 2017 AD
    using DirectoriesT = std::unordered_map<std::string_view,
        nc::base::StringsBulk::NonOwningBuilder>;
    std::unordered_map<VFSHost*, DirectoriesT> entries;
    
    // this will blow up the memory subsystem on listings with 1m+ entries.
    // might need to come with a more clever solution.
    for( unsigned index = 0, count = _listing.Count(); index < count; ++index ) {
        VFSHost * const host_ptr = _listing.Host(index).get();
        
        auto &per_host = entries[ host_ptr ];
        
        const auto directory = std::string_view{ _listing.Directory(index) };
        
        auto &per_directory = per_host[directory];
        
        if( per_directory.Empty() )
            per_directory.Add( directory );
        per_directory.Add( _listing.Filename(index) );
    }

    NonUniformListing info;
    for( const auto &vfs: entries ) {
        NonUniformListing::PerVFS per_vfs;
        
        per_vfs.promise = _adapter(vfs.first->shared_from_this());
       
        for( auto &directory: vfs.second )
            per_vfs.entries.emplace_back( directory.second.Build() );
        sort( begin(per_vfs.entries), end(per_vfs.entries) );
        
        info.per_vfs.emplace_back( std::move(per_vfs) );
    }
    
    return info;
}

VFSListingPtr ListingPromise::Restore(unsigned long _fetch_flags,
                                      const PromiseVFSAdapter &_adapter,
                                      const std::function<bool()> &_cancel_checker ) const
{
    assert(_adapter);
 
    if( std::get_if<UniformListing>(&Storage()) )
        return RestoreUniform(_fetch_flags, _adapter, _cancel_checker);
    else if( std::get_if<NonUniformListing>(&Storage()) )
        return RestoreNonUniform(_fetch_flags, _adapter, _cancel_checker);
    else
        return nullptr;
}

VFSListingPtr ListingPromise::RestoreUniform(unsigned long _fetch_flags,
                                             const PromiseVFSAdapter &_adapter,
                                             const std::function<bool()> &_cancel_checker) const
{
    const auto info = std::get_if<UniformListing>(&Storage());
    assert(info);
    const auto host = _adapter(info->promise);
    if( !host )
        return nullptr;
    
    VFSListingPtr listing;
    const auto rc = host->FetchDirectoryListing(info->directory.c_str(),
                                                listing,
                                                _fetch_flags,
                                                _cancel_checker);
    if( rc != VFSError::Ok )
        throw VFSErrorException{rc};
    
    return listing;
}
    
VFSListingPtr ListingPromise::RestoreNonUniform(unsigned long _fetch_flags,
                                                const PromiseVFSAdapter &_adapter,
                                                const std::function<bool()> &_cancel_checker) const
{
    const auto info = std::get_if<NonUniformListing>(&Storage());
    assert(info);

    std::vector<VFSListingPtr> listings;
    for( const auto &per_vfs: info->per_vfs ) {
        if( _cancel_checker && _cancel_checker() )
            return nullptr;
        
        const auto host = _adapter(per_vfs.promise);
        if( !host )
            return nullptr;

        for( const auto &entries: per_vfs.entries ) {
            assert( entries.size() > 1 );
            
            const auto directory = std::string(entries.front());
            for( size_t i = 1; i < entries.size(); ++i ) {
                if( _cancel_checker && _cancel_checker() )
                    return nullptr;
                const auto path = directory + entries[i];
                VFSListingPtr listing;
                const auto rc = host->FetchSingleItemListing(path.c_str(),
                                                             listing,
                                                             _fetch_flags,
                                                             _cancel_checker);
                if( rc == VFSError::Ok && listing != nullptr )
                    listings.emplace_back( move(listing) );
            }
        }
    }
    
    if( listings.empty() )
        return nullptr;
    
    return VFSListing::Build( VFSListing::Compose(listings) );
}

const ListingPromise::StorageT &ListingPromise::Description() const noexcept
{
    return Storage();
}
    
const ListingPromise::StorageT &ListingPromise::Storage() const noexcept
{
    assert( m_Storage );
    return *m_Storage;
}

size_t ListingPromise::NonUniformListing::EntriesCount() const noexcept
{
    size_t count = 0;
    for( auto &vfs: per_vfs )
        for( auto &dir: vfs.entries ) {
            assert( dir.size() != 0 );
            count += dir.size() - 1;
        }
    return count;
}
    
bool operator==(const ListingPromise& _lhs, const ListingPromise &_rhs) noexcept
{
    return _lhs.m_Storage == _rhs.m_Storage ||
            *_lhs.m_Storage == *_rhs.m_Storage;
}
    
bool operator!=(const ListingPromise& _lhs, const ListingPromise &_rhs) noexcept
{
    return !(_lhs == _rhs);
}

bool operator==(const ListingPromise::NonUniformListing::PerVFS &_lhs,
                const ListingPromise::NonUniformListing::PerVFS &_rhs) noexcept
{
    return _lhs.promise == _rhs.promise &&
           _lhs.entries == _rhs.entries;
}
    
bool operator!=(const ListingPromise::NonUniformListing::PerVFS &_lhs,
                const ListingPromise::NonUniformListing::PerVFS &_rhs) noexcept
{
    return !(_lhs == _rhs);
}

bool operator==(const ListingPromise::UniformListing &_lhs,
                const ListingPromise::UniformListing &_rhs) noexcept
{
    return _lhs.promise == _rhs.promise && _lhs.directory == _rhs.directory;
}
    
bool operator!=(const ListingPromise::UniformListing &_lhs,
                const ListingPromise::UniformListing &_rhs) noexcept
{
    return !(_lhs == _rhs);
}
    
bool operator==(const ListingPromise::NonUniformListing &_lhs,
                const ListingPromise::NonUniformListing &_rhs) noexcept
{
    return _lhs.per_vfs == _rhs.per_vfs;
}
    
bool operator!=(const ListingPromise::NonUniformListing &_lhs,
                const ListingPromise::NonUniformListing &_rhs) noexcept
{
    return !(_lhs == _rhs);
}
    
}
