// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS_fwd.h>
#include <Habanero/StringsBulk.h>
#include <boost/variant.hpp>

// TODO: break VFSInstanceManager.h into two headers to separate VFSInstancePromise
#include "../../Core/VFSInstanceManager.h"

namespace nc::panel {
    
class ListingPromise
{
public:
    struct UniformListing
    {
        VFSInstancePromise promise;
        string directory;
    };
    
    struct NonUniformListing
    {
        struct PerVFS
        {
            VFSInstancePromise promise;
            vector<hbn::StringsBulk> entries;
        };
        vector<PerVFS> per_vfs;
        
        size_t EntriesCount() const noexcept;
    };
    
    using StorageT = boost::variant<UniformListing, NonUniformListing>;
    using VFSPromiseAdapter = function<VFSInstancePromise(const shared_ptr<VFSHost>&)>;
    using PromiseVFSAdapter = function<shared_ptr<VFSHost>(const VFSInstancePromise&)>;
    
    ListingPromise( const VFSListing &_listing, const VFSPromiseAdapter &_adapter );
    ListingPromise( const ListingPromise&) = default;
    ListingPromise( ListingPromise&& ) = default;

    ListingPromise &operator=(const ListingPromise &) = default;
    ListingPromise &operator=(ListingPromise &&) = default;

    // may throw VFSErrorException or return nullptr
    VFSListingPtr Restore(unsigned long _fetch_flags,
                          const PromiseVFSAdapter &_adapter,
                          const function<bool()> &_cancel_checker) const;

    const StorageT &Description() const noexcept;
    
private:
    friend bool operator==(const ListingPromise& _lhs, const ListingPromise &_rhs) noexcept;
    
    VFSListingPtr RestoreUniform(unsigned long _fetch_flags,
                                 const PromiseVFSAdapter &_adapter,
                                 const function<bool()> &_cancel_checker) const;
    VFSListingPtr RestoreNonUniform(unsigned long _fetch_flags,
                                    const PromiseVFSAdapter &_adapter,
                                    const function<bool()> &_cancel_checker) const;
    static NonUniformListing FromNonUniformListing(const VFSListing &_listing,
                                                   const VFSPromiseAdapter &_adapter);
    static UniformListing FromUniformListing(const VFSListing &_listing,
                                             const VFSPromiseAdapter &_adapter);
    const StorageT &Storage() const noexcept;

    shared_ptr<const StorageT> m_Storage;
};

bool operator==(const ListingPromise::UniformListing &_lhs,
                const ListingPromise::UniformListing &_rhs) noexcept;
bool operator!=(const ListingPromise::UniformListing &_lhs,
                const ListingPromise::UniformListing &_rhs) noexcept;
bool operator==(const ListingPromise::NonUniformListing &_lhs,
                const ListingPromise::NonUniformListing &_rhs) noexcept;
bool operator!=(const ListingPromise::NonUniformListing &_lhs,
                const ListingPromise::NonUniformListing &_rhs) noexcept;
bool operator==(const ListingPromise::NonUniformListing::PerVFS &_lhs,
                const ListingPromise::NonUniformListing::PerVFS &_rhs) noexcept;
bool operator!=(const ListingPromise::NonUniformListing::PerVFS &_lhs,
                const ListingPromise::NonUniformListing::PerVFS &_rhs) noexcept;
bool operator==(const ListingPromise& _lhs, const ListingPromise &_rhs) noexcept;
bool operator!=(const ListingPromise& _lhs, const ListingPromise &_rhs) noexcept;
    
}