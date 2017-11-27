// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "MainWindowStateProtocol.h"
#include <VFS/VFS.h>

@class OperationsController;
@class MainWindowFilePanelState;
@class NCTermShellState;

namespace nc::ops {
    class Pool;
    class Operation;
}

@interface MainWindowController : NSWindowController <NSWindowDelegate, NSWindowRestoration>

- (instancetype) initDefaultWindow;
- (instancetype) initWithLastOpenedWindowOptions;
- (instancetype) initRestoringLastWindowFromConfig;

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
- (void)restoreDefaultWindowStateFromLastOpenedWindow;
+ (bool)canRestoreDefaultWindowStateFromLastOpenedWindow;

// Access to states
@property (nonatomic, readonly) MainWindowFilePanelState*   filePanelsState;  // one and only one per window
@property (nonatomic, readonly) NCTermShellState*           terminalState;    // zero or one per window
@property (nonatomic, readonly) id<NCMainWindowState>       topmostState;
@property (nonatomic, readonly) nc::ops::Pool&              operationsPool;


// Toolbar support
- (void)OnShowToolbar:(id)sender;

+ (MainWindowController*)lastFocused;

- (void)enqueueOperation:(const shared_ptr<nc::ops::Operation> &)_operation;
- (void)beginSheet:(NSWindow *)sheetWindow completionHandler:(void (^)(NSModalResponse rc))handler;

@end
