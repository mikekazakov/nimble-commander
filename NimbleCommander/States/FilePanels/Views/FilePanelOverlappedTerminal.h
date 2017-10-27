// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Term/ShellTask.h>

@interface FilePanelOverlappedTerminal : NSView

- (double) bottomGapForLines:(int)_lines_amount;
- (int) totalScreenLines;
- (void) runShell:(const string&)_initial_wd; // if _initital_wd is empty - use home directory
- (void) focusTerminal;
- (void) changeWorkingDirectory:(const string&)_new_dir;
- (void) feedShellWithInput:(const string&)_input;
- (void) commitShell;
- (void) runPasteMenu:(const vector<string>&)_strings;

- (bool) canFeedShellWithKeyDown:(NSEvent *)event;
- (bool) feedShellWithKeyDown:(NSEvent *)event;

@property (nonatomic, readonly) nc::term::ShellTask::TaskState state;

/**
 * tries to understand if Bash shell has something entered awaiting for Enter hit.
 * will return false if state is not Shell
 */
@property (nonatomic, readonly) bool isShellVirgin;
@property (nonatomic) function<void()> onShellCWDChanged;
@property (nonatomic) function<void()> onLongTaskStarted;
@property (nonatomic) function<void()> onLongTaskFinished;
@property (nonatomic, readonly) string cwd;

@end
