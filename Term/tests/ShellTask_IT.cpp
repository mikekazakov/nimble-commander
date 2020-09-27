// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.

#include "Tests.h"

#include <ShellTask.h>
#include <Habanero/CommonPaths.h>
#include <atomic>

using namespace nc::term;
using namespace std::chrono_literals;
#define PREFIX "nc::term::ShellTask "

template <class T>
struct AtomicHolder {
    AtomicHolder():
        value(){}
    
    AtomicHolder(T _value):
        value(_value){}
    
    bool wait_to_become(std::chrono::nanoseconds _timeout,
                        T _new_value) {
        std::unique_lock<std::mutex> lock(mutex);
        const auto pred = [_new_value, this]{
            return value == _new_value;
        };
        return condvar.wait_for(lock, _timeout, pred);
    }
    
    void store(T _new_value) {
        {
            std::lock_guard<std::mutex> lock(mutex);
            value = _new_value;
        }
        condvar.notify_all();        
    }
    
    T value;
private:
    std::condition_variable condvar;
    std::mutex mutex;
};

TEST_CASE(PREFIX"Launch and terminate")
{
    using TaskState = ShellTask::TaskState;
    AtomicHolder<ShellTask::TaskState> shell_state;
    ShellTask shell;
    REQUIRE( shell.State() == TaskState::Inactive );
    
    shell_state.value = shell.State();
    shell.SetOnStateChange([&shell_state](ShellTask::TaskState _new_state){
        shell_state.store(_new_state);
    });
        
    shell.Launch( CommonPaths::AppTemporaryDirectory().c_str() );
    REQUIRE( shell_state.wait_to_become(5s, TaskState::Shell) );
    
    shell.Terminate();
    REQUIRE( shell_state.wait_to_become(5s, TaskState::Inactive) );
}

TEST_CASE(PREFIX"Launch an invalid shell")
{
    SECTION("Looks like Bash") {
        ShellTask shell;
        shell.SetShellPath("/bin/blah/bash");
        CHECK( shell.Launch( CommonPaths::AppTemporaryDirectory().c_str() ) == false );
        CHECK( shell.State() == ShellTask::TaskState::Inactive );
    }
    SECTION("Just nonsense") {
        ShellTask shell;
        shell.SetShellPath("/blah/blah/blah");
        CHECK( shell.Launch( CommonPaths::AppTemporaryDirectory().c_str() ) == false );
        CHECK( shell.State() == ShellTask::TaskState::Inactive );
    }
}
