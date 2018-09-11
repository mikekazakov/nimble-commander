// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Habanero/DispatchGroup.h>
#include <VFSIcon/IconBuilder.h>

namespace nc::panel {

namespace data {
    struct ItemVolatileData;
    class Model;
}

class IconsGenerator2
{
public:
    IconsGenerator2(const std::shared_ptr<vfsicon::IconBuilder> &_icon_builder);
    ~IconsGenerator2();
    
    // callback will be executed in main thread
    void SetUpdateCallback( function<void(uint16_t, NSImage*)> _callback );

    int IconSize() const noexcept;
    void SetIconSize( int _size );
        
    // TODO: remove the DPI notion from this class
    bool HiDPI() const noexcept;
    void SetHiDPI( bool _is_hi_dpi );
    
    // do not rely on .size of this image, it may not respect scale factor.
    NSImage *ImageFor( const VFSListingItem &_item, data::ItemVolatileData &_item_vd );
    
    /**
     * WRITE!!!!
     */
    NSImage *AvailableImageFor(const VFSListingItem &_item, data::ItemVolatileData _item_vd ) const;

    void SyncDiscardedAndOutdated( nc::panel::data::Model &_pd );
      
private:
    enum {MaxIcons = 65535,
        MaxStashedRequests = 256
    };

    struct IconStorage
    {
        uint64_t    file_size;
        time_t      mtime;
        NSImage    *generic;   // just folder or document icon
        NSImage    *filetype;  // icon generated from file's extension or taken from a bundle
        NSImage    *thumbnail; // the best - thumbnail generated from file's content
        NSImage    *Any() const;
    };
    
    struct BuildRequest
    {
        unsigned long generation;
        VFSListingItem item;
        NSImage    *filetype;  // icon generated from file's extension or taken from a bundle
        NSImage    *thumbnail; // the best - thumbnail generated from file's content
        unsigned short icon_number;
    };
        
    unsigned short GetSuitablePositionForNewIcon();
    bool IsFull() const;
    bool IsRequestsStashFull() const;
    int IconSizeInPixels() const noexcept;    
    
    void RunOrStash( BuildRequest _req );
    void DrainStash();
    void BackgroundWork(const BuildRequest &_req);
    IconsGenerator2(const IconsGenerator2&) = delete;
    void operator=(const IconsGenerator2&) = delete;
    
    vector< optional<IconStorage> > m_Icons;
    int                     m_IconsHoles = 0;
    
    int                     m_IconSize = 16;
    int                     m_IconSizePx = 32;    
    bool                    m_HiDPI = true;

    atomic_ulong            m_Generation{0};
    DispatchGroup           m_WorkGroup{DispatchGroup::Low};
    function<void(uint16_t, NSImage*)>m_UpdateCallback;
    
    mutable spinlock        m_RequestsStashLock;
    queue<BuildRequest>     m_RequestsStash;
    
    std::shared_ptr<vfsicon::IconBuilder> m_IconBuilder;    
};

}
