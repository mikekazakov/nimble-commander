// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UserNotificationsCenter.h"
#include <Cocoa/Cocoa.h>
#include <UserNotifications/UserNotifications.h>
#include <Operations/Statistics.h>
#include <Operations/Operation.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include <Base/dispatch_cpp.h>

using namespace std::literals;

static const auto g_DefaultMinElapsedOperationTime = 30s;
static const auto g_Window = @"window";

@interface NCCoreUserNotificationCenterDelegate : NSObject <UNUserNotificationCenterDelegate>
@end

namespace nc::core {

UserNotificationsCenter::UserNotificationsCenter() : m_MinElapsedOperationTime{g_DefaultMinElapsedOperationTime}
{
    static auto delegate = [[NCCoreUserNotificationCenterDelegate alloc] init];
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    center.delegate = delegate;
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                          completionHandler:^(BOOL _granted, NSError *_Nullable) {
                            m_NotificationsAutorized = _granted;
                          }];
}

UserNotificationsCenter &UserNotificationsCenter::Instance()
{
    static const auto inst = new UserNotificationsCenter;
    return *inst;
}

void UserNotificationsCenter::ReportCompletedOperation(const nc::ops::Operation &_operation, NSWindow *_in_window)
{
    if( _operation.Statistics().ElapsedTime() < m_MinElapsedOperationTime || !m_NotificationsAutorized )
        return;

    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = NSLocalizedString(@"Operation is complete", "Notification text");
    content.subtitle = [NSString stringWithUTF8StdString:_operation.Title()];
    content.sound = [UNNotificationSound defaultSound];

    const unsigned long wnd_address = reinterpret_cast<unsigned long>(objc_bridge_cast<void>(_in_window));
    content.userInfo = @{g_Window: [NSNumber numberWithUnsignedLong:wnd_address]};

    NSString *identifier = [NSString stringWithFormat:@"nc.op.complete.%lu", wnd_address];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
                                                                          content:content
                                                                          trigger:nil];

    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request
                                                         withCompletionHandler:^(NSError *_Nullable error) {
                                                           (void)error;
                                                         }];
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

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    const bool is_active = [NSApp isActive];
    const bool should_show_when_active = nc::core::UserNotificationsCenter::Instance().ShowWhenActive();
    if( !is_active || should_show_when_active ) {
        completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
    }
    else {
        completionHandler(UNNotificationPresentationOptionNone);
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
             withCompletionHandler:(void (^)(void))completionHandler
{
    if( [response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier] ) {
        if( NSDictionary *userInfo = response.notification.request.content.userInfo ) {
            if( NSNumber *packed = nc::objc_cast<NSNumber>(userInfo[g_Window]) ) {
                const unsigned long wnd_key = packed.unsignedLongValue;
                dispatch_to_main_queue([wnd_key]() { nc::core::MakeWindowKey(wnd_key); });
            }
        }
    }
    if( completionHandler )
        completionHandler();
}

@end
