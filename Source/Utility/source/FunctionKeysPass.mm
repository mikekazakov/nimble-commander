// Copyright (C) 2016-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include <FunctionKeysPass.h>
#include <Carbon/Carbon.h>
#include <AppKit/AppKit.h>
#include <IOKit/hidsystem/ev_keymap.h>
#include <iostream>
#include <Base/algo.h>
#include <Base/dispatch_cpp.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Utility/Log.h>

namespace nc::utility {

FunctionalKeysPass::FunctionalKeysPass() : m_Port(nullptr), m_Enabled(false)
{
    const auto center = NSNotificationCenter.defaultCenter;
    [center addObserverForName:NSApplicationDidBecomeActiveNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *) {
                      if( m_Port && m_Enabled )
                          CGEventTapEnable(m_Port, true);
                    }];
    [center addObserverForName:NSApplicationDidResignActiveNotification
                        object:nil
                         queue:nil
                    usingBlock:^(NSNotification *) {
                      if( m_Port && m_Enabled )
                          CGEventTapEnable(m_Port, false);
                    }];
}

FunctionalKeysPass &FunctionalKeysPass::Instance() noexcept
{
    [[clang::no_destroy]] static FunctionalKeysPass inst;
    return inst;
}

bool FunctionalKeysPass::Enabled() const
{
    dispatch_assert_main_queue();
    return m_Port != nullptr && CGEventTapIsEnabled(m_Port);
}

static CGEventRef NewFnButtonPress(CGKeyCode _vk, bool _key_down, CGEventFlags _flags)
{
    CGEventRef press = CGEventCreateKeyboardEvent(nullptr, _vk, _key_down);

    const auto filter =
        kCGEventFlagMaskShift | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate | kCGEventFlagMaskCommand;
    const auto flags = _flags & filter;
    if( flags != 0 )
        CGEventSetFlags(press, flags);

    return press;
}

CGEventRef FunctionalKeysPass::Callback([[maybe_unused]] CGEventTapProxy _proxy, CGEventType _type, CGEventRef _event)
{
    if( _type == kCGEventTapDisabledByTimeout ) {
        CGEventTapEnable(m_Port, true);
        return _event;
    }

    if( NSApp.isActive && NSApp.keyWindow != nil ) {
        /* The check above is a paranoid one since an inactive app should not receive any messages
         * via this callback. But in practice there were such occasions, which is still a bit of a
         * mystery.
         */
        if( _type == kCGEventKeyDown || _type == kCGEventKeyUp )
            return HandleRegularKeyEvents(_type, _event);
        else if( static_cast<NSEventType>(_type) == NSEventTypeSystemDefined )
            return HandleControlButtons(_type, _event);
    }

    return _event;
}

CGEventRef FunctionalKeysPass::HandleRegularKeyEvents(CGEventType _type, CGEventRef _event)
{
    // references:
    // https://www.apple.com/uk/newsroom/2022/06/apple-unveils-all-new-macbook-air-supercharged-by-the-new-m2-chip/
    const auto is_key_down = _type == kCGEventKeyDown;
    const auto keycode = static_cast<CGKeyCode>(CGEventGetIntegerValueField(_event, kCGKeyboardEventKeycode));
    const auto substitute = [&](CGKeyCode _vk) { return NewFnButtonPress(_vk, is_key_down, CGEventGetFlags(_event)); };
    Log::Trace("HandleRegularKeyEvents: keycode is {}, pressed={}", keycode, is_key_down);
    switch( keycode ) {
        case 145:
            return substitute(kVK_F1);
        case 144:
            return substitute(kVK_F2);
        case 160:
            return substitute(kVK_F3);
        case 130: // it was used on old Macbooks
        case 131: // launchpad button - multiple generations, laptops and external keyboards
        case 177: // search button on M2 laptops
            return substitute(kVK_F4);
        case 96:  // keyboard brightness down
        case 176: // microphone button on M2 laptops
            return substitute(kVK_F5);
        case 97:  // keyboard brightness up
        case 178: // sleep button on M2 laptops
            return substitute(kVK_F6);
        case 105:
            return substitute(kVK_F13);
        case 107:
            return substitute(kVK_F14);
        case 113:
            return substitute(kVK_F15);
        case 106:
            return substitute(kVK_F16);
        case 64:
            return substitute(kVK_F17);
        case 79:
            return substitute(kVK_F18);
        case 80:
            return substitute(kVK_F19);
    };
    return _event;
}

CGEventRef FunctionalKeysPass::HandleControlButtons([[maybe_unused]] CGEventType _type, CGEventRef _event)
{
    // have to create a NSEvent object for every NSSystemDefined event, which is awful
    const auto ev = [NSEvent eventWithCGEvent:_event];

    if( ev.subtype != NX_SUBTYPE_AUX_CONTROL_BUTTONS )
        return _event;

    const auto data1 = ev.data1;
    const auto keycode = ((data1 & 0xFFFF0000) >> 16);
    const auto is_key_down = (data1 & 0x0000FF00) == 0xA00;
    const auto substitute = [&](CGKeyCode _vk) {
        return NewFnButtonPress(_vk, is_key_down, static_cast<CGEventFlags>(ev.modifierFlags));
    };
    Log::Trace("HandleControlButtons: keycode is {}, pressed={}", keycode, is_key_down);
    switch( keycode ) {
        case NX_KEYTYPE_BRIGHTNESS_DOWN:
            return substitute(kVK_F1);
        case NX_KEYTYPE_BRIGHTNESS_UP:
            return substitute(kVK_F2);
        case NX_KEYTYPE_ILLUMINATION_DOWN:
            return substitute(kVK_F5);
        case NX_KEYTYPE_ILLUMINATION_UP:
            return substitute(kVK_F6);
        case NX_KEYTYPE_REWIND:
            return substitute(kVK_F7);
        case NX_KEYTYPE_PLAY:
            return substitute(kVK_F8);
        case NX_KEYTYPE_FAST:
            return substitute(kVK_F9);
        case NX_KEYTYPE_MUTE:
            return substitute(kVK_F10);
        case NX_KEYTYPE_SOUND_DOWN:
            return substitute(kVK_F11);
        case NX_KEYTYPE_SOUND_UP:
            return substitute(kVK_F12);
    }

    return _event;
}

bool FunctionalKeysPass::Enable()
{
    dispatch_assert_main_queue();

    if( m_Port == nullptr ) {
        if( !ObtainAccessiblityRights() )
            return false;

        const auto interested_events =
            CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(NSEventTypeSystemDefined);
        const auto handler =
            [](CGEventTapProxy _proxy, CGEventType _type, CGEventRef _event, void *_info) -> CGEventRef {
            return static_cast<FunctionalKeysPass *>(_info)->Callback(_proxy, _type, _event);
        };
        const auto port = CGEventTapCreate(
            kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, interested_events, handler, this);
        if( port == nullptr )
            return false;

        // this port will never be released, since this FunctionalKeysPass object lives forever
        m_Port = port;

        const auto loop_source = CFMachPortCreateRunLoopSource(nullptr, port, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), loop_source, kCFRunLoopCommonModes);
        CFRelease(loop_source);
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

bool FunctionalKeysPass::ObtainAccessiblityRights()
{
    const auto options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @YES};
    auto accessibility_granted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    return accessibility_granted;
}

} // namespace nc::utility
