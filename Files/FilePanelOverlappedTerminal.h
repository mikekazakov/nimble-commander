//
//  FilePanelOverlappedTerminal.h
//  Files
//
//  Created by Michael G. Kazakov on 16/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TermShellTask.h"

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

@property (nonatomic, readonly) TermShellTask::TaskState state;

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
