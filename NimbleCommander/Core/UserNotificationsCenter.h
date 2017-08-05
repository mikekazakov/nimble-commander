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

private:
    UserNotificationsCenter();
    UserNotificationsCenter(const UserNotificationsCenter&) = delete;
    ~UserNotificationsCenter();
    void operator=(const UserNotificationsCenter&) = delete;
    nanoseconds m_MinElapsedOperationTime;
};

}
