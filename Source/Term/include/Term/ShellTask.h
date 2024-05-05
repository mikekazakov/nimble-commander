// Copyright (C) 2013-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Task.h"
#include <filesystem>
#include <functional>
#include <string>
#include <thread>

// RTFM: https://hyperpolyglot.org/unix-shells

namespace nc::term {

class ShellTask : public Task
{
public:
    enum class TaskState {

        // initial state - shell is not initialized and is not running
        Inactive = 0,

        // shell is running normally
        Shell = 1,

        // a child program is running under shell, executed from it's command
        // line
        ProgramInternal = 2,

        // a child program is running under shell, executed from NC's UI.
        // shell gets this state right before the actual execution, i.e. there's
        // a bit of delay the child process is spawned.
        ProgramExternal = 3,

        // shell died
        Dead = 4
    };

    enum class ShellType {
        Unknown = -1,
        Bash = 0,
        ZSH = 1,
        TCSH = 2
    };

    using OnStateChange = std::function<void(TaskState _new_state)>;
    using OnPwdPrompt = std::function<void(const char *_cwd, bool _changed)>;
    using OnChildOutput = std::function<void(const void *_d, size_t _sz)>;

    ShellTask();
    ~ShellTask();

    // TODO: describe, change to std::span
    void SetOnChildOutput(OnChildOutput _callback);

    // _callback can be called from a background thread
    void SetOnPwdPrompt(OnPwdPrompt _callback);

    /**
     * Set a callback to be notified each time the shell state changes.
     * _callback can be called from a background thread.
     */
    void SetOnStateChange(OnStateChange _callback);

    /**
     * Sets the desired custom shell path.
     * If none was specified - default login shell will be used.
     * Should be called before Launch().
     */
    void SetShellPath(const std::string &_path);

    /**
     * Adds an argument to be passed to the shell upon startup.
     * This will OVERRIDE the default ones that ShellTask automatically feeds
     * the shell with.
     */
    void AddCustomShellArgument(std::string_view argument);

    /**
     * Sets a value to be fed into the spawned shell task ***upon startup***.
     */
    void SetEnvVar(const std::string &_var, const std::string &_value);

    // Launches current shell at _work_dir
    bool Launch(const std::filesystem::path &_work_dir);

    void Terminate();

    /**
     * Asks shell to change current working directory.
     * TaskState should be Shell, otherwise will do nothing.
     * Does sync I/O on access checking, thus may cause blocking.
     * Thread-safe.
     */
    void ChDir(const std::filesystem::path &_new_cwd);

    /**
     * executes a binary file in a directory using ./filename.
     * _at can be NULL. if it is the same as CWD - then ignored.
     * _parameters can be NULL. if they are not NULL - this string should be
     * escaped in advance - this function doesn't convert is anyhow.
     */
    void Execute(const char *_short_fn, const char *_at, const char *_parameters);

    /**
     * executes a binary by a full path.
     * _parameters can be NULL.
     */
    void ExecuteWithFullPath(const char *_path, const char *_parameters);

    // TODO: describe
    void ExecuteWithFullPath(const std::filesystem::path &_binary_path, std::span<const std::string> _arguments);

    /**
     * Can be used in any TermShellTask state.
     * If shell is alive - will send actual resize signal, otherwise will only
     * set internal width and height.
     */
    void ResizeWindow(int _sx, int _sy);

    /**
     * Feeds child process with arbitrary input data.
     * Task state should not be Inactive or Dead.
     * Thread-safe.
     */
    void WriteChildInput(std::string_view _data);

    /**
     * Returns the current shell task state.
     * Thread-safe.
     */
    TaskState State() const;

    /**
     * Current working directory. With trailing slash, in form: /Users/migun/.
     * Return string by value to minimize potential chance to get race
     * condition. Thread-safe.
     */
    std::string CWD() const;

    /**
     * returns a list of children excluding topmost shell (ie bash).
     * Thread-safe.
     */
    std::vector<std::string> ChildrenList() const;

    /**
     * Returns  a PID of a shell if any, -1 otherwise.
     * Thread-safe.
     */
    int ShellPID() const;

    /**
     * Returns  a PID of a process currently executed by a shell.
     * Will return -1 if there's no children on shell or on any errors.
     * Based on same mech as ChildrenList() so may be time-costly.
     * Thread-safe.
     */
    int ShellChildPID() const;

    /**
     * Returns a shell type, depending on a startup path, regardless of an actual state
     */
    ShellType GetShellType() const;

private:
    ShellTask(const ShellTask &) = delete;
    ShellTask &operator=(const ShellTask &) = delete;

    bool IsCurrentWD(const char *_what) const;
    char **BuildShellArgs() const;
    std::string ComposePromptCommand() const;
    struct Impl;
    std::unique_ptr<Impl> I;
};

} // namespace nc::term
