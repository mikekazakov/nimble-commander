// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Carbon/Carbon.h>
#include <Utility/SheetWithHotkeys.h>

@implementation NCSheetWithHotkeys {
    void (^m_OnCtrlA)();
    void (^m_OnCtrlB)();
    void (^m_OnCtrlC)();
    void (^m_OnCtrlD)();
    void (^m_OnCtrlE)();
    void (^m_OnCtrlF)();
    void (^m_OnCtrlG)();
    void (^m_OnCtrlH)();
    void (^m_OnCtrlI)();
    void (^m_OnCtrlJ)();
    void (^m_OnCtrlK)();
    void (^m_OnCtrlL)();
    void (^m_OnCtrlM)();
    void (^m_OnCtrlN)();
    void (^m_OnCtrlO)();
    void (^m_OnCtrlP)();
    void (^m_OnCtrlQ)();
    void (^m_OnCtrlR)();
    void (^m_OnCtrlS)();
    void (^m_OnCtrlT)();
    void (^m_OnCtrlU)();
    void (^m_OnCtrlV)();
    void (^m_OnCtrlW)();
    void (^m_OnCtrlX)();
    void (^m_OnCtrlY)();
    void (^m_OnCtrlZ)();
}

@synthesize onCtrlA = m_OnCtrlA;
@synthesize onCtrlB = m_OnCtrlB;
@synthesize onCtrlC = m_OnCtrlC;
@synthesize onCtrlD = m_OnCtrlD;
@synthesize onCtrlE = m_OnCtrlE;
@synthesize onCtrlF = m_OnCtrlF;
@synthesize onCtrlG = m_OnCtrlG;
@synthesize onCtrlH = m_OnCtrlH;
@synthesize onCtrlI = m_OnCtrlI;
@synthesize onCtrlJ = m_OnCtrlJ;
@synthesize onCtrlK = m_OnCtrlK;
@synthesize onCtrlL = m_OnCtrlL;
@synthesize onCtrlM = m_OnCtrlM;
@synthesize onCtrlN = m_OnCtrlN;
@synthesize onCtrlO = m_OnCtrlO;
@synthesize onCtrlP = m_OnCtrlP;
@synthesize onCtrlQ = m_OnCtrlQ;
@synthesize onCtrlR = m_OnCtrlR;
@synthesize onCtrlS = m_OnCtrlS;
@synthesize onCtrlT = m_OnCtrlT;
@synthesize onCtrlU = m_OnCtrlU;
@synthesize onCtrlV = m_OnCtrlV;
@synthesize onCtrlW = m_OnCtrlW;
@synthesize onCtrlX = m_OnCtrlX;
@synthesize onCtrlY = m_OnCtrlY;
@synthesize onCtrlZ = m_OnCtrlZ;

- (BOOL)performKeyEquivalent:(NSEvent *)_event
{
    if( _event.type == NSEventTypeKeyDown && (_event.modifierFlags & NSEventModifierFlagControl) ) {
        const unsigned short keycode = _event.keyCode;
#define trigger(KEYCODE, ACTION)                                                                                       \
    if( keycode == (KEYCODE) && (ACTION) ) {                                                                           \
        ACTION();                                                                                                      \
        return true;                                                                                                   \
    }
        trigger(kVK_ANSI_A, m_OnCtrlA);
        trigger(kVK_ANSI_B, m_OnCtrlB);
        trigger(kVK_ANSI_C, m_OnCtrlC);
        trigger(kVK_ANSI_D, m_OnCtrlD);
        trigger(kVK_ANSI_E, m_OnCtrlE);
        trigger(kVK_ANSI_F, m_OnCtrlF);
        trigger(kVK_ANSI_G, m_OnCtrlG);
        trigger(kVK_ANSI_H, m_OnCtrlH);
        trigger(kVK_ANSI_I, m_OnCtrlI);
        trigger(kVK_ANSI_J, m_OnCtrlJ);
        trigger(kVK_ANSI_K, m_OnCtrlK);
        trigger(kVK_ANSI_L, m_OnCtrlL);
        trigger(kVK_ANSI_M, m_OnCtrlM);
        trigger(kVK_ANSI_N, m_OnCtrlN);
        trigger(kVK_ANSI_O, m_OnCtrlO);
        trigger(kVK_ANSI_P, m_OnCtrlP);
        trigger(kVK_ANSI_Q, m_OnCtrlQ);
        trigger(kVK_ANSI_R, m_OnCtrlR);
        trigger(kVK_ANSI_S, m_OnCtrlS);
        trigger(kVK_ANSI_T, m_OnCtrlT);
        trigger(kVK_ANSI_U, m_OnCtrlU);
        trigger(kVK_ANSI_V, m_OnCtrlV);
        trigger(kVK_ANSI_W, m_OnCtrlW);
        trigger(kVK_ANSI_X, m_OnCtrlX);
        trigger(kVK_ANSI_Y, m_OnCtrlY);
        trigger(kVK_ANSI_Z, m_OnCtrlZ);
#undef trigger
    }
    return [super performKeyEquivalent:_event];
}

- (void (^)())makeActionHotkey:(SEL)_action
{
    __weak NCSheetWithHotkeys *wself = self;
    auto l = ^{
      if( NCSheetWithHotkeys *sself = wself ) {
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

- (void (^)())makeFocusHotkey:(NSView *)_target
{
    __weak NCSheetWithHotkeys *wself = self;
    __weak NSView *wtarget = _target;
    auto l = ^{
      if( NCSheetWithHotkeys *sself = wself ) {
          if( NSView *starget = wtarget ) {
              [sself makeFirstResponder:starget];
          }
      }
    };
    return l;
}

- (void (^)())makeClickHotkey:(NSControl *)_target
{
    __weak NCSheetWithHotkeys *wself = self;
    __weak NSControl *wtarget = _target;
    auto l = ^{
      if( NCSheetWithHotkeys *sself = wself ) {
          if( NSControl *starget = wtarget ) {
              [starget performClick:sself];
          }
      }
    };
    return l;
}

@end
