// Copyright (C) 2015-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Cocoa/Cocoa.h>

@interface SheetWithHotkeys : NSWindow

@property (strong) void (^onCtrlA)();
@property (strong) void (^onCtrlB)();
@property (strong) void (^onCtrlC)();
@property (strong) void (^onCtrlD)();
@property (strong) void (^onCtrlE)();
@property (strong) void (^onCtrlF)();
@property (strong) void (^onCtrlG)();
@property (strong) void (^onCtrlH)();
@property (strong) void (^onCtrlI)();
@property (strong) void (^onCtrlJ)();
@property (strong) void (^onCtrlK)();
@property (strong) void (^onCtrlL)();
@property (strong) void (^onCtrlM)();
@property (strong) void (^onCtrlN)();
@property (strong) void (^onCtrlO)();
@property (strong) void (^onCtrlP)();
@property (strong) void (^onCtrlQ)();
@property (strong) void (^onCtrlR)();
@property (strong) void (^onCtrlS)();
@property (strong) void (^onCtrlT)();
@property (strong) void (^onCtrlU)();
@property (strong) void (^onCtrlV)();
@property (strong) void (^onCtrlW)();
@property (strong) void (^onCtrlX)();
@property (strong) void (^onCtrlY)();
@property (strong) void (^onCtrlZ)();

- (void (^)()) makeActionHotkey:(SEL)_action;
- (void (^)()) makeFocusHotkey:(NSView*)_target;
- (void (^)()) makeClickHotkey:(NSControl*)_target;

@end

