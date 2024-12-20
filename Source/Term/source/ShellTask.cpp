// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ShellTask.h"
#include "Log.h"
#include <Base/CloseFrom.h>
#include <Base/CommonPaths.h>
#include <Base/algo.h>
#include <Base/dispatch_cpp.h>
#include <Base/mach_time.h>
#include <Base/spinlock.h>
#include <CoreFoundation/CoreFoundation.h>
#include <Utility/PathManip.h>
#include <Utility/SystemInformation.h>
#include <algorithm>
#include <cerrno>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <fcntl.h>
#include <fmt/format.h>
#include <fmt/std.h>
#include <iostream>
#include <libproc.h>
#include <memory_resource>
#include <queue>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <termios.h>
#include <unistd.h>

namespace nc::term {

static const int g_PromptPipe = 20;
static const int g_SemaphorePipe = 21;
static int g_TCSHPipeGeneration = 0;

static char *g_BashParams[3] = {const_cast<char *>("bash"), const_cast<char *>("--login"), nullptr};
static char *g_ZSHParams[3] = {const_cast<char *>("-Z"), const_cast<char *>("-g"), nullptr};
static char *g_TCSH[2] = {const_cast<char *>("tcsh"), nullptr};
static char **g_ShellParams[3] = {g_BashParams, g_ZSHParams, g_TCSH};

static char g_BashHistControlEnv[] = "HISTCONTROL=ignorespace";
static const char *g_ZSHHistControlCmd = "setopt HIST_IGNORE_SPACE\n";

static bool IsDirectoryAvailableForBrowsing(const char *_path) noexcept;
static bool IsDirectoryAvailableForBrowsing(const std::string &_path) noexcept;
static std::string GetDefaultShell();
static bool WaitUntilBecomes(int _pid,
                             std::string_view _expected_image_path,
                             std::chrono::nanoseconds _timeout,
                             std::chrono::nanoseconds _pull_period) noexcept;
static ShellTask::ShellType DetectShellType(const std::string &_path);
static bool fd_is_valid(int fd);
static void KillAndReap(int _pid, std::chrono::nanoseconds _gentle_deadline, std::chrono::nanoseconds _brutal_deadline);
static void TurnOffSigPipe();
static bool IsProcessDead(int _pid) noexcept;
static std::optional<std::filesystem::path> TryToResolve(const std::filesystem::path &_path);

static bool IsDirectoryAvailableForBrowsing(const char *_path) noexcept
{
    DIR *dirp = opendir(_path);
    if( dirp == nullptr )
        return false;
    closedir(dirp);
    return true;
}

static bool IsDirectoryAvailableForBrowsing(const std::string &_path) noexcept
{
    return IsDirectoryAvailableForBrowsing(_path.c_str());
}

static std::string GetDefaultShell()
{
    if( const char *shell = getenv("SHELL") )
        return shell;
    else // setup is very weird
        return "/bin/bash";
}

static bool IsProcessDead(int _pid) noexcept
{
    const bool dead = kill(_pid, 0) < 0;
    return dead && errno == ESRCH;
}

static bool WaitUntilBecomes(int _pid,
                             std::string_view _expected_image_path,
                             std::chrono::nanoseconds _timeout,
                             std::chrono::nanoseconds _pull_period) noexcept
{
    const auto deadline = base::machtime() + _timeout;
    while( true ) {
        if( IsProcessDead(_pid) )
            return false;

        char current_path[PROC_PIDPATHINFO_MAXSIZE] = {0};
        if( proc_pidpath(_pid, current_path, sizeof(current_path)) <= 0 )
            return false;
        if( current_path == _expected_image_path )
            return true;

        if( base::machtime() >= deadline )
            return false;
        std::this_thread::sleep_for(_pull_period);
    }
}

static ShellTask::ShellType DetectShellType(const std::string &_path)
{
    if( _path.find("/bash") != std::string::npos )
        return ShellTask::ShellType::Bash;
    if( _path.find("/zsh") != std::string::npos )
        return ShellTask::ShellType::ZSH;
    if( _path.find("/tcsh") != std::string::npos )
        return ShellTask::ShellType::TCSH;
    if( _path.find("/csh") != std::string::npos )
        return ShellTask::ShellType::TCSH;
    return ShellTask::ShellType::Unknown;
}

static bool fd_is_valid(int fd)
{
    return fcntl(fd, F_GETFD) != -1 || errno != EBADF;
}

static void TurnOffSigPipe()
{
    static std::once_flag once;
    std::call_once(once, [] { signal(SIGPIPE, SIG_IGN); });
}

static void KillAndReap(int _pid, std::chrono::nanoseconds _gentle_deadline, std::chrono::nanoseconds _brutal_deadline)
{
    constexpr auto poll_wait = std::chrono::milliseconds(1);
    // 1st attempt - do with a gentle SIGTERM
    kill(_pid, SIGTERM);
    int status = 0;
    int waitpid_rc = 0;
    const auto gentle_deadline = base::machtime() + _gentle_deadline;
    while( true ) {
        waitpid_rc = waitpid(_pid, &status, WNOHANG | WUNTRACED);

        if( waitpid_rc != 0 )
            break;

        if( base::machtime() >= gentle_deadline )
            break;

        std::this_thread::sleep_for(poll_wait);
    }

    if( waitpid_rc > 0 ) {
        // 2nd attemp - bruteforce
        kill(_pid, SIGKILL);
        const auto brutal_deadline = base::machtime() + _brutal_deadline;
        while( true ) {
            waitpid_rc = waitpid(_pid, &status, WNOHANG | WUNTRACED);
            if( waitpid_rc != 0 )
                break;

            if( base::machtime() >= brutal_deadline ) {
                // at this point we give up and let the child linger in limbo/zombie state.
                // I have no idea what to do with the marvelous MacOS thing called
                // "E - The process is trying to exit". Subprocesses can fall into this state
                // with some low propability, deadlocking a blocking waitpid() forever.
                std::cerr << "Letting go a child at PID " << _pid << '\n';
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }
}

static std::optional<std::filesystem::path> TryToResolve(const std::filesystem::path &_path)
{
    std::error_code ec;
    const bool exists = std::filesystem::exists(_path, ec);
    if( ec == std::error_code{} && exists ) {
        const bool is_symlink = std::filesystem::is_symlink(_path, ec);
        if( ec == std::error_code{} && is_symlink ) {
            auto symlink = std::filesystem::read_symlink(_path, ec);
            if( ec != std::error_code{} )
                return {};
            if( symlink.is_absolute() )
                return symlink;
            else
                return (_path.parent_path() / symlink).lexically_normal();
        }
    }
    return {};
}

struct ShellTask::Impl {
    Impl();
    Impl(const Impl &) = delete;
    ~Impl();
    Impl &operator=(const Impl &) = delete;

    // The IO queue and group have the same lifetime as the Impl object itself, cleaning up doesn't discard them, only
    // destructor does.
    dispatch_queue_t io_queue = nullptr;
    dispatch_group_t io_group = nullptr;

    // accessible from any thread:
    std::mutex lock;
    dispatch_source_t master_source = nullptr;
    dispatch_source_t cwd_source = nullptr;
    TaskState state = TaskState::Inactive;
    int master_fd = -1;
    std::atomic_int shell_pid{-1};
    int cwd_pipe[2] = {-1, -1};
    int semaphore_pipe[2] = {-1, -1};
    std::string tcsh_cwd_path;
    std::string tcsh_semaphore_path;

    bool temporary_suppressed = false; // will give no output until a next bash prompt will show the requested_cwd path
    std::string requested_cwd;
    std::string cwd;

    // accessible from main thread only (presumably)
    int term_sx = 80;
    int term_sy = 25;
    std::filesystem::path shell_path;
    std::filesystem::path shell_resolved_path; // may differ from shell_path if that's a symlink
    ShellType shell_type = ShellType::Unknown;
    std::vector<std::pair<std::string, std::string>> custom_env_vars;
    std::vector<std::string> custom_shell_args;

    spinlock master_write_lock;

    // reading and writing the callbacks has to be protected with the lock
    mutable spinlock callback_lock;
    std::shared_ptr<OnPwdPrompt> on_pwd_prompt;
    std::shared_ptr<OnStateChange> on_state_changed;
    std::shared_ptr<OnChildOutput> on_child_output;

    void OnMasterSourceData();
    void OnMasterSourceCancellation() const;
    void OnCwdSourceData();
    void OnCwdSourceCancellation();
    void OnShellDied();
    void ProcessPwdPrompt(const void *_d, int _sz);
    void DoCalloutOnChildOutput(const void *_d, size_t _sz);
    void DoOnPwdPromptCallout(const char *_cwd, bool _changed) const;
    void SetState(TaskState _new_state);
    void CleanUp();
    void DoCleanUp();
};

ShellTask::ShellTask() : I(std::make_unique<Impl>())
{
    SetShellPath(GetDefaultShell());
    TurnOffSigPipe();
}

ShellTask::~ShellTask()
{
    I->CleanUp();
}

ShellTask::Impl::Impl()
{
    // The I/O queue has to be serial
    io_queue = dispatch_queue_create("nc::term::ShellTask I/O", DISPATCH_QUEUE_SERIAL);
    io_group = dispatch_group_create();
}

ShellTask::Impl::~Impl()
{
    dispatch_release(io_group);
    dispatch_release(io_queue);
}

bool ShellTask::Launch(const std::filesystem::path &_work_dir)
{
    using namespace std::literals;

    // TODO: write integration tests for double Launch
    if( I->state != TaskState::Inactive )
        throw std::logic_error("ShellTask::Launch called when the object is not pristine");

    if( I->shell_type == ShellType::Unknown )
        return false;

    I->cwd = _work_dir.generic_string();
    Log::Info("Starting a new shell: {}", I->shell_path);
    if( I->shell_resolved_path != I->shell_path )
        Log::Info("{} -> {}", I->shell_path, I->shell_resolved_path);
    Log::Info("Initial work directory: {}", I->cwd);

    // remember current locale and stuff
    const auto env = BuildEnv();
    Log::Debug("Environment:");
    for( auto &env_record : env )
        Log::Debug("\t{} = {}", env_record.first, env_record.second);

    // open a pseudo-terminal device
    const int openpt_rc = posix_openpt(O_RDWR);
    if( openpt_rc < 0 ) {
        Log::Warn("posix_openpt() returned a negative value");
        throw std::runtime_error("posix_openpt() returned a negative value");
    }
    Log::Debug("posix_openpt(O_RDWR) returned {} (master_fd)", openpt_rc);
    I->master_fd = openpt_rc;

    // grant access to the slave pseudo-terminal device
    const int graptpt_rc = grantpt(I->master_fd);
    if( graptpt_rc != 0 ) {
        Log::Warn("graptpt_rc() failed");
        throw std::runtime_error("graptpt_rc() failed");
    }

    // unlock a pseudo-terminal master/slave pair
    const int unlockpt_rc = unlockpt(I->master_fd);
    if( unlockpt_rc != 0 ) {
        Log::Warn("unlockpt() failed");
        throw std::runtime_error("unlockpt() failed");
    }

    // get name of the slave pseudo-terminal device
    const char *const ptsname = ::ptsname(I->master_fd);
    if( ptsname == nullptr ) {
        Log::Warn("ptsname() failed");
        throw std::runtime_error("ptsname() failed");
    }
    Log::Debug("ptsname: {}", ptsname);

    // opening a slave fd for the pseudo-terminal
    const int slave_fd = open(ptsname, O_RDWR);
    if( openpt_rc < 0 ) {
        Log::Warn("open() returned a negative value");
        throw std::runtime_error("open() returned a negative value");
    }
    Log::Debug("slave_fd: {}", slave_fd);

    // init FIFO stuff for Shell's CWD
    if( I->shell_type == ShellType::Bash || I->shell_type == ShellType::ZSH ) {
        // for Bash and ZSH use a regular pipe handle
        const int cwd_pipe_rc = pipe(I->cwd_pipe);
        if( cwd_pipe_rc != 0 ) {
            Log::Warn("pipe(I->cwd_pipe) failed");
            throw std::runtime_error("pipe(I->cwd_pipe) failed");
        }

        const int semaphore_pipe_rc = pipe(I->semaphore_pipe);
        if( semaphore_pipe_rc != 0 ) {
            Log::Warn("pipe(I->semaphore_pipe) failed");
            throw std::runtime_error("pipe(I->semaphore_pipe) failed");
        }
    }
    else if( I->shell_type == ShellType::TCSH ) {
        // for TCSH use named fifo file. supporting [t]csh was a mistake :(
        const auto &dir = base::CommonPaths::AppTemporaryDirectory();
        const auto mypid = std::to_string(getpid());
        const auto gen = std::to_string(g_TCSHPipeGeneration++);

        // open the cwd channel first
        I->tcsh_cwd_path = dir + "nimble_commander.tcsh.cwd_pipe." + mypid + "." + gen;
        Log::Debug("tcsh_cwd_path: {}", I->tcsh_cwd_path);

        const int cwd_fifo_rc = mkfifo(I->tcsh_cwd_path.c_str(), 0600);
        if( cwd_fifo_rc != 0 ) {
            Log::Warn("mkfifo(I->tcsh_cwd_path.c_str(), 0600) failed");
            throw std::runtime_error("mkfifo(I->tcsh_cwd_path.c_str(), 0600) failed");
        }

        const int cwd_open_rc = open(I->tcsh_cwd_path.c_str(), O_RDWR);
        if( cwd_open_rc < 0 ) {
            Log::Warn("open(I->tcsh_cwd_path.c_str(), O_RDWR) failed");
            throw std::runtime_error("open(I->tcsh_cwd_path.c_str(), O_RDWR) failed");
        }
        I->cwd_pipe[0] = cwd_open_rc;

        // and then open the semaphore channel
        I->tcsh_semaphore_path = dir + "nimble_commander.tcsh.semaphore_pipe." + mypid + "." + gen;
        Log::Debug("tcsh_semaphore_path: {}", I->tcsh_semaphore_path);

        const int semaphore_fifo_rc = mkfifo(I->tcsh_semaphore_path.c_str(), 0600);
        if( semaphore_fifo_rc != 0 ) {
            Log::Warn("mkfifo(I->tcsh_semaphore_path.c_str(), 0600) failed");
            throw std::runtime_error("mkfifo(I->tcsh_semaphore_path.c_str(), 0600) failed");
        }

        const int semaphore_open_rc = open(I->tcsh_semaphore_path.c_str(), O_RDWR);
        if( semaphore_open_rc < 0 ) {
            Log::Warn("open(I->tcsh_semaphore_path.c_str(), O_RDWR) failed");
            throw std::runtime_error("open(I->tcsh_semaphore_path.c_str(), O_RDWR) failed");
        }

        I->semaphore_pipe[1] = semaphore_open_rc;
    }

    Log::Debug("cwd_pipe: {}, {}", I->cwd_pipe[0], I->cwd_pipe[1]);
    Log::Debug("semaphore_pipe: {}, {}", I->semaphore_pipe[0], I->semaphore_pipe[1]);

    // Create the child process
    const auto fork_rc = fork();
    if( fork_rc < 0 ) {
        // error
        std::cerr << "fork() failed with " << errno << "!" << '\n';
        return false;
    }
    else if( fork_rc > 0 ) {
        Log::Debug("fork() returned {}", fork_rc);

        // master
        I->shell_pid = fork_rc;
        close(slave_fd);
        close(I->cwd_pipe[1]);
        close(I->semaphore_pipe[0]);
        I->temporary_suppressed = true; /// HACKY!!!

        // wait until either the forked process becomes an expected shell or dies
        const bool became_shell = WaitUntilBecomes(I->shell_pid, I->shell_resolved_path.native(), 5s, 1ms);
        if( !became_shell ) {
            Log::Warn("forked process failed to become a shell!");
            I->CleanUp(); // Well, RIP
            return false;
        }

        if( !fd_is_valid(I->master_fd) ) {
            Log::Warn("m_MasterFD is dead!");
            I->CleanUp(); // Well, RIP
            return false;
        }

        // set up libdispatch sources here
        I->master_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, I->master_fd, 0, I->io_queue);
        dispatch_source_set_event_handler_f(
            I->master_source, +[](void *_ctx) { static_cast<Impl *>(_ctx)->OnMasterSourceData(); });
        dispatch_source_set_cancel_handler_f(
            I->master_source, +[](void *_ctx) { static_cast<Impl *>(_ctx)->OnMasterSourceCancellation(); });
        dispatch_set_context(I->master_source, I.get());
        dispatch_activate(I->master_source);

        I->cwd_source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, I->cwd_pipe[0], 0, I->io_queue);
        dispatch_source_set_event_handler_f(
            I->cwd_source, +[](void *_ctx) { static_cast<Impl *>(_ctx)->OnCwdSourceData(); });
        dispatch_source_set_cancel_handler_f(
            I->cwd_source, +[](void *_ctx) { static_cast<Impl *>(_ctx)->OnCwdSourceCancellation(); });
        dispatch_set_context(I->cwd_source, I.get());
        dispatch_activate(I->cwd_source);

        if( I->shell_type == ShellType::ZSH ) {
            // say ZSH to not put into history any commands starting with space character
            auto cmd = std::string_view(g_ZSHHistControlCmd);
            I->master_write_lock.lock();
            const ssize_t write_res = write(I->master_fd, cmd.data(), cmd.length());
            I->master_write_lock.unlock();
            if( write_res != static_cast<ssize_t>(cmd.length()) ) {
                Log::Warn("failed to write histctrl cmd, errno: {} ({})", errno, strerror(errno));
                I->CleanUp(); // Well, RIP
                return false;
            }
        }

        // write prompt setup to the shell
        const std::string prompt_setup = ComposePromptCommand();
        Log::Debug("prompt_setup: {}", prompt_setup);
        I->master_write_lock.lock();
        const ssize_t write_res = write(I->master_fd, prompt_setup.data(), prompt_setup.size());
        I->master_write_lock.unlock();
        if( write_res != static_cast<ssize_t>(prompt_setup.size()) ) {
            Log::Warn("failed to write command prompt, errno: {} ({})", errno, strerror(errno));
            I->CleanUp(); // Well, RIP
            return false;
        }

        // now let's declare that we have a working shell
        I->SetState(TaskState::Shell);

        return true;
    }
    else { // fork_rc == 0
        // slave/child
        SetupTermios(slave_fd);
        SetTermWindow(slave_fd, static_cast<unsigned short>(I->term_sx), static_cast<unsigned short>(I->term_sy));
        SetupHandlesAndSID(slave_fd);

        chdir(_work_dir.generic_string().c_str());

        // put basic environment stuff
        SetEnv(env);

        // put custom variables if any
        SetEnv(I->custom_env_vars);

        if( I->shell_type != ShellType::TCSH ) {
            // setup piping for CWD prompt
            // using FDs g_PromptPipe/g_SemaphorePipe becuse bash is closing fds [3,20) upon
            // opening in logon mode (our case)
            const int cwd_dup_rc = dup2(I->cwd_pipe[1], g_PromptPipe);
            if( cwd_dup_rc != g_PromptPipe )
                exit(-1);

            const int semaphore_dup_rc = dup2(I->semaphore_pipe[0], g_SemaphorePipe);
            if( semaphore_dup_rc != g_SemaphorePipe )
                exit(-1);
        }

        if( I->shell_type == ShellType::Bash ) {
            // say BASH to not put into history any commands starting with space character
            putenv(g_BashHistControlEnv);
        }

        // close all file descriptors except [0], [1], [2] and [g_PromptPipe][g_SemaphorePipe]
        nc::base::CloseFromExcept(3, std::array<int, 2>{g_PromptPipe, g_SemaphorePipe});

        // execution of the program
        execv(I->shell_resolved_path.c_str(), BuildShellArgs());

        // we never get here in normal condition
        exit(-1);
    }
}

void ShellTask::SetOnChildOutput(OnChildOutput _callback)
{
    auto local = std::lock_guard{I->callback_lock};
    I->on_child_output = std::make_shared<OnChildOutput>(std::move(_callback));
}

void ShellTask::Impl::OnMasterSourceData()
{
    dispatch_assert_background_queue();
    const size_t estimated_size = dispatch_source_get_data(master_source);
    Log::Trace("OnMasterSourceData() estimated {} bytes available", estimated_size);
    if( estimated_size == 0 ) {
        // GCD reports dead FDs as zero available data
        OnShellDied();
        return;
    }

    constexpr size_t input_sz = 8192;
    char input[input_sz];
    // There's a data on the master side of PTY (some child's output)
    // Need to consume it first as it can be suppressed and we want to eat it before opening a
    // shell's semaphore.
    const ssize_t have_read = read(master_fd, input, input_sz);
    if( have_read > 0 ) {
        if( !temporary_suppressed ) {
            DoCalloutOnChildOutput(input, have_read);
        }
    }
}

void ShellTask::Impl::OnCwdSourceData()
{
    dispatch_assert_background_queue(); // must be called on io_queue
    const size_t estimated_size = dispatch_source_get_data(master_source);
    Log::Trace("OnCwdSourceData() estimated {} bytes available", estimated_size);
    if( estimated_size == 0 ) {
        // GCD reports dead FDs as zero available data
        OnShellDied();
        return;
    }

    constexpr size_t input_sz = 8192;
    char input[input_sz];
    const ssize_t have_read = read(cwd_pipe[0], input, input_sz);
    if( have_read > 0 ) {
        ProcessPwdPrompt(input, static_cast<int>(have_read));
    }
}

void ShellTask::Impl::OnMasterSourceCancellation() const
{
    dispatch_assert_background_queue(); // must be called on io_queue
    Log::Trace("ShellTask::Impl::OnMasterSourceCancellation() called");
    assert(master_fd >= 0); // shall be closed later in DoCleanUp() but must be alive by now
}

void ShellTask::Impl::OnCwdSourceCancellation()
{
    dispatch_assert_background_queue(); // must be called on io_queue
    Log::Trace("ShellTask::Impl::OnCwdSourceCancellation() called");
    assert(cwd_pipe[0] >= 0); // shall be closed later in DoCleanUp() but must be alive by now
}

void ShellTask::Impl::DoCalloutOnChildOutput(const void *_d, size_t _sz)
{
    callback_lock.lock();
    auto clbk = on_child_output;
    callback_lock.unlock();

    if( clbk && *clbk && _sz && _d )
        (*clbk)(_d, _sz);
}

void ShellTask::Impl::ProcessPwdPrompt(const void *_d, int _sz)
{
    dispatch_assert_background_queue();
    std::string current_cwd = cwd;
    bool do_nr_hack = false;
    bool current_wd_changed = false;

    std::string new_cwd(static_cast<const char *>(_d), _sz);
    while( !new_cwd.empty() && (new_cwd.back() == '\n' || new_cwd.back() == '\r') )
        new_cwd.pop_back();
    new_cwd = EnsureTrailingSlash(new_cwd);
    Log::Info("pwd prompt from shell_pid={}: {}", shell_pid.load(), new_cwd);

    {
        const auto lock_g = std::lock_guard{lock};

        cwd = new_cwd;

        if( current_cwd != cwd ) {
            current_cwd = cwd;
            current_wd_changed = true;
        }

        if( state == TaskState::ProgramExternal || state == TaskState::ProgramInternal ) {
            // shell just finished running something - let's back it to StateShell state
            SetState(TaskState::Shell);
        }

        if( temporary_suppressed && (requested_cwd.empty() || requested_cwd == cwd) ) {
            temporary_suppressed = false;
            if( !requested_cwd.empty() ) {
                requested_cwd = "";
                do_nr_hack = true;
            }
        }
    }

    if( requested_cwd.empty() )
        DoOnPwdPromptCallout(current_cwd.c_str(), current_wd_changed);
    if( do_nr_hack )
        DoCalloutOnChildOutput("\n\r", 2);

    write(semaphore_pipe[1], "OK\n\r", 4);
}

void ShellTask::Impl::DoOnPwdPromptCallout(const char *_cwd, bool _changed) const
{
    callback_lock.lock();
    auto on_pwd = on_pwd_prompt;
    callback_lock.unlock();

    if( on_pwd && *on_pwd )
        (*on_pwd)(_cwd, _changed);
}

void ShellTask::WriteChildInput(std::string_view _data)
{
    if( I->state == TaskState::Inactive || I->state == TaskState::Dead )
        return;
    if( _data.empty() )
        return;

    {
        const auto lock = std::lock_guard{I->master_write_lock};
        const ssize_t rc = write(I->master_fd, _data.data(), _data.size());
        if( rc < 0 || rc != static_cast<ssize_t>(_data.size()) )
            std::cerr << "write( m_MasterFD, _data.data(), _data.size() ) returned " << rc << '\n';
    }

    if( (_data.back() == '\n' || _data.back() == '\r') && I->state == TaskState::Shell ) {
        const auto lock = std::lock_guard{I->lock};
        I->SetState(TaskState::ProgramInternal);
    }
}

void ShellTask::Impl::CleanUp()
{
    // first we must ensure that the dispatch sources (if any) are cancelled BEFORE calling DoCleanUp()
    dispatch_group_async_f(
        io_group, io_queue, this, +[](void *_ctx) {
            Impl *me = static_cast<Impl *>(_ctx);
            if( me->master_source != nullptr )
                dispatch_source_cancel(me->master_source);
            if( me->cwd_source != nullptr )
                dispatch_source_cancel(me->cwd_source);
        });
    // wait until it completes and possibly GCD submits cancellation blocks
    dispatch_group_wait(io_group, DISPATCH_TIME_FOREVER);

    // next dispatch a request for the cleanup and wait until it completes
    dispatch_group_async_f(io_group, io_queue, this, +[](void *_ctx) { static_cast<Impl *>(_ctx)->DoCleanUp(); });
    dispatch_group_wait(io_group, DISPATCH_TIME_FOREVER);
}

void ShellTask::Impl::DoCleanUp()
{
    // this method shall be called only on the io_queue.
    dispatch_assert_background_queue();
    const std::lock_guard lockg{lock};

    if( shell_pid > 0 ) {
        const int pid = shell_pid;
        shell_pid = -1;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0),
                       [pid] { KillAndReap(pid, std::chrono::milliseconds(400), std::chrono::milliseconds(1000)); });
    }

    if( master_source != nullptr ) {
        // the source must be already cancelled before sheduling this cleanup call
        assert(dispatch_source_testcancel(master_source));
        dispatch_release(master_source);
        master_source = nullptr;
    }

    if( cwd_source != nullptr ) {
        // the source must be already cancelled before sheduling this cleanup call
        assert(dispatch_source_testcancel(cwd_source));
        dispatch_release(cwd_source);
        cwd_source = nullptr;
    }

    if( master_fd >= 0 ) {
        close(master_fd);
        master_fd = -1;
    }

    if( cwd_pipe[0] >= 0 ) {
        close(cwd_pipe[0]);
        cwd_pipe[0] = cwd_pipe[1] = -1;
    }

    if( semaphore_pipe[1] >= 0 ) {
        close(semaphore_pipe[1]);
        semaphore_pipe[0] = semaphore_pipe[1] = -1;
    }

    if( !tcsh_cwd_path.empty() ) {
        unlink(tcsh_cwd_path.c_str());
        tcsh_cwd_path.clear();
    }

    if( !tcsh_semaphore_path.empty() ) {
        unlink(tcsh_semaphore_path.c_str());
        tcsh_semaphore_path.clear();
    }

    temporary_suppressed = false;
    requested_cwd = "";
    cwd = "";

    SetState(TaskState::Inactive);
}

void ShellTask::Impl::OnShellDied()
{
    dispatch_assert_background_queue();

    // no need to call it if PID is already set to invalid - we're in closing state
    if( shell_pid <= 0 )
        return; // wtf this even is??
    if( state == TaskState::Dead || state == TaskState::Inactive )
        return; // guard against competing calls from two GCD callbacks (master and cwd fds)

    SetState(TaskState::Dead);

    dispatch_source_cancel(master_source);
    dispatch_source_cancel(cwd_source);
    dispatch_group_async_f(io_group, io_queue, this, +[](void *_ctx) { static_cast<Impl *>(_ctx)->DoCleanUp(); });
}

void ShellTask::Impl::SetState(TaskState _new_state)
{
    if( state == _new_state )
        return;

    state = _new_state;

    callback_lock.lock();
    auto callback = on_state_changed;
    callback_lock.unlock();

    if( callback && *callback )
        (*callback)(_new_state);
}

void ShellTask::ChDir(const std::filesystem::path &_new_cwd)
{
    if( I->state != TaskState::Shell )
        return;

    const auto requested_cwd = EnsureTrailingSlash(_new_cwd.generic_string());

    {
        const auto lock = std::lock_guard{I->lock};
        if( I->cwd == requested_cwd )
            return; // do nothing if current working directory is the same as requested
    }

    // file I/O here
    if( !IsDirectoryAvailableForBrowsing(requested_cwd) )
        return;

    {
        const auto lock = std::lock_guard{I->lock};
        I->temporary_suppressed = true; // will show no output of shell when changing a directory
        I->requested_cwd = requested_cwd;
    }

    // now compose a command to feed the shell with
    std::string child_feed;
    // pass ctrl+C to shell to ensure that no previous user input (if any) will stay
    child_feed += "\x03";
    child_feed += " cd ";
    // cd command don't like trailing slashes, so remove it
    child_feed += EscapeShellFeed(EnsureNoTrailingSlash(requested_cwd));
    child_feed += "\n";

    // and send it
    WriteChildInput(child_feed);
}

bool ShellTask::IsCurrentWD(const char *_what) const
{
    char cwd[MAXPATHLEN];
    strcpy(cwd, _what);

    if( !utility::PathManip::HasTrailingSlash(cwd) )
        strcat(cwd, "/");

    return I->cwd == cwd;
}

void ShellTask::Execute(const char *_short_fn, const char *_at, const char *_parameters)
{
    if( I->state != TaskState::Shell )
        return;

    const std::string cmd = EscapeShellFeed(_short_fn);

    // process cwd stuff if any
    char cwd[MAXPATHLEN];
    cwd[0] = 0;
    if( _at != nullptr ) {
        strcpy(cwd, _at);
        if( utility::PathManip::HasTrailingSlash(cwd) && strlen(cwd) > 1 ) // cd command don't like trailing slashes
            cwd[strlen(cwd) - 1] = 0;

        if( IsCurrentWD(cwd) ) {
            cwd[0] = 0;
        }
        else {
            if( !IsDirectoryAvailableForBrowsing(cwd) ) // file I/O here
                return;
        }
    }

    std::string input;
    if( cwd[0] != 0 )
        input = fmt::format("cd '{}'; ./{}{}{}\n",
                            cwd,
                            cmd,
                            _parameters != nullptr ? " " : "",
                            _parameters != nullptr ? _parameters : "");
    else
        input = fmt::format(
            "./{}{}{}\n", cmd, _parameters != nullptr ? " " : "", _parameters != nullptr ? _parameters : "");

    I->SetState(TaskState::ProgramExternal);
    WriteChildInput(input);
}

void ShellTask::ExecuteWithFullPath(const char *_path, const char *_parameters)
{
    if( I->state != TaskState::Shell )
        return;

    const std::string cmd = EscapeShellFeed(_path);
    const std::string input =
        fmt::format("{}{}{}\n", cmd, _parameters != nullptr ? " " : "", _parameters != nullptr ? _parameters : "");

    I->SetState(TaskState::ProgramExternal);
    WriteChildInput(input);
}

void ShellTask::ExecuteWithFullPath(const std::filesystem::path &_binary_path, std::span<const std::string> _arguments)
{
    if( I->state != TaskState::Shell )
        return;

    std::string cmd = EscapeShellFeed(_binary_path);
    for( auto &arg : _arguments ) {
        cmd += ' ';
        cmd += EscapeShellFeed(arg);
    }
    cmd += "\n";

    I->SetState(TaskState::ProgramExternal);
    WriteChildInput(cmd);
}

std::vector<std::string> ShellTask::ChildrenList() const
{
    if( I->state == TaskState::Inactive || I->state == TaskState::Dead || I->shell_pid < 0 )
        return {};

    size_t proc_cnt = 0;
    kinfo_proc *proc_list;
    if( nc::utility::GetBSDProcessList(&proc_list, &proc_cnt) != 0 )
        return {};

    std::array<char, 16384> mem_buffer;
    std::pmr::monotonic_buffer_resource mem_resource(mem_buffer.data(), mem_buffer.size());

    // copy kinfo_proc into a more usage datastructure
    struct Proc {
        pid_t pid;
        pid_t ppid;
        const char *name;
    };
    std::pmr::vector<Proc> procs(&mem_resource);
    for( size_t i = 0; i < proc_cnt; ++i ) {
        procs.emplace_back(Proc{.pid = proc_list[i].kp_proc.p_pid,
                                .ppid = proc_list[i].kp_eproc.e_ppid,
                                .name = proc_list[i].kp_proc.p_comm});
    }

    struct PPidLess {
        bool operator()(const Proc &lhs, const Proc &rhs) const noexcept { return lhs.ppid < rhs.ppid; }
        bool operator()(const Proc &lhs, pid_t rhs) const noexcept { return lhs.ppid < rhs; }
        bool operator()(pid_t lhs, const Proc &rhs) const noexcept { return lhs < rhs.ppid; }
    };

    // sort by parent pid O(nlogn)
    std::ranges::sort(procs, PPidLess{});

    // names of the sub-processes, sorted by depth
    std::vector<std::string> result;

    // for each parent pid in the queue:
    std::queue<pid_t, std::pmr::deque<pid_t>> parent_pids{std::pmr::deque<pid_t>(&mem_resource)};
    parent_pids.push(I->shell_pid);
    while( !parent_pids.empty() ) {
        const pid_t ppid = parent_pids.front();
        parent_pids.pop();

        // find all processes with this specific ppid, O(logn), get their names and add their pids at the tail of the
        // queue
        const auto range = std::equal_range(procs.begin(), procs.end(), ppid, PPidLess{}); // NOLINT
        for( auto it = range.first; it != range.second; ++it ) {
            const pid_t pid = it->pid;
            char path_buffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
            const int rc = proc_pidpath(pid, path_buffer, sizeof(path_buffer));
            if( rc >= 0 ) {
                // a proper 'long' version based on a filepath
                const auto name = nc::utility::PathManip::Filename(path_buffer);
                result.emplace_back(name);
            }
            else {
                // 'short' backup version
                result.emplace_back(it->name);
            }
            parent_pids.push(pid);
        }
    }

    free(proc_list);
    return result;
}

int ShellTask::ShellPID() const
{
    return I->shell_pid;
}

int ShellTask::ShellChildPID() const
{
    if( I->state == TaskState::Inactive || I->state == TaskState::Dead || I->state == TaskState::Shell ||
        I->shell_pid < 0 )
        return -1;

    size_t proc_cnt = 0;
    kinfo_proc *proc_list;
    if( nc::utility::GetBSDProcessList(&proc_list, &proc_cnt) != 0 )
        return -1;

    int child_pid = -1;

    for( size_t i = 0; i < proc_cnt; ++i ) {
        const int pid = proc_list[i].kp_proc.p_pid;
        const int ppid = proc_list[i].kp_eproc.e_ppid;
        if( ppid == I->shell_pid ) {
            child_pid = pid;
            break;
        }
    }

    free(proc_list);
    return child_pid;
}

std::string ShellTask::CWD() const
{
    const std::lock_guard<std::mutex> lock(I->lock);
    return I->cwd;
}

void ShellTask::ResizeWindow(int _sx, int _sy)
{
    if( I->term_sx == _sx && I->term_sy == _sy )
        return;

    I->term_sx = _sx;
    I->term_sy = _sy;

    if( I->state != TaskState::Inactive && I->state != TaskState::Dead )
        Task::SetTermWindow(I->master_fd, static_cast<unsigned short>(_sx), static_cast<unsigned short>(_sy));
}

void ShellTask::Terminate()
{
    I->CleanUp();
}

void ShellTask::SetOnPwdPrompt(OnPwdPrompt _callback)
{
    auto callback = to_shared_ptr(std::move(_callback));
    I->callback_lock.lock();
    I->on_pwd_prompt = std::move(callback);
    I->callback_lock.unlock();
}

void ShellTask::SetOnStateChange(OnStateChange _callback)
{
    auto callback = to_shared_ptr(std::move(_callback));
    I->callback_lock.lock();
    I->on_state_changed = std::move(callback);
    I->callback_lock.unlock();
}

ShellTask::TaskState ShellTask::State() const
{
    return I->state;
}

void ShellTask::SetShellPath(const std::string &_path)
{
    // that's the raw shell path
    I->shell_path = _path;

    // for now we decude a shell type from the raw input
    I->shell_type = DetectShellType(_path);

    // try to resolve it in case it's a symlink. Sync I/O here!
    if( auto symlink = TryToResolve(I->shell_path) ) {
        I->shell_resolved_path = std::move(*symlink);
    }
    else {
        I->shell_resolved_path = I->shell_path;
    }
}

void ShellTask::SetEnvVar(const std::string &_var, const std::string &_value)
{
    I->custom_env_vars.emplace_back(_var, _value);
}

void ShellTask::AddCustomShellArgument(std::string_view argument)
{
    if( argument.empty() )
        return;
    I->custom_shell_args.emplace_back(argument);
}

char **ShellTask::BuildShellArgs() const
{
    if( I->shell_type == ShellType::Unknown )
        return nullptr;

    const auto &custom_args = I->custom_shell_args;

    if( !custom_args.empty() ) {
        // Feed the custom arguments
        char **args = new char *[custom_args.size() + 1];
        for( size_t i = 0; i != custom_args.size(); ++i )
            args[i] = strdup(custom_args[i].c_str());
        args[custom_args.size()] = nullptr;
        return args;
    }
    else {
        // Feed the built-in ones
        return g_ShellParams[static_cast<int>(I->shell_type)];
    }
}

ShellTask::ShellType ShellTask::GetShellType() const
{
    return I->shell_type;
}

std::string ShellTask::ComposePromptCommand() const
{
    // setup pwd feedback
    // this braindead construct creates a two-way communication channel between a shell and NC:
    // 1) the shell is about to print a command prompt
    // 2) PROMPT_COMMAND/precmd is executed by the shell
    // 2.a) current directory is told to NC through the pwd pipe
    // 2.b) shell is blocked until NC responds via the semaphore pipe
    // 2.c) NC processes the pwd notification (hopefully) and writes into the semaphore pipe
    // 2.d) data from that semaphore is read and the shell is unblocked
    // 3) the shell resumes
    const int pid = I->shell_pid;
    if( I->shell_type == ShellType::Bash )
        return fmt::format(" PROMPT_COMMAND='if [ $$ -eq {} ]; then pwd>&20; read sema <&21; fi'\n", pid);
    else if( I->shell_type == ShellType::ZSH )
        return fmt::format(" precmd(){{ if [ $$ -eq {} ]; then pwd>&20; read sema <&21; fi; }}\n", pid);
    else if( I->shell_type == ShellType::TCSH )
        return fmt::format(" alias precmd 'if ( $$ == {} ) pwd>>{};dd if={} of=/dev/null bs=4 count=1 >&/dev/null'\n",
                           pid,
                           I->tcsh_cwd_path,
                           I->tcsh_semaphore_path);
    else
        return {};
}

} // namespace nc::term
