//
//  MainWindowBigFileViewState.h
//  Files
//
//  Created by Michael G. Kazakov on 04.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "MainWindowStateProtocol.h"
#include "BigFileView.h"
#include "vfs/VFS.h"

@interface MainWindowBigFileViewState : NSView<MainWindowStateProtocol, BigFileViewDelegateProtocol, NSTextFieldDelegate, NSToolbarDelegate, NSSearchFieldDelegate>

- (bool) OpenFile: (const char*) _fn with_fs:(shared_ptr<VFSHost>) _host;

+ (int) fileWindowSize;

@end
