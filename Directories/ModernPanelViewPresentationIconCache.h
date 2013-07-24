//
//  ModernPanelViewPresentationIconCache.h
//  Files
//
//  Created by Michael G. Kazakov on 22.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "ModernPanelViewPresentation.h"
#import "DirRead.h"

class ModernPanelViewPresentationIconCache
{
public:
    ModernPanelViewPresentationIconCache(ModernPanelViewPresentation *_presentation, int _icon_size);
    ~ModernPanelViewPresentationIconCache();
    void SetIconMode(int _mode);
    bool IsNeedsLoading();
    NSImageRep *CreateIcon(const DirectoryEntryInformation &_item, int _item_index, PanelData *_data);
    NSImageRep *GetIcon(const DirectoryEntryInformation &_item);
    void RunLoadThread(PanelData *_data);
    void OnDirectoryChanged(PanelData *_data);
    
    void SetIconSize(int _size);
    
private:
    void ClearIcons();
    void BuildGenericIcons();
    
    enum IconMode
    {
        IconModeGeneric = 0,
        IconModeFileIcons,
        IconModeFileIconsThumbnails,
        
        IconModesCount
    };
    struct UniqueIcon
    {
        NSImageRep *image;
        NSString *item_path;
        bool try_create_thumbnail;
    };
    typedef std::deque<UniqueIcon> UniqueIconsT;
    
    UniqueIconsT m_UniqueIcons;
    NSRect m_IconSize;
    volatile int m_IconsAmount;
    IconMode m_IconMode;
    
    NSString *m_ParentDir;
    ModernPanelViewPresentation *m_Presentation;
    
    dispatch_group_t m_LoadIconsGroup;
    volatile bool m_LoadIconsRunning;
    volatile bool m_LoadIconShouldStop;
    bool m_NeedsLoading;
    pthread_mutex_t m_Lock;
    
    NSImageRep *m_GenericFileIcon;
    NSImageRep *m_GenericFolderIcon;
};