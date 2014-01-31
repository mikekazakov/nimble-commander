//
//  PanelDragPasteboardItem.m
//  Files
//
//  Created by Michael G. Kazakov on 26.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "PanelDraggingItem.h"

@implementation PanelDraggingItem
{
    string              m_Filename;
    string              m_Path;
    shared_ptr<VFSHost> m_VFS;
    
    
}

- (id) init
{
    self = [super init];
    if(self) {
    }
    return self;
}


- (void) dealloc
{

}

- (void) SetPath:(string)_str
{
    m_Path = _str;
}

- (string) Path
{
    return m_Path;
}

- (void) SetFilename:(string)_str
{
    m_Filename = _str;
}

- (string) Filename
{
    return m_Filename;
}

- (void) SetVFS:(shared_ptr<VFSHost>)_vfs
{
    m_VFS = _vfs;
}

- (shared_ptr<VFSHost>) VFS
{
    return m_VFS;
}

- (bool) IsValid
{
    return bool(m_VFS);
}

- (void) Clear
{
    m_VFS.reset();
}


@end
