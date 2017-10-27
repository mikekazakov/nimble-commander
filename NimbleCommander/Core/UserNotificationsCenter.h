// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::ops {
class Operation;
}

namespace nc::core {

// not thread-safe, use in a main tread only
class UserNotificationsCenter
{
public:
    static UserNotificationsCenter &Instance();

    void ReportCompletedOperation( const nc::ops::Operation &_operation, NSWindow *_in_window );


    bool ShowWhenActive() const noexcept;
    void SetShowWhenActive( bool _value );

    nanoseconds MinElapsedOperationTime() const noexcept;
    void SetMinElapsedOperationTime( nanoseconds _value );

private:
    UserNotificationsCenter();
    UserNotificationsCenter(const UserNotificationsCenter&) = delete;
    ~UserNotificationsCenter();
    void operator=(const UserNotificationsCenter&) = delete;
    bool m_ShowWhenActive;
    nanoseconds m_MinElapsedOperationTime;
};

}
