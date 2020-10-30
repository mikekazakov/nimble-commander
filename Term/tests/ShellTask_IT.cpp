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
#include <sys/param.h>
#include <unordered_map>

using namespace nc;
using namespace nc::term;
using nc::base::CommonPaths;
using TaskState = ShellTask::TaskState;
using namespace std::chrono_literals;
#define PREFIX "nc::term::ShellTask "

[[maybe_unused]] static std::string RightPad(std::string _input, size_t _to, char _with = ' ')
{
    if( _input.size() < _to )
        _input.append(_to - _input.size(), _with);
    return _input;
}

static bool WaitChildrenListToBecome(const ShellTask &_shell,
                                     const std::vector<std::string> &_expected,
                                     std::chrono::nanoseconds _deadline,
                                     std::chrono::nanoseconds _poll_period)
{
    const auto deadline = machtime() + _deadline;
    while( true ) {
        const auto list = _shell.ChildrenList();
        if( list == _expected )
            return true;
        if( machtime() >= deadline )
            return false;
        std::this_thread::sleep_for(_poll_period);
    }
}

static bool WaitUntilProcessDies(int _pid,
                                 std::chrono::nanoseconds _deadline,
                                 std::chrono::nanoseconds _poll_period)
{
    const auto deadline = machtime() + _deadline;
    while( true ) {
        const bool dead = kill(_pid, 0) < 0;
        if( dead && errno == ESRCH )
            return true;
        if( machtime() >= deadline )
            return false;
        std::this_thread::sleep_for(_poll_period);
    }
}

TEST_CASE(PREFIX "Inactive -> Shell -> Terminate - Inactive")
{
    ShellTask shell;
    SECTION("/bin/bash") { shell.SetShellPath("/bin/bash"); }
    SECTION("/bin/zsh") { shell.SetShellPath("/bin/zsh"); }
    SECTION("/bin/tcsh") { shell.SetShellPath("/bin/tcsh"); }
    SECTION("/bin/csh") { shell.SetShellPath("/bin/csh"); }
    QueuedAtomicHolder<ShellTask::TaskState> shell_state(shell.State());
    REQUIRE(shell.State() == TaskState::Inactive);

    shell.SetOnStateChange(
        [&shell_state](ShellTask::TaskState _new_state) { shell_state.store(_new_state); });

    shell.Launch(CommonPaths::AppTemporaryDirectory());
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    const int pid = shell.ShellPID();
    REQUIRE(pid >= 0);

    shell.Terminate();
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Inactive));
    REQUIRE(WaitUntilProcessDies(pid, 5s, 1ms));
}

TEST_CASE(PREFIX "Inactive -> Shell -> ProgramInternal (exit) -> Dead -> Inactive")
{
    QueuedAtomicHolder<ShellTask::TaskState> shell_state(ShellTask::TaskState::Inactive);
    ShellTask shell;
    SECTION("/bin/bash") { shell.SetShellPath("/bin/bash"); }
    SECTION("/bin/zsh") { shell.SetShellPath("/bin/zsh"); }
    SECTION("/bin/tcsh") { shell.SetShellPath("/bin/tcsh"); }
    SECTION("/bin/csh") { shell.SetShellPath("/bin/csh"); }
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
    ShellTask shell;
    SECTION("/bin/bash") { shell.SetShellPath("/bin/bash"); }
    SECTION("/bin/zsh") { shell.SetShellPath("/bin/zsh"); }
    SECTION("/bin/tcsh") { shell.SetShellPath("/bin/tcsh"); }
    SECTION("/bin/csh") { shell.SetShellPath("/bin/csh"); }
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
    ShellTask shell;
    SECTION("/bin/bash") { shell.SetShellPath("/bin/bash"); }
    SECTION("/bin/zsh") { shell.SetShellPath("/bin/zsh"); }
    SECTION("/bin/tcsh") { shell.SetShellPath("/bin/tcsh"); }
    SECTION("/bin/csh") { shell.SetShellPath("/bin/csh"); }
    QueuedAtomicHolder<ShellTask::TaskState> shell_state(shell.State());
    shell.SetOnStateChange(
        [&shell_state](ShellTask::TaskState _new_state) { shell_state.store(_new_state); });
    REQUIRE(shell.State() == TaskState::Inactive);
    shell.Launch(CommonPaths::AppTemporaryDirectory());
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    shell.ExecuteWithFullPath("/usr/bin/vi", nullptr);
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    shell.WriteChildInput(":q\r");
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    shell.Terminate();
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Inactive));
}

TEST_CASE(PREFIX "Launch=>Exit via output (Bash)")
{
    AtomicHolder<std::string> buffer_dump;
    Screen screen(20, 3);
    Parser2Impl parser;
    InterpreterImpl interpreter(screen);

    ShellTask shell;
    shell.ResizeWindow(20, 3);
    SECTION("bash")
    {
        shell.SetShellPath("/bin/bash");
        shell.SetEnvVar("PS1", "Hello=>");
        shell.AddCustomShellArgument("bash");
    }
    SECTION("zsh")
    {
        shell.SetShellPath("/bin/zsh");
        shell.SetEnvVar("PS1", "Hello=>");
        shell.AddCustomShellArgument("zsh");
        shell.AddCustomShellArgument("-f");
    }
    SECTION("csh")
    {
        shell.SetShellPath("/bin/csh");
    }
    SECTION("tcsh")
    {
        shell.SetShellPath("/bin/tcsh");
    }
    const auto type = shell.GetShellType();
    shell.SetOnChildOutput([&](const void *_d, int _sz) {
        if( auto cmds = parser.Parse({(const std::byte *)_d, (size_t)_sz}); !cmds.empty() ) {
            if( auto lock = screen.AcquireLock() ) {
                interpreter.Interpret(cmds);
                buffer_dump.store(screen.Buffer().DumpScreenAsANSI());
            }
        }
    });
    shell.Launch(CommonPaths::AppTemporaryDirectory());

    if( type == ShellTask::ShellType::TCSH ) {
        shell.WriteChildInput("set prompt='Hello=>'\rclear\r");
    }
    
    const std::string expected = "Hello=>             "
                                 "                    "
                                 "                    ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected));

    shell.WriteChildInput("exit\r");
    std::unordered_map<ShellTask::ShellType, std::string> expected2;
    expected2[ShellTask::ShellType::Bash] = "Hello=>exit         "
                                            "exit                "
                                            "                    ";
    expected2[ShellTask::ShellType::TCSH] = expected2[ShellTask::ShellType::Bash];
    expected2[ShellTask::ShellType::ZSH] = "Hello=>exit         "
                                           "                    "
                                           "                    ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected2[type]));
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
    SECTION("bash")
    {
        shell.SetShellPath("/bin/bash");
        shell.SetEnvVar("PS1", ">");
        shell.AddCustomShellArgument("bash");
    }
    SECTION("zsh")
    {
        shell.SetShellPath("/bin/zsh");
        shell.SetEnvVar("PS1", ">");
        shell.AddCustomShellArgument("zsh");
        shell.AddCustomShellArgument("-f");
    }
    SECTION("csh")
    {
        shell.SetShellPath("/bin/csh");
    }
    SECTION("tcsh")
    {
        shell.SetShellPath("/bin/tcsh");
    }
    const auto type = shell.GetShellType();
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
    
    if( type == ShellTask::ShellType::TCSH ) {
        shell.WriteChildInput("set prompt='>'\rclear\r");
    }

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

TEST_CASE(PREFIX "CWD prompt response - changed/same")
{
    const TempTestDir dir;
    ShellTask shell;
    QueuedAtomicHolder<std::pair<std::filesystem::path, bool>> cwd;
    shell.SetOnPwdPrompt([&](const char *_cwd, bool _changed) { cwd.store({_cwd, _changed}); });
    SECTION("/bin/bash") { shell.SetShellPath("/bin/bash"); }
    SECTION("/bin/zsh") { shell.SetShellPath("/bin/zsh"); }
    SECTION("/bin/tcsh") { shell.SetShellPath("/bin/tcsh"); }
    SECTION("/bin/csh") { shell.SetShellPath("/bin/csh"); }
    shell.Launch(dir.directory);
    REQUIRE(cwd.wait_to_become(5s, {dir.directory, false}));
    
    shell.ExecuteWithFullPath("cd", ".");
    REQUIRE(cwd.wait_to_become(5s, {dir.directory, false}));
    
    shell.ExecuteWithFullPath("cd", "/");
    REQUIRE(cwd.wait_to_become(5s, {"/", true}));
    
    shell.ExecuteWithFullPath("cd", "/");
    REQUIRE(cwd.wait_to_become(5s, {"/", false}));
}

TEST_CASE(PREFIX "Test basics (legacy stuff)")
{
    const TempTestDir dir;
    const auto dir2 = dir.directory / "Test" / "";
    std::filesystem::create_directory(dir2);

    QueuedAtomicHolder<ShellTask::TaskState> shell_state;
    AtomicHolder<std::filesystem::path> cwd;
    ShellTask shell;
    shell_state.store(shell.State());
    shell_state.strict(false);
    shell.SetOnStateChange(
        [&shell_state](ShellTask::TaskState _new_state) { shell_state.store(_new_state); });
    shell.SetOnPwdPrompt([&](const char *_cwd, bool) { cwd.store(_cwd); });
    SECTION("/bin/bash") { shell.SetShellPath("/bin/bash"); }
    SECTION("/bin/zsh") { shell.SetShellPath("/bin/zsh"); }
    SECTION("/bin/tcsh") { shell.SetShellPath("/bin/tcsh"); }
    SECTION("/bin/csh") { shell.SetShellPath("/bin/csh"); }
    shell.ResizeWindow(100, 100);
    shell.Launch(dir.directory);

    // check cwd
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(shell.CWD() == dir.directory.generic_string());

    // the only task is running is shell itself, and is not returned by ChildrenList
    CHECK(shell.ChildrenList().empty());

    // test executing binaries within a shell
    shell.ExecuteWithFullPath("/usr/bin/top", nullptr);
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    REQUIRE(WaitChildrenListToBecome(shell, {"top"}, 5s, 1ms));

    // simulates user press Q to quit top
    shell.WriteChildInput("q");
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    REQUIRE(WaitChildrenListToBecome(shell, {}, 5s, 1ms));

    // check chdir
    shell.ChDir(dir2);
    REQUIRE(cwd.wait_to_become(5s, dir2));
    REQUIRE(shell.CWD() == dir2.generic_string());

    // test chdir in the middle of some typing
    shell.WriteChildInput("ls ");
    shell.ChDir(dir.directory);
    REQUIRE(cwd.wait_to_become(5s, dir.directory));
    REQUIRE(shell.CWD() == dir.directory.generic_string());

    // check internal program state
    shell.WriteChildInput("top\r");
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramInternal));
    REQUIRE(WaitChildrenListToBecome(shell, {"top"}, 5s, 1ms));

    // check termination
    shell.Terminate();
    REQUIRE(shell.ChildrenList().empty());
    REQUIRE(shell.State() == ShellTask::TaskState::Inactive);

    // check execution with short path in different directory
    shell.Launch(dir.directory);
    REQUIRE(shell_state.wait_to_become(5s, TaskState::Shell));
    shell.Execute("top", "/usr/bin/", nullptr);
    REQUIRE(shell_state.wait_to_become(5s, TaskState::ProgramExternal));
    REQUIRE(WaitChildrenListToBecome(shell, {"top"}, 5s, 1ms));

    shell.Terminate();
    REQUIRE(shell.ChildrenList().empty());
}

TEST_CASE(PREFIX "Test vim interaction via output")
{
    const TempTestDir dir;
    std::filesystem::remove(dir.directory / ".vim_test.swp");

    AtomicHolder<std::string> buffer_dump;
    Screen screen(40, 10);
    Parser2Impl parser;
    InterpreterImpl interpreter(screen);

    ShellTask shell;
    shell.ResizeWindow(40, 10);
    SECTION("bash")
    {
        shell.SetShellPath("/bin/bash");
        shell.SetEnvVar("PS1", ">");
        shell.AddCustomShellArgument("bash");
    }
    SECTION("zsh")
    {
        shell.SetShellPath("/bin/zsh");
        shell.SetEnvVar("PS1", ">");
        shell.AddCustomShellArgument("zsh");
        shell.AddCustomShellArgument("-f");
    }
    SECTION("csh")
    {
        shell.SetShellPath("/bin/csh");
    }
    SECTION("tcsh")
    {
        shell.SetShellPath("/bin/tcsh");
    }
    shell.SetOnChildOutput([&](const void *_d, int _sz) {
        if( auto cmds = parser.Parse({(const std::byte *)_d, (size_t)_sz}); !cmds.empty() ) {
            if( auto lock = screen.AcquireLock() ) {
                interpreter.Interpret(cmds);
                buffer_dump.store(screen.Buffer().DumpScreenAsANSI());
            }
        }
    });
    shell.Launch(dir.directory);
    
    if( shell.GetShellType() == ShellTask::ShellType::TCSH ) {
        shell.WriteChildInput("set prompt='>'\rclear\r");
    }

    shell.WriteChildInput("vim vim_test\r"); // vim vim_test Return
    const auto expected1 = "                                        "
                           "~                                       "
                           "~                                       "
                           "~                                       "
                           "~                                       "
                           "~                                       "
                           "~                                       "
                           "~                                       "
                           "~                                       "
                           "\"vim_test\" [New File]                   ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected1));

    shell.WriteChildInput("i1\r2\r3\r4\r5\r\eOA\eOA\r"); // i 1 Return 2 Return 3 Return 4 Return 5
                                                         // Return Up Up Return
    const auto expected2 = "1                                       "
                           "2                                       "
                           "3                                       "
                           "                                        "
                           "4                                       "
                           "5                                       "
                           "                                        "
                           "~                                       "
                           "~                                       "
                           "-- INSERT --                            ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected2));

    shell.WriteChildInput("\x1b:q!\r"); // Esc : q ! Return
    const auto expected3 = ">vim vim_test                           "
                           ">                                       "
                           "                                        "
                           "                                        "
                           "                                        "
                           "                                        "
                           "                                        "
                           "                                        "
                           "                                        "
                           "                                        ";
    REQUIRE(buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected3));
}

TEST_CASE(PREFIX "Test multiple shells in parallel via output")
{
    const TempTestDir dir;
    constexpr size_t number = 50; // just casually spawn 50 shells, not a big deal...
        
    struct Context {
        AtomicHolder<std::string> buffer_dump;
        AtomicHolder<ShellTask::TaskState> shell_state;
        Screen screen{20, 5};
        Parser2Impl parser;
        InterpreterImpl interpreter{screen};
        ShellTask shell;
    };
    std::array<Context, number> shells;

    SECTION("bash")
    {
        for( auto &ctx : shells ) {
            ctx.shell.SetShellPath("/bin/bash");
            ctx.shell.SetEnvVar("PS1", ">");
            ctx.shell.AddCustomShellArgument("bash");
        }
    }
    SECTION("zsh")
    {
        for( auto &ctx : shells ) {
            ctx.shell.SetShellPath("/bin/zsh");
            ctx.shell.SetEnvVar("PS1", ">");
            ctx.shell.AddCustomShellArgument("zsh");
            ctx.shell.AddCustomShellArgument("-f");
        }
    }
    SECTION("csh")
    {
        for( auto &ctx : shells ) {
            ctx.shell.SetShellPath("/bin/csh");
        }
    }
    SECTION("tcsh")
    {
        for( auto &ctx : shells ) {
            ctx.shell.SetShellPath("/bin/tcsh");
        }
    }
    for( auto &ctx : shells ) {
        ctx.shell.ResizeWindow(20, 5);
        ctx.shell.SetOnChildOutput([&](const void *_d, int _sz) {
            if( auto cmds = ctx.parser.Parse({(const std::byte *)_d, (size_t)_sz}); !cmds.empty() ) {
                if( auto lock = ctx.screen.AcquireLock() ) {
                    ctx.interpreter.Interpret(cmds);
                    ctx.buffer_dump.store(ctx.screen.Buffer().DumpScreenAsANSI());
                }
            }
        });
        ctx.shell.SetOnStateChange(
            [&](ShellTask::TaskState _new_state) { ctx.shell_state.store(_new_state); });
        ctx.shell.Launch(dir.directory);

        if( ctx.shell.GetShellType() == ShellTask::ShellType::TCSH )
            ctx.shell.WriteChildInput("set prompt='>'\rclear\r");
    }
    
    // wait until each shell wakes up
    for( size_t i = 0; i != number; ++i ) {
        const std::string expected = ">                   "
                                     "                    "
                                     "                    "
                                     "                    "
                                     "                    ";
        REQUIRE(shells[i].buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected));
    }
    
    // write the shell number to each shell
    for( size_t i = 0; i != number; ++i ) {
        const std::string msg = "Hi," + std::to_string(i);
        shells[i].shell.WriteChildInput(msg);
    }
    
    // wait until each shell dispays it
    for( size_t i = 0; i != number; ++i ) {
        const std::string msg = "Hi," + std::to_string(i);
        std::string line = ">                   ";
        line.replace(1, msg.size(), msg);
        const std::string expected = line + "                    "
                                            "                    "
                                            "                    "
                                            "                    ";
        REQUIRE(shells[i].buffer_dump.wait_to_become_with_runloop(5s, 1ms, expected));
    }
    
    // now tell all the shell to bugger off
    for( auto &ctx : shells )
        ctx.shell.Terminate();
    
    // and wait until there were none
    for( auto &ctx : shells )
        REQUIRE(ctx.shell_state.wait_to_become(5s, TaskState::Inactive));
}
