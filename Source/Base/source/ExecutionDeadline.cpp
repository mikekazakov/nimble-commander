// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/ExecutionDeadline.h>
#include <cstdlib>
#include <iostream>
#include <pthread.h>
#include <thread>

namespace nc::base {

ExecutionDeadline::ExecutionDeadline(std::chrono::seconds _execution_limit)
{
    // that's a really rough implementation.
    // it doesn't support a notification about a graceful shutdown and contains a potential race
    // condition.
    std::thread([_execution_limit] {
        pthread_setname_np("ExecutionDeadline watchdog");
        std::this_thread::sleep_for(_execution_limit);
        std::cerr << "Here comes the grim reaper after a naughty process which has been running for more than "
                  << _execution_limit.count() << " seconds!" << '\n';
        exit(-1);
    }).detach();
}

} // namespace nc::base
