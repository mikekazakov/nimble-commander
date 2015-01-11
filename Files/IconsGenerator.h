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

class IconsGenerator : public enable_shared_from_this<IconsGenerator>
{
public:
    IconsGenerator();
    ~IconsGenerator();
    
    void SetUpdateCallback( function<void()> _callback ); // callback will be executed in background thread
    void SetIconMode(int _mode);
    void SetIconSize(int _size);
    int IconSize() { return m_IconSize.size.height; }
    
    NSImageRep *ImageFor(unsigned _no, VFSListing &_listing);
    void Flush(); // should be called on every directory changes thus loosing generating icons' ID
    
    enum IconMode
    {
        IconModeGeneric = 0,
        IconModeFileIcons,
        IconModeFileIconsThumbnails,
        IconModesCount
    };
    
private:
    enum {MaxIcons = 65535,
        MaxFileSizeForThumbnailNative = 256*1024*1024,
        MaxFileSizeForThumbnailNonNative = 1*1024*1024 // ?
    };

    
    
    struct Meta
    {
        uint64_t    file_size;
        mode_t      unix_mode;
        string extension;
        string relative_path;
        shared_ptr<VFSHost> host;
        
        NSImageRep *generic;   // just folder or document icon
        
        NSImageRep *filetype;  // icon generated from file's extension or taken from a bundle
        
        NSImageRep *thumbnail; // the best - thumbnail generated from file's content
        
        
    };
    
    map<unsigned short, shared_ptr<Meta>> m_Icons;
    unsigned int m_LastIconID = 0;
    NSRect m_IconSize = NSMakeRect(0, 0, 16, 16);

    
    NSImage *m_GenericFileIconImage;
    NSImage *m_GenericFolderIconImage;
    NSImageRep *m_GenericFileIcon;
    NSImageRep *m_GenericFolderIcon;
    NSBitmapImageRep *m_GenericFileIconBitmap;
    NSBitmapImageRep *m_GenericFolderIconBitmap;

    DispatchGroup    m_WorkGroup{DispatchGroup::Background};    // working queue is concurrent
    dispatch_queue   m_ControlQueue{__FILES_IDENTIFIER__".IconsGenerator.control_queue"};
    
    atomic_int       m_StopWorkQueue{0};
    int              m_IconsMode = IconModeFileIconsThumbnails;
    function<void()> m_UpdateCallback;
    
    void BuildGenericIcons();
    void Runner(shared_ptr<Meta> _meta, shared_ptr<IconsGenerator> _guard);
    void StopWorkQueue();
    
    
    mutex                    m_ExtensionIconsCacheLock;
    map<string, NSImageRep*> m_ExtensionIconsCache;
    
    
    // denied! (c) Quake3
    IconsGenerator(const IconsGenerator&) = delete;
    void operator=(const IconsGenerator&) = delete;
};
