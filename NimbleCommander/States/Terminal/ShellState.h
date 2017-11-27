// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/States/MainWindowStateProtocol.h>

namespace nc::term {
    class ShellTask;
}

@interface NCTermShellState : NSView<NCMainWindowState>

@property (nonatomic, readonly) bool isAnythingRunning;

- (string)initialWD;
- (void) setInitialWD:(const string&)_wd;

- (void) chDir:(const string&)_new_dir;
- (void) execute:(const char *)_binary_name
              at:(const char*)_binary_dir;
- (void) execute:(const char *)_binary_name
              at:(const char*)_binary_dir
      parameters:(const char*)_params;

- (void) executeWithFullPath:(const char *)_path parameters:(const char*)_params;

- (void) terminate;

- (string) cwd;

- (nc::term::ShellTask&) task;

@end
