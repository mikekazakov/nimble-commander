// Copyright (C) 2015-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Carbon/Carbon.h>
#include <Utility/SheetWithHotkeys.h>

@implementation SheetWithHotkeys

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
    if(event.type == NSKeyDown && (event.modifierFlags & NSControlKeyMask) ) {
        auto keycode = event.keyCode;
#define stuff(kk, aa) \
    if( keycode == kk && self.aa ) { \
        self.aa(); \
        return true; \
    }
        stuff(kVK_ANSI_A, onCtrlA);
        stuff(kVK_ANSI_B, onCtrlB);
        stuff(kVK_ANSI_C, onCtrlC);
        stuff(kVK_ANSI_D, onCtrlD);
        stuff(kVK_ANSI_E, onCtrlE);
        stuff(kVK_ANSI_F, onCtrlF);
        stuff(kVK_ANSI_G, onCtrlG);
        stuff(kVK_ANSI_H, onCtrlH);
        stuff(kVK_ANSI_I, onCtrlI);
        stuff(kVK_ANSI_J, onCtrlJ);
        stuff(kVK_ANSI_K, onCtrlK);
        stuff(kVK_ANSI_L, onCtrlL);
        stuff(kVK_ANSI_M, onCtrlM);
        stuff(kVK_ANSI_N, onCtrlN);
        stuff(kVK_ANSI_O, onCtrlO);
        stuff(kVK_ANSI_P, onCtrlP);
        stuff(kVK_ANSI_Q, onCtrlQ);
        stuff(kVK_ANSI_R, onCtrlR);
        stuff(kVK_ANSI_S, onCtrlS);
        stuff(kVK_ANSI_T, onCtrlT);
        stuff(kVK_ANSI_U, onCtrlU);
        stuff(kVK_ANSI_V, onCtrlV);
        stuff(kVK_ANSI_W, onCtrlW);
        stuff(kVK_ANSI_X, onCtrlX);
        stuff(kVK_ANSI_Y, onCtrlY);
        stuff(kVK_ANSI_Z, onCtrlZ);
#undef stuff
    }
    return [super performKeyEquivalent:event];
}

- (void (^)()) makeActionHotkey:(SEL)_action
{
    __weak SheetWithHotkeys* wself = self;
    auto l = ^{
        if( SheetWithHotkeys* sself = wself ) {
            id ctrl = sself.windowController;
            if( ctrl && [ctrl respondsToSelector:_action] ) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [ctrl performSelector:_action withObject:sself];
#pragma clang diagnostic pop                
            }
        }
    };
    return l;
}

- (void (^)()) makeFocusHotkey:(NSView*)_target
{
    __weak SheetWithHotkeys* wself = self;
    __weak NSView *wtarget = _target;
    auto l = ^{
        if( SheetWithHotkeys* sself = wself ) {
            if( NSView *starget = wtarget ) {
                [sself makeFirstResponder:starget];
            }
        }
    };
    return l;
}

- (void (^)()) makeClickHotkey:(NSControl*)_target
{
    __weak SheetWithHotkeys* wself = self;
    __weak NSControl *wtarget = _target;
    auto l = ^{
        if( SheetWithHotkeys* sself = wself ) {
            if( NSControl *starget = wtarget ) {
                [starget performClick:sself];
            }
        }
    };
    return l;
}

@end
