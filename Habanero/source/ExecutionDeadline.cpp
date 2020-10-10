// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/ExecutionDeadline.h>
#include <thread>
#include <iostream>
#include <stdlib.h>

namespace nc::base {

ExecutionDeadline::ExecutionDeadline( std::chrono::seconds _execution_limit )
{
    // that's a really rough implementation.
    // it doesn't support a notification about a graceful shutdown and contains a potential race
    // condition
    std::thread([_execution_limit]{
        std::this_thread::sleep_for(_execution_limit);
        std::cerr << "Here comes the grim reaper after a naughty process which ran for more than "
            << _execution_limit.count() << " seconds!" << std::endl;
        exit(-1);
    }).detach();
}

ExecutionDeadline::~ExecutionDeadline()
{
}

}
