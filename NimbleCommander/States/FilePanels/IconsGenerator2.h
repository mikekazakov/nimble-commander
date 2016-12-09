//
//  IconsGenerator.h
//  Files
//
//  Created by Michael G. Kazakov on 04.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include <Habanero/DispatchQueue.h>
#include <VFS/VFS.h>

#include "../../../Files/PanelData.h"

class IconsGenerator2
{
public:
    enum class IconMode
    {
        Generic         = 0,
        Icons           = 1,
        Thumbnails      = 2,
        IconModesCount  = 3
    };
        
    IconsGenerator2();
    ~IconsGenerator2();
    
    void SetUpdateCallback( function<void(uint16_t, NSImageRep*)> _callback ); // callback will be executed in main thread
    void SetIconMode(IconMode _mode);
    IconMode GetIconMode() const noexcept { return m_IconsMode; };

    void SetIconSize(int _size);
    int IconSize() const { return m_IconSize; }
    
    NSImageRep *ImageFor(const VFSListingItem &_item, PanelData::VolatileData &_item_vd);

    void SyncDiscardedAndOutdated( PanelData &_pd );
    
private:
    enum {MaxIcons = 65535,
        MaxStashedRequests = 100,
        MaxFileSizeForThumbnailNative = 256*1024*1024,
        MaxFileSizeForThumbnailNonNative = 1*1024*1024 // ?
    };

    struct IconStorage
    {
        uint64_t    file_size;
        time_t      mtime;
        NSImageRep *generic;   // just folder or document icon
        NSImageRep *filetype;  // icon generated from file's extension or taken from a bundle
        NSImageRep *thumbnail; // the best - thumbnail generated from file's content
        NSImageRep *Any() const;
    };
    
    struct BuildRequest
    {
        unsigned long generation;
        uint64_t    file_size;
        mode_t      unix_mode;
        time_t      mtime;
        string      extension;
        string      relative_path;
        VFSHostPtr  host;
        NSImageRep *filetype;  // icon generated from file's extension or taken from a bundle
        NSImageRep *thumbnail; // the best - thumbnail generated from file's content
        unsigned short icon_number;
    };
    
    struct BuildResult
    {
        NSImageRep *filetype;
        NSImageRep *thumbnail;
    };
    
    NSImageRep *GetGenericIcon( const VFSListingItem &_item ) const;
    NSImageRep *GetCachedExtensionIcon( const VFSListingItem &_item ) const;
    unsigned short GetSuitablePositionForNewIcon();
    bool IsFull() const;
    bool IsRequestsStashFull() const;
    
    void BuildGenericIcons();
    
    void RunOrStash( BuildRequest _req );
    void DrainStash();
    void BackgroundWork(const BuildRequest &_req);
    optional<BuildResult> Runner(const BuildRequest &_req);
    IconsGenerator2(const IconsGenerator2&) = delete;
    void operator=(const IconsGenerator2&) = delete;
    
    vector< optional<IconStorage> > m_Icons;
    int                     m_IconsHoles = 0;
    
    int                     m_IconSize = 16;
    IconMode                m_IconsMode = IconMode::Thumbnails;

    atomic_ulong            m_Generation{0};
    DispatchGroup           m_WorkGroup{DispatchGroup::Low};
    function<void(uint16_t, NSImageRep*)>m_UpdateCallback;
    
    NSImageRep             *m_GenericFileIcon;
    NSImageRep             *m_GenericFolderIcon;
    NSBitmapImageRep       *m_GenericFileIconBitmap;
    NSBitmapImageRep       *m_GenericFolderIconBitmap;

    mutable spinlock        m_ExtensionIconsCacheLock;
    map<string,NSImageRep*> m_ExtensionIconsCache;
    
    mutable spinlock        m_RequestsStashLock;
    queue<BuildRequest>     m_RequestsStash;
};
