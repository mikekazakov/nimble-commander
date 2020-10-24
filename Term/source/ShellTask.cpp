// Copyright (C) 2013-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/select.h>
#include <sys/ioctl.h>
#include <sys/sysctl.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <string.h>
#include <libproc.h>
#include <dirent.h>
#include <signal.h>
#include <Utility/SystemInformation.h>
#include <Utility/PathManip.h>
#include <Habanero/algo.h>
#include <Habanero/mach_time.h>
#include <Habanero/CommonPaths.h>
#include <Habanero/dispatch_cpp.h>
#include <Habanero/CloseFrom.h>
#include <Habanero/spinlock.h>
#include <iostream>
#include <signal.h>
#include "ShellTask.h"

namespace nc::term {

static const int g_PromptPipe = 20;
static const int g_SemaphorePipe = 21;
static int g_TCSHPipeGeneration = 0;

static char *g_BashParams[3] = {(char *)"bash", (char *)"--login", 0};
static char *g_ZSHParams[3] = {(char *)"-Z", (char *)"-g", 0};
static char *g_TCSH[2] = {(char *)"tcsh", 0};
static char **g_ShellParams[3] = {g_BashParams, g_ZSHParams, g_TCSH};

static bool IsDirectoryAvailableForBrowsing(const char *_path);
static bool IsDirectoryAvailableForBrowsing(const std::string &_path);
static std::string GetDefaultShell();
static std::string ProcPidPath(int _pid);
static bool WaitUntilBecomes(int _pid,
                             std::string_view _expected_image_path,
                             std::chrono::nanoseconds _timeout,
                             std::chrono::nanoseconds _pull_period);
static ShellTask::ShellType DetectShellType(const std::string &_path);
static bool fd_is_valid(int fd);
static void KillAndReap(int _pid,
                        std::chrono::nanoseconds _gentle_deadline,
                        std::chrono::nanoseconds _brutal_deadline);
static void TurnOffSigPipe();

static bool IsDirectoryAvailableForBrowsing(const char *_path)
{
    DIR *dirp = opendir(_path);
    if( dirp == nullptr )
        return false;
    closedir(dirp);
    return true;
}

static bool IsDirectoryAvailableForBrowsing(const std::string &_path)
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

static std::string ProcPidPath(int _pid)
{
    char buf[PROC_PIDPATHINFO_MAXSIZE] = {0};
    if( proc_pidpath(_pid, buf, PROC_PIDPATHINFO_MAXSIZE) <= 0 )
        return {};
    else
        return buf;
}

static bool WaitUntilBecomes(int _pid,
                             std::string_view _expected_image_path,
                             std::chrono::nanoseconds _timeout,
                             std::chrono::nanoseconds _pull_period)
{
    const auto deadline = machtime() + _timeout;
    while( true ) {
        const auto current_path = ProcPidPath(_pid);
        if( current_path.empty() )
            return false;
        if( current_path == _expected_image_path )
            return true;
        if( machtime() >= deadline )
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

static void KillAndReap(int _pid,
                        std::chrono::nanoseconds _gentle_deadline,
                        std::chrono::nanoseconds _brutal_deadline)
{
    constexpr auto poll_wait = std::chrono::milliseconds(1);
    // 1st attempt - do with a gentle SIGTERM
    kill(_pid, SIGTERM);
    int status = 0;
    int waitpid_rc = 0;
    const auto gentle_deadline = machtime() + _gentle_deadline;
    while( true ) {
        waitpid_rc = waitpid(_pid, &status, WNOHANG | WUNTRACED);

        if( waitpid_rc != 0 )
            break;

        if( machtime() >= gentle_deadline )
            break;

        std::this_thread::sleep_for(poll_wait);
    }

    if( waitpid_rc > 0 ) {
        // 2nd attemp - bruteforce
        kill(_pid, SIGKILL);
        const auto brutal_deadline = machtime() + _brutal_deadline;
        while( true ) {
            waitpid_rc = waitpid(_pid, &status, WNOHANG | WUNTRACED);
            if( waitpid_rc != 0 )
                break;

            if( machtime() >= brutal_deadline ) {
                // at this point we give up and let the child linger in limbo/zombie state.
                // I have no idea what to do with the marvelous MacOS thing called
                // "E - The process is trying to exit". Subprocesses can fall into this state
                // with some low propability, deadlocking a blocking waitpid() forever.
                std::cerr << "Letting go a child at PID " << _pid << std::endl;
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }
}

struct ShellTask::Impl {
    // accessible from any thread:
    std::mutex lock;
    TaskState state = TaskState::Inactive;
    int master_fd = -1;
    std::atomic_int shell_pid{-1};
    int cwd_pipe[2] = {-1, -1};
    int semaphore_pipe[2] = {-1, -1};
    int signal_pipe[2] = {-1, -1};
    std::string tcsh_cwd_path;
    std::string tcsh_semaphore_path;
    // will give no output until the next bash prompt will show the requested_cwd path
    bool temporary_suppressed = false;
    std::thread input_thread;
    std::string requested_cwd = "";
    std::string cwd = "";

    // accessible from main thread only (presumably)
    int term_sx = 80;
    int term_sy = 25;
    std::string shell_path = "";
    ShellType shell_type = ShellType::Unknown;
    std::vector<std::pair<std::string, std::string>> custom_env_vars;
    std::vector<std::string> custom_shell_args;

    std::atomic_bool is_shutting_down{false};
    spinlock master_write_lock;

    spinlock callback_lock;
    std::shared_ptr<std::function<void(const char *_cwd, bool _changed)>> on_pwd_prompt;
    std::shared_ptr<OnStateChange> on_state_changed;
};

ShellTask::ShellTask() : I(std::make_shared<Impl>())
{
    SetShellPath(GetDefaultShell());
    TurnOffSigPipe();
}

ShellTask::~ShellTask()
{
    I->is_shutting_down = true;
    CleanUp();
}

bool ShellTask::Launch(const std::filesystem::path &_work_dir)
{
    using namespace std::literals;

    if( I->input_thread.joinable() )
        throw std::logic_error("ShellTask::Launch called with joinable input thread");

    if( I->shell_type == ShellType::Unknown )
        return false;

    I->cwd = _work_dir.generic_string();
    
    // remember current locale and stuff
    auto env = BuildEnv();

    I->master_fd = posix_openpt(O_RDWR);
    assert(I->master_fd >= 0);

    grantpt(I->master_fd);
    unlockpt(I->master_fd);

    int slave_fd = open(ptsname(I->master_fd), O_RDWR);

    int rc = 0;
    // init FIFO stuff for Shell's CWD
    if( I->shell_type == ShellType::Bash || I->shell_type == ShellType::ZSH ) {
        // for Bash or ZSH use regular pipe handle
        rc = pipe(I->cwd_pipe);
        assert(rc == 0);
        rc = pipe(I->semaphore_pipe);
        assert(rc == 0);
    } else if( I->shell_type == ShellType::TCSH ) {
        // for TCSH use named fifo file. supporting [t]csh was a mistake :(
        const auto &dir = base::CommonPaths::AppTemporaryDirectory();
        const auto mypid = std::to_string(getpid());
        const auto gen = std::to_string(g_TCSHPipeGeneration);
        I->tcsh_cwd_path = dir + "nimble_commander.tcsh.cwd_pipe." + mypid + "." + gen;

        rc = mkfifo(I->tcsh_cwd_path.c_str(), 0600);
        assert(rc == 0);

        rc = I->cwd_pipe[0] = open(I->tcsh_cwd_path.c_str(), O_RDWR);
        assert(rc != -1);

        I->tcsh_semaphore_path = dir + "nimble_commander.tcsh.semaphore_pipe." + mypid + "." + gen;

        rc = mkfifo(I->tcsh_semaphore_path.c_str(), 0600);
        assert(rc == 0);

        rc = I->semaphore_pipe[1] = open(I->tcsh_semaphore_path.c_str(), O_RDWR);
        assert(rc != -1);

        ++g_TCSHPipeGeneration;
    }
    
    // create a pipe to communicate with the blocking select()
    rc = pipe(I->signal_pipe);
    assert(rc == 0);
    
    // Create the child process
    const auto fork_rc = fork();
    if( fork_rc < 0 ) {
        // error
        std::cerr << "fork() failed with " << errno << "!" << std::endl;
        return false;
    } else if( fork_rc > 0 ) {
        // master
        I->shell_pid = fork_rc;
        close(slave_fd);
        close(I->cwd_pipe[1]);
        close(I->semaphore_pipe[0]);
        I->temporary_suppressed = true; /// HACKY!!!

        // wait until either the forked process becomes an expected shell or dies
        const bool became_shell = WaitUntilBecomes(I->shell_pid, I->shell_path, 1s, 1ms);
        if( !became_shell ) {
            CleanUp(); // Well, RIP
            return false;
        }

        SetState(TaskState::Shell);

        I->input_thread = std::thread([=] {
            auto name = "ShellTask background input thread, PID="s + std::to_string(I->shell_pid);
            pthread_setname_np(name.c_str());
            ReadChildOutput();
        });

        // setup pwd feedback
        // this braindead construct creates a two-way communication channel between a shell and NC:
        // 1) the shell is about to print a command prompt
        // 2) PROMPT_COMMAND/precmd is executed by the shell
        // 2.a) current directory is told to NC through the pwd pipe
        // 2.b) shell is blocked until NC responds via the semaphore pipe
        // 2.c) NC processes the pwd notification (hopefully) and writes into the semaphore pipe
        // 2.d) data from that semaphore is read and the shell is unblocked
        // 3) the shell resumes
        char prompt_setup[1024] = {0};
        if( I->shell_type == ShellType::Bash )
            sprintf(prompt_setup,
                    " PROMPT_COMMAND='if [ $$ -eq %d ]; then pwd>&20; read sema <&21; fi'\n",
                    fork_rc);
        else if( I->shell_type == ShellType::ZSH )
            sprintf(prompt_setup,
                    " precmd(){ if [ $$ -eq %d ]; then pwd>&20; read sema <&21; fi; }\n",
                    fork_rc);
        else if( I->shell_type == ShellType::TCSH )
            sprintf(
                prompt_setup,
                " alias precmd 'if ( $$ == %d ) pwd>>%s;dd if=%s of=/dev/null bs=4 count=1 >&/dev/null'\n",
                fork_rc,
                I->tcsh_cwd_path.c_str(),
                I->tcsh_semaphore_path.c_str());
        
        if( !fd_is_valid(I->master_fd) )
            std::cerr << "m_MasterFD is dead!" << std::endl;

        LOCK_GUARD(I->master_write_lock)
        {
            ssize_t write_res = write(I->master_fd, prompt_setup, strlen(prompt_setup));
            if( write_res == -1 ) {
                std::cout << "write() error: " << errno << ", verbose: " << strerror(errno)
                          << std::endl;
            }
        }

        return true;
    } else { // fork_rc == 0
        // slave/child
        SetupTermios(slave_fd);
        SetTermWindow(slave_fd, I->term_sx, I->term_sy);
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
            rc = dup2(I->cwd_pipe[1], g_PromptPipe);
            assert(rc == g_PromptPipe);
            rc = dup2(I->semaphore_pipe[0], g_SemaphorePipe);
            assert(rc == g_SemaphorePipe);
        }

        // say BASH to not put into history any command starting with space character
        putenv((char *)"HISTCONTROL=ignorespace");

        // close all file descriptors except [0], [1], [2] and [g_PromptPipe][g_SemaphorePipe]
        nc::base::CloseFromExcept(3, std::array<int, 2>{g_PromptPipe, g_SemaphorePipe});

        // execution of the program
        execv(I->shell_path.c_str(), BuildShellArgs());

        // we never get here in normal condition
        exit(-1);
    }
}

void ShellTask::ReadChildOutput()
{
    constexpr int input_sz = 65536;
    char input[65536];
    fd_set fd_in, fd_err;
    
    while( true ) {
        // Wait for either a data from master, cwd or signal, or an error from master.        
        FD_ZERO(&fd_in);
        FD_SET(I->master_fd, &fd_in);
        FD_SET(I->cwd_pipe[0], &fd_in);
        FD_SET(I->signal_pipe[0], &fd_in);
        FD_ZERO(&fd_err);
        FD_SET(I->master_fd, &fd_err);
        const int max_fd = std::max({I->master_fd, I->cwd_pipe[0], I->signal_pipe[0]});
        const int select_rc = select(max_fd + 1, &fd_in, NULL, &fd_err, NULL);
        if( I->shell_pid < 0 ) {
            // The shell was closed from the master thread, don't do aything.
            // Most likely it's due to FD_ISSET(I->signal_pipe[0], &fd_in), but we can't(?) reliably
            // check for that due to a possible race condition between "I->shell_pid = -1;" and
            // "write(I->signal_pipe[1], ...)".
            break;
        }

        if( select_rc < 0 ) {
            //            std::cerr << "select(max_fd + 1, &fd_in, NULL, &fd_err, NULL) returned "
            //                << rc << std::endl;
            // error on select(), let's think that shell has died
            // mb call ShellDied() here?
            break;
        }

        // If data on master side of PTY (some child's output)
        // Need to consume it first as it can be suppressed and we want to eat it before opening a
        // shell's semaphore.
        if( FD_ISSET(I->master_fd, &fd_in) ) {
            // try to read a bit more - wait 1usec to see if any additional data will come in
            unsigned have_read = ReadInputAsMuchAsAvailable(I->master_fd, input, input_sz);
            if( !I->temporary_suppressed )
                DoCalloutOnChildOutput(input, have_read);
        }

        // check prompt's output
        if( FD_ISSET(I->cwd_pipe[0], &fd_in) ) {
            const int read_rc = (int)read(I->cwd_pipe[0], input, input_sz);
            if( read_rc > 0 )
                ProcessPwdPrompt(input, read_rc);
        }

        // check if child process died
        if( FD_ISSET(I->master_fd, &fd_err) ) {
            //            std::cout << "shell died: FD_ISSET(I->master_fd, &fd_err)" << std::endl;
            if( !I->is_shutting_down )
                //                dispatch_to_main_queue([=]{
                ShellDied();
            //                });
            break;
        }
    } // End while
    //    std::cerr << "done with ReadChildOutput()" << std::endl;
}

void ShellTask::ProcessPwdPrompt(const void *_d, int _sz)
{
    dispatch_assert_background_queue();
    std::string current_cwd = I->cwd;
    bool do_nr_hack = false;
    bool current_wd_changed = false;

    LOCK_GUARD(I->lock)
    {
        char tmp[1024];
        memcpy(tmp, _d, _sz);
        tmp[_sz] = 0;

        while( strlen(tmp) > 0 &&
               ( // need MOAR slow strlens in this while! gimme MOAR!!!!!
                   tmp[strlen(tmp) - 1] == '\n' || tmp[strlen(tmp) - 1] == '\r') )
            tmp[strlen(tmp) - 1] = 0;

        I->cwd = tmp;
        if( I->cwd.empty() || I->cwd.back() != '/' )
            I->cwd += '/';

        if( current_cwd != I->cwd ) {
            current_cwd = I->cwd;
            current_wd_changed = true;
        }

        if( I->state == TaskState::ProgramExternal || I->state == TaskState::ProgramInternal ) {
            // shell just finished running something - let's back it to StateShell state
            SetState(TaskState::Shell);
        }

        if( I->temporary_suppressed && (I->requested_cwd.empty() || I->requested_cwd == tmp) ) {

            I->temporary_suppressed = false;
            if( !I->requested_cwd.empty() ) {
                I->requested_cwd = "";
                do_nr_hack = true;
            }
        }
    }

    if( I->requested_cwd.empty() )
        DoOnPwdPromptCallout(current_cwd.c_str(), current_wd_changed);
    if( do_nr_hack )
        DoCalloutOnChildOutput("\n\r", 2);

    write(I->semaphore_pipe[1], "OK\n\r", 4);
}

void ShellTask::DoOnPwdPromptCallout(const char *_cwd, bool _changed) const
{
    I->callback_lock.lock();
    auto on_pwd = I->on_pwd_prompt;
    I->callback_lock.unlock();

    if( on_pwd && *on_pwd )
        (*on_pwd)(_cwd, _changed);
}

void ShellTask::WriteChildInput(std::string_view _data)
{
    if( I->state == TaskState::Inactive || I->state == TaskState::Dead )
        return;
    if( _data.empty() )
        return;

    LOCK_GUARD(I->master_write_lock)
    {
        ssize_t rc = write(I->master_fd, _data.data(), _data.size());
        if( rc < 0 || rc != (ssize_t)_data.size() )
            std::cerr << "write( m_MasterFD, _data.data(), _data.size() ) returned " << rc
                      << std::endl;
    }

    if( (_data.back() == '\n' || _data.back() == '\r') && I->state == TaskState::Shell ) {
        LOCK_GUARD(I->lock)
        SetState(TaskState::ProgramInternal);
    }
}

void ShellTask::CleanUp()
{
    std::lock_guard lock{I->lock};

    if( I->shell_pid > 0 ) {
        const int pid = I->shell_pid;
        I->shell_pid = -1;
        std::thread([pid]{
            KillAndReap(pid, std::chrono::milliseconds(400), std::chrono::milliseconds(1000));
        }).detach();
    }
    
    if( I->input_thread.joinable() ) {
        if( I->input_thread.get_id() == std::this_thread::get_id() ) {
            I->input_thread.detach();
        } else {
            char c = 0;
            write(I->signal_pipe[1], &c, 1);
            I->input_thread.join();
        }
    }
    
    if( I->signal_pipe[0] >= 0 ) {
        close(I->signal_pipe[0]);
        close(I->signal_pipe[1]);
        I->signal_pipe[0] = I->signal_pipe[1] = -1;
    }

    if( I->master_fd >= 0 ) {
        close(I->master_fd);
        I->master_fd = -1;
    }

    if( I->cwd_pipe[0] >= 0 ) {
        close(I->cwd_pipe[0]);
        I->cwd_pipe[0] = I->cwd_pipe[1] = -1;
    }

    if( I->semaphore_pipe[1] >= 0 ) {
        close(I->semaphore_pipe[1]);
        I->semaphore_pipe[0] = I->semaphore_pipe[1] = -1;
    }

    if( !I->tcsh_cwd_path.empty() ) {
        unlink(I->tcsh_cwd_path.c_str());
        I->tcsh_cwd_path.clear();
    }
    
    if( !I->tcsh_semaphore_path.empty()) {
        unlink(I->tcsh_semaphore_path.c_str());
        I->tcsh_semaphore_path.clear();
    }

    I->temporary_suppressed = false;
    I->requested_cwd = "";
    I->cwd = "";

    SetState(TaskState::Inactive);
}

void ShellTask::ShellDied()
{
    dispatch_assert_background_queue();

    // no need to call it if PID is already set to invalid - we're in closing state
    if( I->shell_pid <= 0 )
        return; // wtf this even is??

    SetState(TaskState::Dead);

    CleanUp();
}

void ShellTask::SetState(TaskState _new_state)
{
    if( I->state == _new_state )
        return;

    I->state = _new_state;

    I->callback_lock.lock();
    auto callback = I->on_state_changed;
    I->callback_lock.unlock();

    if( callback && *callback )
        (*callback)(I->state);
}

void ShellTask::ChDir(const std::filesystem::path &_new_cwd)
{
    if( I->state != TaskState::Shell )
        return;

    auto requested_cwd = EnsureTrailingSlash(_new_cwd.generic_string());
    LOCK_GUARD(I->lock)
    if( I->cwd == requested_cwd )
        return; // do nothing if current working directory is the same as requested

    requested_cwd = EnsureNoTrailingSlash(requested_cwd); // cd command don't like trailing slashes

    // file I/O here
    if( !IsDirectoryAvailableForBrowsing(requested_cwd) )
        return;

    LOCK_GUARD(I->lock)
    {
        I->temporary_suppressed = true; // will show no output of shell when changing a directory
        I->requested_cwd = requested_cwd;
    }

    std::string child_feed;
    child_feed +=
        "\x03"; // pass ctrl+C to shell to ensure that no previous user input (if any) will stay

//    child_feed += " cd '";
//    child_feed += requested_cwd;
//    child_feed += "'\n";

    child_feed += " cd ";
    child_feed += EscapeShellFeed(requested_cwd);
    child_feed += "\n";
    
//    child_feed += EscapeShellFeed(requested_cwd);
    
    WriteChildInput(child_feed);
}

bool ShellTask::IsCurrentWD(const char *_what) const
{
    char cwd[MAXPATHLEN];
    strcpy(cwd, _what);

    if( !IsPathWithTrailingSlash(cwd) )
        strcat(cwd, "/");

    return I->cwd == cwd;
}

void ShellTask::Execute(const char *_short_fn, const char *_at, const char *_parameters)
{
    if( I->state != TaskState::Shell )
        return;

    std::string cmd = EscapeShellFeed(_short_fn);

    // process cwd stuff if any
    char cwd[MAXPATHLEN];
    cwd[0] = 0;
    if( _at != 0 ) {
        strcpy(cwd, _at);
        if( IsPathWithTrailingSlash(cwd) &&
            strlen(cwd) > 1 ) // cd command don't like trailing slashes
            cwd[strlen(cwd) - 1] = 0;

        if( IsCurrentWD(cwd) ) {
            cwd[0] = 0;
        } else {
            if( !IsDirectoryAvailableForBrowsing(cwd) ) // file I/O here
                return;
        }
    }

    char input[2048];
    if( cwd[0] != 0 )
        sprintf(input, "cd '%s'; ./%s%s%s\n", cwd, cmd.c_str(), _parameters != nullptr ? " " : "",
                _parameters != nullptr ? _parameters : "");
    else
        sprintf(input, "./%s%s%s\n", cmd.c_str(), _parameters != nullptr ? " " : "",
                _parameters != nullptr ? _parameters : "");

    SetState(TaskState::ProgramExternal);
    WriteChildInput(input);
}

void ShellTask::ExecuteWithFullPath(const char *_path, const char *_parameters)
{
    if( I->state != TaskState::Shell )
        return;

    std::string cmd = EscapeShellFeed(_path);

    char input[2048];
    sprintf(input, "%s%s%s\n", cmd.c_str(), _parameters != nullptr ? " " : "",
            _parameters != nullptr ? _parameters : "");

    SetState(TaskState::ProgramExternal);
    WriteChildInput(input);
}

std::vector<std::string> ShellTask::ChildrenList() const
{
    if( I->state == TaskState::Inactive || I->state == TaskState::Dead || I->shell_pid < 0 )
        return {};

    size_t proc_cnt = 0;
    kinfo_proc *proc_list;
    if( nc::utility::GetBSDProcessList(&proc_list, &proc_cnt) != 0 )
        return {};

    std::vector<std::string> result;
    for( size_t i = 0; i < proc_cnt; ++i ) {
        int pid = proc_list[i].kp_proc.p_pid;
        int ppid = proc_list[i].kp_eproc.e_ppid;

    again:
        if( ppid == I->shell_pid ) {
            char name[1024];
            int ret = proc_name(pid, name, sizeof(name));
            result.emplace_back(ret > 0 ? name : proc_list[i].kp_proc.p_comm);
        } else if( ppid >= 1024 )
            for( size_t j = 0; j < proc_cnt; ++j )
                if( proc_list[j].kp_proc.p_pid == ppid ) {
                    ppid = proc_list[j].kp_eproc.e_ppid;
                    goto again;
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
    if( I->state == TaskState::Inactive || I->state == TaskState::Dead ||
        I->state == TaskState::Shell || I->shell_pid < 0 )
        return -1;

    size_t proc_cnt = 0;
    kinfo_proc *proc_list;
    if( nc::utility::GetBSDProcessList(&proc_list, &proc_cnt) != 0 )
        return -1;

    int child_pid = -1;

    for( size_t i = 0; i < proc_cnt; ++i ) {
        int pid = proc_list[i].kp_proc.p_pid;
        int ppid = proc_list[i].kp_eproc.e_ppid;
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
    std::lock_guard<std::mutex> lock(I->lock);
    return I->cwd;
}

void ShellTask::ResizeWindow(int _sx, int _sy)
{
    if( I->term_sx == _sx && I->term_sy == _sy )
        return;

    I->term_sx = _sx;
    I->term_sy = _sy;

    if( I->state != TaskState::Inactive && I->state != TaskState::Dead )
        Task::SetTermWindow(I->master_fd, _sx, _sy);
}

void ShellTask::Terminate()
{
    CleanUp();
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
    I->on_state_changed = move(callback);
    I->callback_lock.unlock();
}

ShellTask::TaskState ShellTask::State() const
{
    return I->state;
}

void ShellTask::SetShellPath(const std::string &_path)
{
    I->shell_path = _path;
    I->shell_type = DetectShellType(_path);
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
    } else {
        // Feed the built-in ones
        return g_ShellParams[static_cast<int>(I->shell_type)];
    }
}

ShellTask::ShellType ShellTask::GetShellType() const
{
    return I->shell_type;
}

} // namespace nc::term
