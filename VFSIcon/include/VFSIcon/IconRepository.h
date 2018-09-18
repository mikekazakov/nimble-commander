// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>

namespace nc::vfsicon {
    
class IconRepository
{
public:
    virtual ~IconRepository() = default;
    
    using SlotKey = uint16_t;
    static inline const SlotKey InvalidKey = SlotKey{0};   
    
    virtual bool IsValidSlot( SlotKey _key ) const = 0;
    virtual NSImage *AvailableIconForSlot( SlotKey _key ) const = 0;
    virtual NSImage *AvailableIconForListingItem( const VFSListingItem &_item ) const = 0;
    
    virtual SlotKey Register( const VFSListingItem &_item ) = 0;
    
    /**
     * Returns a list of all used registered slots.
     * The result will be sorted in ascending order.
     */
    virtual std::vector<SlotKey> AllSlots() const = 0;     
    virtual void Unregister( SlotKey _key ) = 0;
    
    virtual void ScheduleIconProduction(SlotKey _key, const VFSListingItem &_item) = 0;

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
