// Copyright (C) 2017-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <chrono>
#include <Cocoa/Cocoa.h>

namespace nc::ops {
class Operation;
}

namespace nc::core {

// not thread-safe, use in a main tread only
class UserNotificationsCenter
{
public:
    UserNotificationsCenter(const UserNotificationsCenter &) = delete;

    ~UserNotificationsCenter() = default;

    void operator=(const UserNotificationsCenter &) = delete;

    static UserNotificationsCenter &Instance();

    void ReportCompletedOperation(const nc::ops::Operation &_operation, NSWindow *_in_window);

    [[nodiscard]] bool ShowWhenActive() const noexcept;
    void SetShowWhenActive(bool _value);

    [[nodiscard]] std::chrono::nanoseconds MinElapsedOperationTime() const noexcept;
    void SetMinElapsedOperationTime(std::chrono::nanoseconds _value);

private:
    UserNotificationsCenter();
    bool m_ShowWhenActive = true;
    bool m_NotificationsAutorized = false;
    std::chrono::nanoseconds m_MinElapsedOperationTime;
};

} // namespace nc::core
