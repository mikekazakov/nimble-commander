// Copyright (C) 2015-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Cocoa/Cocoa.h>

@interface NCSheetWithHotkeys : NSWindow

@property(strong, nonatomic) void (^onCtrlA)();
@property(strong, nonatomic) void (^onCtrlB)();
@property(strong, nonatomic) void (^onCtrlC)();
@property(strong, nonatomic) void (^onCtrlD)();
@property(strong, nonatomic) void (^onCtrlE)();
@property(strong, nonatomic) void (^onCtrlF)();
@property(strong, nonatomic) void (^onCtrlG)();
@property(strong, nonatomic) void (^onCtrlH)();
@property(strong, nonatomic) void (^onCtrlI)();
@property(strong, nonatomic) void (^onCtrlJ)();
@property(strong, nonatomic) void (^onCtrlK)();
@property(strong, nonatomic) void (^onCtrlL)();
@property(strong, nonatomic) void (^onCtrlM)();
@property(strong, nonatomic) void (^onCtrlN)();
@property(strong, nonatomic) void (^onCtrlO)();
@property(strong, nonatomic) void (^onCtrlP)();
@property(strong, nonatomic) void (^onCtrlQ)();
@property(strong, nonatomic) void (^onCtrlR)();
@property(strong, nonatomic) void (^onCtrlS)();
@property(strong, nonatomic) void (^onCtrlT)();
@property(strong, nonatomic) void (^onCtrlU)();
@property(strong, nonatomic) void (^onCtrlV)();
@property(strong, nonatomic) void (^onCtrlW)();
@property(strong, nonatomic) void (^onCtrlX)();
@property(strong, nonatomic) void (^onCtrlY)();
@property(strong, nonatomic) void (^onCtrlZ)();

- (void (^)())makeActionHotkey:(SEL)_action;
- (void (^)())makeFocusHotkey:(NSView *)_target;
- (void (^)())makeClickHotkey:(NSControl *)_target;

@end
