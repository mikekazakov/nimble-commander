// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS_fwd.h>
#include <Habanero/StringsBulk.h>
#include <NimbleCommander/Core/VFSInstancePromise.h>
#include <variant>

namespace nc::panel {
    
class ListingPromise
{
public:
    struct UniformListing
    {
        core::VFSInstancePromise promise;
        std::string directory;
    };
    
    struct NonUniformListing
    {
        struct PerVFS
        {
            core::VFSInstancePromise promise;
            std::vector<nc::base::StringsBulk> entries;
        };
        std::vector<PerVFS> per_vfs;
        
        size_t EntriesCount() const noexcept;
    };
    
    using StorageT = std::variant<UniformListing, NonUniformListing>;
    using VFSPromiseAdapter =
        std::function<core::VFSInstancePromise(const std::shared_ptr<VFSHost>&)>;
    using PromiseVFSAdapter =
        std::function<std::shared_ptr<VFSHost>(const core::VFSInstancePromise&)>;
    
    ListingPromise( const VFSListing &_listing, const VFSPromiseAdapter &_adapter );
    ListingPromise( const ListingPromise&) = default;
    ListingPromise( ListingPromise&& ) = default;

    ListingPromise &operator=(const ListingPromise &) = default;
    ListingPromise &operator=(ListingPromise &&) = default;

    // may throw VFSErrorException or return nullptr
    VFSListingPtr Restore(unsigned long _fetch_flags,
                          const PromiseVFSAdapter &_adapter,
                          const std::function<bool()> &_cancel_checker) const;

    const StorageT &Description() const noexcept;
    
private:
    friend bool operator==(const ListingPromise& _lhs, const ListingPromise &_rhs) noexcept;
    
    VFSListingPtr RestoreUniform(unsigned long _fetch_flags,
                                 const PromiseVFSAdapter &_adapter,
                                 const std::function<bool()> &_cancel_checker) const;
    VFSListingPtr RestoreNonUniform(unsigned long _fetch_flags,
                                    const PromiseVFSAdapter &_adapter,
                                    const std::function<bool()> &_cancel_checker) const;
    static NonUniformListing FromNonUniformListing(const VFSListing &_listing,
                                                   const VFSPromiseAdapter &_adapter);
    static UniformListing FromUniformListing(const VFSListing &_listing,
                                             const VFSPromiseAdapter &_adapter);
    const StorageT &Storage() const noexcept;

    std::shared_ptr<const StorageT> m_Storage;
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
