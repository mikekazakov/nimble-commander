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
#import "VFS.h"

@class OperationsController;
@class MainWindowFilePanelState;
@class MainWindowTerminalState;

@interface MainWindowController : NSWindowController <NSWindowDelegate, NSWindowRestoration>

- (OperationsController*) OperationsController;

- (void)ApplySkin:(ApplicationSkin)_skin;

// Window state manipulations
- (void)ResignAsWindowState:(id)_state;
- (void)RequestBigFileView:(string)_filepath with_fs:(shared_ptr<VFSHost>) _host;
- (void)RequestTerminal:(const char*)_cwd;
- (void)RequestTerminalExecution:(const char*)_filename at:(const char*)_cwd;
- (void)RequestExternalEditorTerminalExecution:(const string&)_full_app_path
                                        params:(const string&)_params
                                          file:(const string&)_file_path;

// Access to states
@property (nonatomic, readonly) MainWindowFilePanelState* FilePanelState; // one and only one per window
@property (nonatomic, readonly) MainWindowTerminalState* TerminalState;// zero or one per window

@end
