//
//  PanelDragPasteboardItem.h
//  Files
//
//  Created by Michael G. Kazakov on 26.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include <string>
#include "VFS.h"

using namespace std;

@interface PanelDraggingItem : NSPasteboardItem

- (void) SetFilename:(string)_str;
- (string) Filename;

- (void) SetPath:(string)_str;
- (string) Path;

- (void) SetVFS:(shared_ptr<VFSHost>)_vfs;
- (shared_ptr<VFSHost>) VFS;


- (bool) IsValid;
- (void) Clear;

@end
