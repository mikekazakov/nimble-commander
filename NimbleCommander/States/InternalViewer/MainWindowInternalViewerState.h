//
//  MainWindowInternalViewerState.h
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 8/10/16.
//  Copyright © 2016 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <VFS/VFS.h>
#include "../../Files/MainWindowStateProtocol.h"
#include "../../Viewer/BigFileView.h"
#include "../../Viewer/InternalViewerToolbarProtocol.h"

@interface MainWindowInternalViewerState : NSViewController<MainWindowStateProtocol>

- (bool)openFile:(const string&)_path atVFS:(const VFSHostPtr&)_host;

@end
