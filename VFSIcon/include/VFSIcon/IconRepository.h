// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>

namespace nc::vfsicon {

/**
 * IconRepository assumes a single thread affinity.
 * This means that client(s) should call it from one thread only, presumably from a main thread
 * only.
 */
class IconRepository
{
public:
    virtual ~IconRepository() = default;
    
    using SlotKey = uint16_t;
    
    static inline const SlotKey InvalidKey = SlotKey{0};   
    
    /**
     * Checks whether _key refers to a valid slot. A key which is equal to InvalidKey is always
     * invalid.
     */
    virtual bool IsValidSlot( SlotKey _key ) const = 0;
    
    /**
     * Returns the icon currently available for the given slot.
     * This function does no blocking I/O.
     */ 
    virtual NSImage *AvailableIconForSlot( SlotKey _key ) const = 0;
    
    /**
     * Returns an icon for VFS item in case when it's not possible to register this item at first
     * (for instance when IconRegistry is full).
     * This function does no blocking I/O.
     */
    virtual NSImage *AvailableIconForListingItem( const VFSListingItem &_item ) const = 0;
    
    /**
     * Creates an entry corresponding to the VFS item.
     * Retrieves a preliminary icon for this item, without any deep scan and/or I/O.
     * May return InvalidKey, which means that the item was not registered in IconRepository.
     * Does not hold any references to the underlying VFS Listing or VFS Host.
     */
    virtual SlotKey Register( const VFSListingItem &_item ) = 0;
    
    /**
     * Returns a list of all used registered slots.
     * The result will be sorted in ascending order.
     */
    virtual std::vector<SlotKey> AllSlots() const = 0;
    
    /**
     * Removes a registry entity corresponding to _key. _key becomes invalid afterwards.
     */
    virtual void Unregister( SlotKey _key ) = 0;
    
    /**
     * Request the IconRepository to perform a full-weight icon production for the VFS item.
     * The production be async in a background thread.
     * The correponding entry may be updated with the new icon after the background production
     * finishes.
     * The UpdateCallback will be executed if the icon was updated in result.
     */
    virtual void ScheduleIconProduction(SlotKey _key, const VFSListingItem &_item) = 0;

    /**
     * Sets a callback which will be executed when a registry entry receives an updated icon after
     * the background icon production.
     * The callback will be executed in the same thread client calls the IconRepository.
     */
    virtual void SetUpdateCallback( std::function<void(SlotKey, NSImage*)> _on_icon_updated ) = 0;
    
    /**
     * Sets a hint about physical pixel-wise dimensions of produced icons.
     * This is not a request, only a hint.
     * Also, the caller should not rely on .size property of returned images and it should do a
     * copy and manually set a desired size of that copied image.  
     */
    virtual void SetPxSize( int _px_size ) = 0;
};
    
}
