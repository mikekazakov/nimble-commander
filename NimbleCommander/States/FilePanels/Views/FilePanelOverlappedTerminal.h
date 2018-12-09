// Copyright (C) 2015-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Term/ShellTask.h>
#include <Term/View.h>

@interface FilePanelOverlappedTerminal : NSView

- (double) bottomGapForLines:(int)_lines_amount;
- (int) totalScreenLines;
- (void) runShell:(const std::string&)_initial_wd; // if _initital_wd is empty - use home directory
- (void) focusTerminal;
- (void) changeWorkingDirectory:(const std::string&)_new_dir;
- (void) feedShellWithInput:(const std::string&)_input;
- (void) commitShell;
- (void) runPasteMenu:(const std::vector<std::string>&)_strings;

- (bool) canFeedShellWithKeyDown:(NSEvent *)event;
- (bool) feedShellWithKeyDown:(NSEvent *)event;

@property (nonatomic, readonly) nc::term::ShellTask::TaskState state;
@property (nonatomic, readonly) NCTermView *termView;

/**
 * tries to understand if Bash shell has something entered awaiting for Enter hit.
 * will return false if state is not Shell
 */
@property (nonatomic, readonly) bool isShellVirgin;
@property (nonatomic) std::function<void()> onShellCWDChanged;
@property (nonatomic) std::function<void()> onLongTaskStarted;
@property (nonatomic) std::function<void()> onLongTaskFinished;
@property (nonatomic, readonly) std::string cwd;

@end
