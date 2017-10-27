// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Carbon/Carbon.h>
#include <AppKit/AppKit.h>
#include <IOKit/hidsystem/ev_keymap.h>
#include <iostream>
#include <Habanero/algo.h>
#include <Habanero/dispatch_cpp.h>
#include "../include/Utility/FunctionKeysPass.h"

#include <CoreFoundation/CoreFoundation.h>
#include <Carbon/Carbon.h>

using namespace std;

FunctionalKeysPass::FunctionalKeysPass():
    m_Port( nullptr ),
    m_Enabled( false )
{
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification * _Nonnull note) {
                                                    if( m_Port && m_Enabled )
                                                        CGEventTapEnable(m_Port, true);
                                                }];
    [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidResignActiveNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification * _Nonnull note) {
                                                    if( m_Port && m_Enabled )
                                                        CGEventTapEnable(m_Port, false);
                                                }];
}

FunctionalKeysPass &FunctionalKeysPass::Instance()
{
    static FunctionalKeysPass *i = new FunctionalKeysPass;
    return *i;
}

bool FunctionalKeysPass::Enabled() const
{
    dispatch_assert_main_queue();
    return m_Port != nullptr && CGEventTapIsEnabled(m_Port);
}

static CGEventRef NewFnButtonPress( CGKeyCode _vk, bool _key_down, CGEventFlags _flags )
{
    CGEventRef press = CGEventCreateKeyboardEvent( nullptr, _vk, _key_down );
    const uint64_t flags = _flags & (kCGEventFlagMaskShift | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate | kCGEventFlagMaskCommand );
    if( flags != 0 )
        CGEventSetFlags( press, (CGEventFlags)flags );
    
    return press;
}

CGEventRef FunctionalKeysPass::Callback(CGEventTapProxy _proxy, CGEventType _type, CGEventRef _event)
{
    if( _type == kCGEventTapDisabledByTimeout ) {
        assert( m_Port != nullptr );
        cout << "calling CGEventTapEnable()" << endl;
        CGEventTapEnable(m_Port, true);
        return nil;
    }

    if( _type == kCGEventKeyDown || _type == kCGEventKeyUp) {
        const auto key_down = _type == kCGEventKeyDown;
        const auto keycode = (CGKeyCode)CGEventGetIntegerValueField( _event, kCGKeyboardEventKeycode );
        
        switch( keycode ) {
            case 145: return NewFnButtonPress( kVK_F1,  key_down, CGEventGetFlags(_event) );
            case 144: return NewFnButtonPress( kVK_F2,  key_down, CGEventGetFlags(_event) );
            case 160: return NewFnButtonPress( kVK_F3,  key_down, CGEventGetFlags(_event) );
            case 130: // it was used on old Macbooks
            case 131: return NewFnButtonPress( kVK_F4,  key_down, CGEventGetFlags(_event) );
            case 96:  return NewFnButtonPress( kVK_F5,  key_down, CGEventGetFlags(_event) );
            case 97:  return NewFnButtonPress( kVK_F6,  key_down, CGEventGetFlags(_event) );
            case 105: return NewFnButtonPress( kVK_F13, key_down, CGEventGetFlags(_event) );
            case 107: return NewFnButtonPress( kVK_F14, key_down, CGEventGetFlags(_event) );
            case 113: return NewFnButtonPress( kVK_F15, key_down, CGEventGetFlags(_event) );
            case 106: return NewFnButtonPress( kVK_F16, key_down, CGEventGetFlags(_event) );
            case 64:  return NewFnButtonPress( kVK_F17, key_down, CGEventGetFlags(_event) );
            case 79:  return NewFnButtonPress( kVK_F18, key_down, CGEventGetFlags(_event) );
            case 80:  return NewFnButtonPress( kVK_F19, key_down, CGEventGetFlags(_event) );
        };
    }
    else if( (NSEventType)_type == NSSystemDefined ) {
        NSEvent *ev = [NSEvent eventWithCGEvent:_event]; // have to create a NSEvent object for every NSSystemDefined event, which is awful
        if( ev.subtype == NX_SUBTYPE_AUX_CONTROL_BUTTONS ) {
            const NSInteger data1 = ev.data1;
            const int keycode = ((data1 & 0xFFFF0000) >> 16);
            const bool key_down = (data1 & 0x0000FF00) == 0xA00;
            switch( keycode ) {
                case NX_KEYTYPE_BRIGHTNESS_DOWN:    return NewFnButtonPress( kVK_F1,  key_down, (CGEventFlags) ev.modifierFlags );
                case NX_KEYTYPE_BRIGHTNESS_UP:      return NewFnButtonPress( kVK_F2,  key_down, (CGEventFlags) ev.modifierFlags );
                case NX_KEYTYPE_ILLUMINATION_DOWN:  return NewFnButtonPress( kVK_F5,  key_down, (CGEventFlags) ev.modifierFlags );
                case NX_KEYTYPE_ILLUMINATION_UP:    return NewFnButtonPress( kVK_F6,  key_down, (CGEventFlags) ev.modifierFlags );
                case NX_KEYTYPE_REWIND:             return NewFnButtonPress( kVK_F7,  key_down, (CGEventFlags) ev.modifierFlags );
                case NX_KEYTYPE_PLAY:               return NewFnButtonPress( kVK_F8,  key_down, (CGEventFlags) ev.modifierFlags );
                case NX_KEYTYPE_FAST:               return NewFnButtonPress( kVK_F9,  key_down, (CGEventFlags) ev.modifierFlags );
                case NX_KEYTYPE_MUTE:               return NewFnButtonPress( kVK_F10, key_down, (CGEventFlags) ev.modifierFlags );
                case NX_KEYTYPE_SOUND_DOWN:         return NewFnButtonPress( kVK_F11, key_down, (CGEventFlags) ev.modifierFlags );
                case NX_KEYTYPE_SOUND_UP:           return NewFnButtonPress( kVK_F12, key_down, (CGEventFlags) ev.modifierFlags );
            }
        }
    }

    return _event;
}

bool FunctionalKeysPass::Enable()
{
    dispatch_assert_main_queue();
    
    if( m_Port == nullptr ) {
        NSDictionary *options = @{(__bridge NSString*)kAXTrustedCheckOptionPrompt: @YES};
        bool accessibility_enabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
        if( !accessibility_enabled ) {
            cerr << "can't get accessibility rights" << endl;
            return false;
        }
        
        CFMachPortRef port = CGEventTapCreate(kCGHIDEventTap,
                                              kCGHeadInsertEventTap,
                                              kCGEventTapOptionDefault,
                                              CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(NSSystemDefined),
                                              [](CGEventTapProxy _proxy, CGEventType _type, CGEventRef _event, void *_info) -> CGEventRef {
                                                  return ((FunctionalKeysPass*)_info)->Callback(_proxy, _type, _event);
                                              },
                                              this
                                              );
        if( !port ) {
            cerr << "CGEventTapCreate() failed" << endl;
            return false;
        }
        m_Port = port; // this port will never be released, since this FunctionalKeysPass object lives forever
        
        CFRunLoopSourceRef keyUpRunLoopSourceRef = CFMachPortCreateRunLoopSource(nullptr, port, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), keyUpRunLoopSourceRef, kCFRunLoopCommonModes);
        CFRelease(keyUpRunLoopSourceRef);
    }
    else {
        CGEventTapEnable(m_Port, true);
    }
    m_Enabled = true;
    return true;
}

void FunctionalKeysPass::Disable()
{
    dispatch_assert_main_queue();
    if( m_Port ) {
        CGEventTapEnable(m_Port, false);
        m_Enabled = false;
    }
}
