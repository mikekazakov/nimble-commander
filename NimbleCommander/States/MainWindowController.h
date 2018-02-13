// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "MainWindowStateProtocol.h"
#include <VFS/VFS.h>

@class OperationsController;
@class MainWindowFilePanelState;
@class NCTermShellState;
@class NCMainWindow;

namespace nc::ops {
    class Pool;
    class Operation;
}

@interface NCMainWindowController : NSWindowController <NSWindowDelegate, NSWindowRestoration>

- (instancetype) initWithWindow:(NCMainWindow*)window;

// Window state manipulations
- (void)ResignAsWindowState:(id)_state;

- (void)requestViewerFor:(string)_filepath at:(shared_ptr<VFSHost>) _host;

- (void)requestTerminal:(const string&)_cwd;
- (void)requestTerminalExecution:(const char*)_filename
                              at:(const char*)_cwd;
- (void)requestTerminalExecution:(const char*)_filename
                              at:(const char*)_cwd
                  withParameters:(const char*)_params;
- (void)requestTerminalExecutionWithFullPath:(const char*)_binary_path
                              withParameters:(const char*)_params;

- (void)RequestExternalEditorTerminalExecution:(const string&)_full_app_path
                                        params:(const string&)_params
                                     fileTitle:(const string&)_file_title;

- (bool)restoreDefaultWindowStateFromConfig;
+ (bool)restoreDefaultWindowStateFromConfig:(MainWindowFilePanelState*)_state;
- (void)restoreDefaultWindowStateFromLastOpenedWindow;
+ (bool)canRestoreDefaultWindowStateFromLastOpenedWindow;

// Access to states
@property (nonatomic, readwrite) MainWindowFilePanelState*  filePanelsState;  // one and only one per window
@property (nonatomic, readonly) NCTermShellState*           terminalState;    // zero or one per window
@property (nonatomic, readonly) id<NCMainWindowState>       topmostState;
@property (nonatomic, readonly) nc::ops::Pool&              operationsPool;

- (void)setOperationsPool:(nc::ops::Pool&)_pool;

// Toolbar support
- (void)OnShowToolbar:(id)sender;

+ (NCMainWindowController*)lastFocused;

- (void)enqueueOperation:(const shared_ptr<nc::ops::Operation> &)_operation;
- (void)beginSheet:(NSWindow *)sheetWindow completionHandler:(void (^)(NSModalResponse rc))handler;

@end
