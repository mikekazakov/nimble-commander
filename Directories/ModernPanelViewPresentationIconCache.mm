//
//  ModernPanelViewPresentationIconCache.cpp
//  Files
//
//  Created by Michael G. Kazakov on 22.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <pthread.h>
#import <Quartz/Quartz.h>
#import "ModernPanelViewPresentationIconCache.h"
#import "PanelData.h"
#import "Common.h"

ModernPanelViewPresentationIconCache::ModernPanelViewPresentationIconCache(ModernPanelViewPresentation *_presentation, int _icon_size):
    m_ParentDir(nil),
    m_Presentation(_presentation),
    m_IconsAmount(0),
    m_LoadIconsRunning(false),
    m_LoadIconShouldStop(nullptr),
    m_NeedsLoading(false),
    m_GenericFileIcon(nil),
    m_GenericFolderIcon(nil),
    m_IconSize(NSMakeRect(0, 0, _icon_size, _icon_size))
{
    pthread_mutex_init(&m_Lock, NULL);
    m_LoadIconsGroup = dispatch_group_create();
        
    BuildGenericIcons();
}
    
ModernPanelViewPresentationIconCache::~ModernPanelViewPresentationIconCache()
{
    ClearIcons();
        
    dispatch_group_wait(m_LoadIconsGroup, 5*USEC_PER_SEC);
        
    pthread_mutex_destroy(&m_Lock);
    
    dispatch_release(m_LoadIconsGroup);
}

void ModernPanelViewPresentationIconCache::BuildGenericIcons()
{
    // Load predefined directory icon.
    NSImage *image = [NSImage imageNamed:NSImageNameFolder];
    m_GenericFolderIcon = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
    
    // Load predefined generic document file icon.
    image = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kGenericDocumentIcon)];
    m_GenericFileIcon = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
}

void ModernPanelViewPresentationIconCache::SetIconMode(int _mode)
{
    assert(_mode >= 0 && _mode < IconModesCount);
    m_IconMode = (IconMode)_mode;
}
    
bool ModernPanelViewPresentationIconCache::IsNeedsLoading()
{
    return m_NeedsLoading;
}

NSImageRep *ModernPanelViewPresentationIconCache::CreateIcon(const DirectoryEntryInformation &_item, int _item_index, PanelData *_data)
{
    // If item has no associated icon, then create entry for the icon and schedule the loading process.
    assert(_item.cicon == 0);
    assert(&_data->EntryAtRawPosition(_item_index) == &_item);
    unsigned short index = (unsigned short)(m_UniqueIcons.size() + 1);
    _data->CustomIconSet(_item_index, index);
        
    bool only_generic_icons = m_IconMode == IconMode::IconModeGeneric;
    UniqueIcon icon;
    if (_item.isdir())
        icon.image = m_GenericFolderIcon;
    else if (only_generic_icons || !_item.hasextension())
        icon.image = m_GenericFileIcon;
    else
    {
        NSString *ext = [NSString stringWithUTF8String:_item.extensionc()];
        NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:ext];
        icon.image = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
    }
        
    if (only_generic_icons)
    {
        icon.item_path = nil;
        icon.try_create_thumbnail = false;
    }
    else
    {
        icon.item_path = (_item.isdotdot() ? @"." : [(__bridge NSString *)_item.cf_name copy]);
        icon.try_create_thumbnail = (_item.size < 256*1024*1024); // size less than 256 MB.
        m_NeedsLoading = true;
    }
    
    icon.built_using_thumbnail = false;
        
    m_UniqueIcons.push_back(icon);
    ++m_IconsAmount;
        
    return icon.image;
}

NSImageRep *ModernPanelViewPresentationIconCache::GetIcon(const DirectoryEntryInformation &_item)
{
    assert(_item.cicon);
    unsigned short index = _item.cicon - 1;
    assert(index < m_UniqueIcons.size());
    return m_UniqueIcons[index].image;
}
    
void ModernPanelViewPresentationIconCache::RunLoadThread(PanelData *_data)
{
    m_NeedsLoading = false;
    
    // Nothing to load if only generic icons are used.
    if (m_IconMode == IconModeGeneric) return;
        
    pthread_mutex_lock(&m_Lock);
        
    if (m_LoadIconsRunning)
    {
        pthread_mutex_unlock(&m_Lock);
        return;
    }
        
    // Start loading thread.
        
    // Find the first not loaded icon.
    int start = 0;
    for (auto i = m_UniqueIcons.begin(), end = m_UniqueIcons.end(); i != end; ++start, ++i)
        if (i->item_path) break;
    assert(m_UniqueIcons[start].item_path);
        
    if (!m_ParentDir)
    {
        char buff[1024] = {0};
        _data->GetDirectoryPathWithTrailingSlash(buff);
        m_ParentDir = [NSString stringWithUTF8String:buff];
    }
        
    NSString *parent_dir = m_ParentDir;
    bool load_thumbnails = (m_IconMode == IconModeFileIconsThumbnails);

    m_LoadIconShouldStop = false;
    m_LoadIconsRunning = true;
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_block_t block =
    ^{
        // for debug only, to see some fancy and strange things happen
        auto pthis = this;
        auto current_size = m_UniqueIcons.size();
        
        uint64_t last_draw_time = GetTimeInNanoseconds();
        int i = start;
            
        UniqueIcon *icon = nullptr;
        NSString *item_path;
        bool try_create_thumbnail;
        NSImage *image;
            
        for (;;)
        {
            // While lock is aqcuired, check that block needs to stop and get the next icon.
            pthread_mutex_lock(&m_Lock);
                
            if (m_LoadIconShouldStop)
            {
                pthread_mutex_unlock(&m_Lock);
                break;
            }
                
            if (icon)
            {
                // Apply the image we acquired during last iteration.
                icon->built_using_thumbnail = true;
                icon->image = [image bestRepresentationForRect:m_IconSize context:nil hints:nil];
                icon->item_path = nil;
            }
                
            // Check if icons are exhausted.
            assert(i <= m_IconsAmount);
            if (i == m_IconsAmount)
            {
                dispatch_async(dispatch_get_main_queue(), ^{ m_Presentation->SetViewNeedsDisplay(); });
                m_LoadIconsRunning = false;
                pthread_mutex_unlock(&m_Lock);
                break;
            }
            
            assert(i < m_UniqueIcons.size());
            icon = &m_UniqueIcons[i++];
            assert(icon->item_path); // this bitchy assert appeared sometimes. hope that setting m_LoadIconsRunning to false below fixed it
            item_path = icon->item_path;
            try_create_thumbnail = icon->try_create_thumbnail;

//            pthread_mutex_unlock(&m_Lock);
            item_path = [parent_dir stringByAppendingString:item_path];
            
            CGImageRef thumbnail = NULL;
            if (load_thumbnails && try_create_thumbnail)
            {
                CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:item_path];
                void *keys[] = {(void*)kQLThumbnailOptionIconModeKey};
                void *values[] = {(void*)kCFBooleanTrue};
                CFDictionaryRef dict = CFDictionaryCreate(CFAllocatorGetDefault(), (const void**)keys, (const void**)values, 1, 0, 0);
                thumbnail = QLThumbnailImageCreate(CFAllocatorGetDefault(), url, m_IconSize.size, dict);
                CFRelease(dict);
            }
            
            pthread_mutex_unlock(&m_Lock);
            
            if (thumbnail != NULL)
            {
                image = [[NSImage alloc] initWithCGImage:thumbnail size:m_IconSize.size];
                CGImageRelease(thumbnail);
            }
            else
            {
                image = [[NSWorkspace sharedWorkspace] iconForFile:item_path];
            }

            if (m_LoadIconShouldStop)
            {
                m_LoadIconsRunning = false;                
                break;
            }
            
            uint64_t curtime = GetTimeInNanoseconds();
            if (curtime - last_draw_time > 500*NSEC_PER_MSEC)
            {
                dispatch_async(dispatch_get_main_queue(), ^{ m_Presentation->SetViewNeedsDisplay(); });
                last_draw_time = curtime;
            }
        }
    };
        
    dispatch_group_async(m_LoadIconsGroup, queue, block);
        
    pthread_mutex_unlock(&m_Lock);
}
    
void ModernPanelViewPresentationIconCache::OnDirectoryChanged(PanelData *_data)
{
    ClearIcons();
    m_ParentDir = nil;
}

void ModernPanelViewPresentationIconCache::ClearIcons()
{
    if (m_LoadIconsRunning)
    {
        pthread_mutex_lock(&m_Lock);
        if (m_LoadIconsRunning)
        {
            m_LoadIconShouldStop = true;
//            m_LoadIconsRunning = false;
        }
        pthread_mutex_unlock(&m_Lock);
    }
        
    m_IconsAmount = 0;
    m_UniqueIcons.clear();
}

void ModernPanelViewPresentationIconCache::SetIconSize(int _size)
{
    if((int)m_IconSize.size.width == _size) return;
    m_IconSize = NSMakeRect(0, 0, _size, _size);
    BuildGenericIcons();
}