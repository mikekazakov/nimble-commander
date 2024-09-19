// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UserNotificationsCenter.h"
#include <Cocoa/Cocoa.h>
#include <Operations/Statistics.h>
#include <Operations/Operation.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

using namespace std::literals;

static const auto g_DefaultMinElapsedOperationTime = 30s;
static const auto g_Window = @"window";

@interface NCCoreUserNotificationCenterDelegate : NSObject <NSUserNotificationCenterDelegate>
@end

namespace nc::core {

UserNotificationsCenter::UserNotificationsCenter()
    : m_ShowWhenActive{true}, m_MinElapsedOperationTime{g_DefaultMinElapsedOperationTime}
{
    static auto delegate = [[NCCoreUserNotificationCenterDelegate alloc] init];
    NSUserNotificationCenter.defaultUserNotificationCenter.delegate = delegate;
}

UserNotificationsCenter &UserNotificationsCenter::Instance()
{
    static const auto inst = new UserNotificationsCenter;
    return *inst;
}

void UserNotificationsCenter::ReportCompletedOperation(const nc::ops::Operation &_operation, NSWindow *_in_window)
{
    if( _operation.Statistics().ElapsedTime() < m_MinElapsedOperationTime )
        return;

    NSUserNotification *const un = [[NSUserNotification alloc] init];
    un.title = NSLocalizedString(@"Operation is complete", "Notification text");
    un.subtitle = [NSString stringWithUTF8StdString:_operation.Title()];
    un.soundName = NSUserNotificationDefaultSoundName;
    const auto wnd_address = reinterpret_cast<unsigned long>(objc_bridge_cast<void>(_in_window));
    un.userInfo = @{g_Window: [NSNumber numberWithUnsignedLong:wnd_address]};

    [NSUserNotificationCenter.defaultUserNotificationCenter deliverNotification:un];
}

bool UserNotificationsCenter::ShowWhenActive() const noexcept
{
    return m_ShowWhenActive;
}

void UserNotificationsCenter::SetShowWhenActive(bool _value)
{
    m_ShowWhenActive = _value;
}

std::chrono::nanoseconds UserNotificationsCenter::MinElapsedOperationTime() const noexcept
{
    return m_MinElapsedOperationTime;
}

void UserNotificationsCenter::SetMinElapsedOperationTime(std::chrono::nanoseconds _value)
{
    m_MinElapsedOperationTime = _value;
}

static void MakeWindowKey(unsigned long _wnd_adress)
{
    const auto windows = NSApp.windows;
    for( NSWindow *window : windows )
        if( reinterpret_cast<unsigned long>(objc_bridge_cast<void>(window)) == _wnd_adress ) {
            [window makeKeyAndOrderFront:nil];
            break;
        }
}

} // namespace nc::core

@implementation NCCoreUserNotificationCenterDelegate

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *) [[maybe_unused]] _center
     shouldPresentNotification:(NSUserNotification *) [[maybe_unused]] _notification
{
    return nc::core::UserNotificationsCenter::Instance().ShowWhenActive();
}

- (void)userNotificationCenter:(NSUserNotificationCenter *) [[maybe_unused]] _center
       didActivateNotification:(NSUserNotification *)notification
{
    if( notification.userInfo )
        if( const auto packed_wnd_address = nc::objc_cast<NSNumber>(notification.userInfo[g_Window]) )
            nc::core::MakeWindowKey(packed_wnd_address.unsignedLongValue);
}

@end
