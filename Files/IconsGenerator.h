//
//  IconsGenerator.h
//  Files
//
//  Created by Michael G. Kazakov on 04.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import "DispatchQueue.h"
#import "VFS.h"

class IconsGenerator
{
public:
    enum class IconMode
    {
        Generic         = 0,
        Icons           = 1,
        Thumbnails      = 2,
        IconModesCount  = 3
    };
        
    IconsGenerator();
    ~IconsGenerator();
    
    void SetUpdateCallback( function<void()> _callback ); // callback will be executed in main thread
    void SetIconMode(IconMode _mode);
    void SetIconSize(int _size);
    int IconSize() const { return m_IconSize.size.height; }
    
    NSImageRep *ImageFor(unsigned _no, VFSListing &_listing);
    void Flush(); // should be called on every directory changes thus loosing generated icons' ID
    
    
private:
    enum {MaxIcons = 65535,
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
    };
    
    struct BuildResult
    {
        NSImageRep *filetype;
        NSImageRep *thumbnail;
    };
    
    vector<IconStorage> m_Icons;
    NSRect m_IconSize = NSMakeRect(0, 0, 16, 16);
    
    NSImageRep *m_GenericFileIcon;
    NSImageRep *m_GenericFolderIcon;
    NSBitmapImageRep *m_GenericFileIconBitmap;
    NSBitmapImageRep *m_GenericFolderIconBitmap;

    DispatchGroup    m_WorkGroup{DispatchGroup::Low};    // working queue is concurrent
    atomic_ulong     m_Generation{0};
    
    IconMode         m_IconsMode = IconMode::Thumbnails;
    function<void()> m_UpdateCallback;
    
    void BuildGenericIcons();
    optional<BuildResult> Runner(const BuildRequest &_req);
    
    mutex                    m_ExtensionIconsCacheLock;
    map<string, NSImageRep*> m_ExtensionIconsCache;
    
    
    // denied! (c) Quake3
    IconsGenerator(const IconsGenerator&) = delete;
    void operator=(const IconsGenerator&) = delete;
};
