//
//  MainWindowController.h
//  Directories
//
//  Created by Michael G. Kazakov on 09.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "chained_strings.h"
#import "ApplicationSkins.h"
#import "vfs/VFS.h"
#import "MainWindowStateProtocol.h"

@class OperationsController;
@class MainWindowFilePanelState;
@class MainWindowTerminalState;

@interface MainWindowController : NSWindowController <NSWindowDelegate, NSWindowRestoration>

- (OperationsController*) OperationsController;

// Window state manipulations
- (void)ResignAsWindowState:(id)_state;
- (void)RequestBigFileView:(string)_filepath with_fs:(shared_ptr<VFSHost>) _host;
- (void)RequestTerminal:(const string&)_cwd;
- (void)RequestTerminalExecution:(const char*)_filename at:(const char*)_cwd;
- (void)RequestExternalEditorTerminalExecution:(const string&)_full_app_path
                                        params:(const string&)_params
                                          file:(const string&)_file_path;

- (void)restoreDefaultWindowStateFromConfig;
- (void)restoreDefaultWindowStateFromLastOpenedWindow;

// Access to states
@property (nonatomic, readonly) MainWindowFilePanelState*   filePanelsState;  // one and only one per window
@property (nonatomic, readonly) MainWindowTerminalState*    terminalState;    // zero or one per window
@property (nonatomic, readonly) id<MainWindowStateProtocol> topmostState;

// Toolbar support
@property (nonatomic, readonly) bool toolbarVisible;
- (void)OnShowToolbar:(id)sender;

@end
