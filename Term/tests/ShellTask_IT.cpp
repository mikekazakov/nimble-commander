// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.

#include "Tests.h"
#include "AtomicHolder.h"

#include <ShellTask.h>
#include <Screen.h>
#include <Parser2Impl.h>
#include <InterpreterImpl.h>
#include <Habanero/CommonPaths.h>
#include <Habanero/mach_time.h>
#include <Habanero/dispatch_cpp.h>
#include <Utility/SystemInformation.h>
#include <magic_enum.hpp>

using namespace nc;
using namespace nc::term;
using nc::base::CommonPaths;
using namespace std::chrono_literals;
#define PREFIX "nc::term::ShellTask "

[[maybe_unused]] static std::string RightPad(std::string _input, size_t _to, char _with = ' ')
{
    if( _input.size() < _to )
        _input.append(_to - _input.size(), _with);
    return _input;
}

TEST_CASE(PREFIX "Inactive -> Shell -> Terminate - Inactive")
{
    using TaskState = ShellTask::TaskState;
    ShellTask shell;
    QueuedAtomicHolder<ShellTask::TaskState> shell_state(shell.State());
    REQUIRE(shell.State() == TaskState::Inactive);

    shell.SetOnStateChange(
        [&shell_state](ShellTask::TaskState _new_state) { shell_state.store(_new_state); });

    shell.Launch(CommonPaths::AppTemporaryDirectory());
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));

    shell.Terminate();
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Inactive));
}

TEST_CASE(PREFIX "Inactive -> Shell -> ProgramInternal (exit) -> Dead -> Inactive")
{
    using TaskState = ShellTask::TaskState;
    ShellTask shell;
    QueuedAtomicHolder<ShellTask::TaskState> shell_state(shell.State());
    shell.SetOnStateChange(
        [&shell_state](ShellTask::TaskState _new_state) { shell_state.store(_new_state); });
    REQUIRE(shell.State() == TaskState::Inactive);
    shell.Launch(CommonPaths::AppTemporaryDirectory());
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    shell.WriteChildInput("exit\r");
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramInternal));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Dead));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Inactive));
}

TEST_CASE(PREFIX "Inactive -> Shell -> ProgramInternal (vi) -> Shell -> Terminate -> Inactive")
{
    using TaskState = ShellTask::TaskState;
    ShellTask shell;
    QueuedAtomicHolder<ShellTask::TaskState> shell_state(shell.State());
    shell.SetOnStateChange(
        [&shell_state](ShellTask::TaskState _new_state) { shell_state.store(_new_state); });
    REQUIRE(shell.State() == TaskState::Inactive);
    shell.Launch(CommonPaths::AppTemporaryDirectory());
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    shell.WriteChildInput("vi\r");
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramInternal));
    shell.WriteChildInput(":q\r");
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    shell.Terminate();
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Inactive));
}

TEST_CASE(PREFIX "Inactive -> Shell -> ProgramExternal (vi) -> Shell -> Terminate -> Inactive")
{
    using TaskState = ShellTask::TaskState;
    ShellTask shell;
    QueuedAtomicHolder<ShellTask::TaskState> shell_state(shell.State());
    shell.SetOnStateChange(
        [&shell_state](ShellTask::TaskState _new_state) { shell_state.store(_new_state); });
    REQUIRE(shell.State() == TaskState::Inactive);
    shell.Launch(CommonPaths::AppTemporaryDirectory());
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    ;
    shell.ExecuteWithFullPath("/usr/bin/vi", nullptr);
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    shell.WriteChildInput(":q\r");
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    shell.Terminate();
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Inactive));
}

TEST_CASE(PREFIX "Launch=>Exit via output")
{
    AtomicHolder<std::string> buffer_dump;
    Screen screen(20, 3);
    Parser2Impl parser;
    InterpreterImpl interpreter(screen);

    ShellTask shell;
    shell.ResizeWindow(20, 3);
    shell.SetShellPath("/bin/bash");
    shell.SetEnvVar("PS1", "Hello=>");
    shell.AddCustomShellArgument("bash");
    shell.SetOnChildOutput([&](const void *_d, int _sz) {
        if( auto cmds = parser.Parse({(const std::byte *)_d, (size_t)_sz}); !cmds.empty() ) {
            if( auto lock = screen.AcquireLock() ) {
                interpreter.Interpret(cmds);
                buffer_dump.store(screen.Buffer().DumpScreenAsANSI());
            }
        }
    });
    shell.Launch(CommonPaths::AppTemporaryDirectory());

    const std::string expected = "Hello=>             "
                                 "                    "
                                 "                    ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected));

    shell.WriteChildInput("exit\r");
    const std::string expected2 = "Hello=>exit         "
                                  "exit                "
                                  "                    ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected2));
}

TEST_CASE(PREFIX "ChDir(), verify via output and cwd prompt (Bash)")
{
    const TempTestDir dir;
    const auto dir2 = dir.directory / "Therion" / "";
    const auto dir3 = dir.directory / "Blackmore's Night" / "";
    const auto dir4 = dir.directory / U"Сектор Газа" / "";
    const auto dir5 = dir.directory / U"😀🍻" / "";
    for( auto d : {dir2, dir3, dir4, dir5} )
        std::filesystem::create_directory(d);

    AtomicHolder<std::string> buffer_dump;
    AtomicHolder<std::filesystem::path> cwd;
    Screen screen(20, 5);
    Parser2Impl parser;
    InterpreterImpl interpreter(screen);

    ShellTask shell;
    shell.ResizeWindow(20, 5);
    shell.SetShellPath("/bin/bash");
    shell.SetEnvVar("PS1", ">");
    shell.AddCustomShellArgument("bash");
    shell.SetOnChildOutput([&](const void *_d, int _sz) {
        if( auto cmds = parser.Parse({(const std::byte *)_d, (size_t)_sz}); !cmds.empty() ) {
            if( auto lock = screen.AcquireLock() ) {
                interpreter.Interpret(cmds);
                buffer_dump.store(screen.Buffer().DumpScreenAsANSI());
            }
        }
    });
    shell.SetOnPwdPrompt([&](const char *_cwd, bool) { cwd.store(_cwd); });
    shell.Launch(dir.directory);

    const std::string expected1 = ">                   "
                                  "                    "
                                  "                    "
                                  "                    "
                                  "                    ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected1));
    REQUIRE(cwd.wait_to_become(5s, dir.directory));

    shell.ChDir(dir2);
    const std::string expected2 = ">                   "
                                  ">                   "
                                  "                    "
                                  "                    "
                                  "                    ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected2));
    REQUIRE(cwd.wait_to_become(5s, dir2));

    shell.ChDir(dir3);
    const std::string expected3 = ">                   "
                                  ">                   "
                                  ">                   "
                                  "                    "
                                  "                    ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected3));
    REQUIRE(cwd.wait_to_become(5s, dir3));

    shell.ChDir(dir4);
    const std::string expected4 = ">                   "
                                  ">                   "
                                  ">                   "
                                  ">                   "
                                  "                    ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected4));
    REQUIRE(cwd.wait_to_become(5s, dir4));

    shell.ChDir(dir5);
    const std::string expected5 = ">                   "
                                  ">                   "
                                  ">                   "
                                  ">                   "
                                  ">                   ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected5));
    REQUIRE(cwd.wait_to_become(5s, dir5));
}

TEST_CASE(PREFIX "Launch an invalid shell")
{
    SECTION("Looks like Bash")
    {
        ShellTask shell;
        shell.SetShellPath("/bin/blah/bash");
        CHECK(shell.Launch(CommonPaths::AppTemporaryDirectory()) == false);
        CHECK(shell.State() == ShellTask::TaskState::Inactive);
    }
    SECTION("Just nonsense")
    {
        ShellTask shell;
        shell.SetShellPath("/blah/blah/blah");
        CHECK(shell.Launch(CommonPaths::AppTemporaryDirectory()) == false);
        CHECK(shell.State() == ShellTask::TaskState::Inactive);
    }
}

TEST_CASE(PREFIX "CWD prompt response")
{
    const TempTestDir dir;
    using TaskState = ShellTask::TaskState;
    AtomicHolder<ShellTask::TaskState> shell_state;
    ShellTask shell;
    shell_state.value = shell.State();
    shell.SetOnStateChange(
        [&shell_state](ShellTask::TaskState _new_state) { shell_state.store(_new_state); });
    AtomicHolder<std::filesystem::path> cwd;
    shell.SetOnPwdPrompt([&](const char *_cwd, bool) { cwd.store(_cwd); });
    REQUIRE(shell.State() == TaskState::Inactive);
    SECTION("/bin/bash") { shell.SetShellPath("/bin/bash"); }
    SECTION("/bin/zsh") { shell.SetShellPath("/bin/zsh"); }
    SECTION("/bin/tcsh") { shell.SetShellPath("/bin/tcsh"); }
    SECTION("/bin/csh") { shell.SetShellPath("/bin/csh"); }
    shell.Launch(dir.directory);
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(cwd.wait_to_become(5s, dir.directory));

    const char *new_dir1 = "foo";
    shell.ExecuteWithFullPath("/bin/mkdir", new_dir1);
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(cwd.wait_to_become(5s, dir.directory));
    shell.ExecuteWithFullPath("cd", new_dir1);
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(cwd.wait_to_become(5s, dir.directory / new_dir1 / ""));
    shell.ExecuteWithFullPath("cd", "..");
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(cwd.wait_to_become(5s, dir.directory));

    const char *new_dir2 = reinterpret_cast<const char *>(u8"привет");
    shell.ExecuteWithFullPath("/bin/mkdir", Task::EscapeShellFeed(new_dir2).c_str());
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(cwd.wait_to_become(5s, dir.directory));
    shell.ExecuteWithFullPath("cd", Task::EscapeShellFeed(new_dir2).c_str());
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(cwd.wait_to_become(5s, dir.directory / new_dir2 / ""));
    shell.ExecuteWithFullPath("cd", "..");
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(cwd.wait_to_become(5s, dir.directory));

    const char *new_dir3 = reinterpret_cast<const char *>(u8"привет, мир!");
    shell.ExecuteWithFullPath("/bin/mkdir", ("'" + std::string(new_dir3) + "'").c_str());
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(cwd.wait_to_become(5s, dir.directory));
    shell.ExecuteWithFullPath("cd", Task::EscapeShellFeed(new_dir3).c_str());
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(cwd.wait_to_become(5s, dir.directory / new_dir3 / ""));
    shell.ExecuteWithFullPath("cd", "..");
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(cwd.wait_to_become(5s, dir.directory));

    // skipping emoji test for now, as CSH/TCSH requires escaping emojis as e.g. '\U+1F37B', i.e.
    // EscapeShellFeed should ideally become shell-type-aware AND to properly parse its input
    // unicode-wise. that really sucks.
}
