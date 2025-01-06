// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <NimbleCommander/States/MainWindowStateProtocol.h>

#include <string>
#include <filesystem>
#include <span>

namespace nc::utility {
class ActionsShortcutsManager;
class NativeFSManager;
} // namespace nc::utility

namespace nc::term {
class ShellTask;
}

@interface NCTermShellState : NSView <NCMainWindowState>

@property(nonatomic, readonly) bool isAnythingRunning;

- (instancetype)initWithFrame:(NSRect)frameRect NS_UNAVAILABLE;
- (instancetype)initWithFrame:(NSRect)frameRect
              nativeFSManager:(nc::utility::NativeFSManager &)_native_fs_man
      actionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_actions_shortcuts_manager;

- (std::string)initialWD;
- (void)setInitialWD:(const std::string &)_wd;

- (void)chDir:(const std::string &)_new_dir;
- (void)execute:(const char *)_binary_name at:(const char *)_binary_dir;
- (void)execute:(const char *)_binary_name at:(const char *)_binary_dir parameters:(const char *)_params;

- (void)executeWithFullPath:(const std::filesystem::path &)_binary_path
               andArguments:(std::span<const std::string>)_params;

- (void)terminate;

- (std::string)cwd;

- (nc::term::ShellTask &)task;

@end
