#include "MainWindowStateProtocol.h"

class VFSHost;
@class OperationsController;
@class MainWindowFilePanelState;
@class MainWindowTerminalState;

namespace nc::ops {
    class Pool;
    class Operation;
}

@interface MainWindowController : NSWindowController <NSWindowDelegate, NSWindowRestoration>

- (instancetype) initDefaultWindow;
- (instancetype) initWithLastOpenedWindowOptions;
- (instancetype) initRestoringLastWindowFromConfig;

- (OperationsController*) OperationsController;

// Window state manipulations
- (void)ResignAsWindowState:(id)_state;

- (void)RequestBigFileView:(string)_filepath with_fs:(shared_ptr<VFSHost>) _host;

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

- (void)restoreDefaultWindowStateFromConfig;
- (void)restoreDefaultWindowStateFromLastOpenedWindow;
+ (bool)canRestoreDefaultWindowStateFromLastOpenedWindow;

// Access to states
@property (nonatomic, readonly) MainWindowFilePanelState*   filePanelsState;  // one and only one per window
@property (nonatomic, readonly) MainWindowTerminalState*    terminalState;    // zero or one per window
@property (nonatomic, readonly) id<MainWindowStateProtocol> topmostState;
@property (nonatomic, readonly) nc::ops::Pool&              operationsPool;


// Toolbar support
- (void)OnShowToolbar:(id)sender;

+ (MainWindowController*)lastFocused;

- (void)enqueueOperation:(const shared_ptr<nc::ops::Operation> &)_operation;

@end
