// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
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
#include <Utility/SystemInformation.h>
#include <Utility/PathManip.h>
#include <Habanero/algo.h>
#include <Habanero/CommonPaths.h>
#include <Habanero/dispatch_cpp.h>
#include <iostream>
#include <signal.h>
#include "ShellTask.h"

namespace nc::term {

static const int    g_PromptPipe    = 20;

static char *g_BashParams[2]    = {(char*)"-L", 0};
static char *g_ZSHParams[3]     = {(char*)"-Z", (char*)"-g", 0};
static char *g_TCSH[2]          = {(char*)"tcsh", 0};
static char **g_ShellParams[3]  = { g_BashParams, g_ZSHParams, g_TCSH };

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

static int MaxFD()
{
    static const int max_fd = (int)sysconf(_SC_OPEN_MAX);
    return max_fd;
}

static std::string GetDefaultShell()
{
    if( const char *shell = getenv("SHELL") )
        return shell;
    else // setup is very weird
        return "/bin/bash";
}

static ShellTask::ShellType DetectShellType( const std::string &_path )
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

ShellTask::ShellTask():
    m_ShellPath( GetDefaultShell() )
{
}

ShellTask::~ShellTask()
{
    m_IsShuttingDown = true;
    CleanUp();
}

static bool fd_is_valid(int fd)
{
    return fcntl(fd, F_GETFD) != -1 || errno != EBADF;
}

bool ShellTask::Launch(const char *_work_dir)
{
    using namespace std::literals;
    
    if( m_InputThread.joinable() )
        throw std::logic_error("ShellTask::Launch called with joinable input thread");

    m_ShellType = DetectShellType(m_ShellPath);
    if( m_ShellType == ShellType::Unknown )
        return false;
    
    // remember current locale and stuff
    auto env = BuildEnv();
    
    m_MasterFD = posix_openpt(O_RDWR);
    assert(m_MasterFD >= 0);
    
    grantpt(m_MasterFD);
    unlockpt(m_MasterFD);
    
    int slave_fd = open(ptsname(m_MasterFD), O_RDWR);
    
    int rc = 0;
    // init FIFO stuff for Shell's CWD
    if( m_ShellType == ShellType::Bash ||
        m_ShellType == ShellType::ZSH ) {
        // for Bash or ZSH use regular pipe handle
        rc = pipe( m_CwdPipe );
        assert(rc == 0);
    }
    else if( m_ShellType == ShellType::TCSH ) {
        // for TCSH use named fifo file
        m_TCSH_FifoPath =
            CommonPaths::AppTemporaryDirectory() +
            "nimble_commander.tcsh.pipe." + 
            std::to_string(getpid());
        
        rc = mkfifo(m_TCSH_FifoPath.c_str(), 0600);
        assert( rc == 0 );
        
        rc = m_CwdPipe[0] = open(m_TCSH_FifoPath.c_str(), O_RDWR);
        assert( rc != -1 );
    }
    
    // Create the child process
    if( (rc = fork()) != 0 ) {
        if( rc < 0 )
            std::cerr << "fork() returned " << rc << "!" << std::endl;
        
        // master
        m_ShellPID = rc;
        close(slave_fd);
        close(m_CwdPipe[1]);
        m_TemporarySuppressed = true;
        
        SetState(TaskState::Shell);
        
        m_InputThread = std::thread([=]{
            auto name = "ShellTask background input thread, PID="s + std::to_string(m_ShellPID);
            pthread_setname_np( name.c_str() );
            ReadChildOutput();
        });
        
        // give shell some time to init and background thead to read any ouput available
        std::this_thread::sleep_for(50ms);
        
        // setup pwd feedback
        char prompt_setup[1024] = {0};
        if( m_ShellType == ShellType::Bash )
            sprintf(prompt_setup, " PROMPT_COMMAND='if [ $$ -eq %d ]; then pwd>&20; fi'\n", rc);
        else if( m_ShellType == ShellType::ZSH )
            sprintf(prompt_setup, " precmd(){ if [ $$ -eq %d ]; then pwd>&20; fi; }\n", rc);
        else if( m_ShellType == ShellType::TCSH )
            sprintf(prompt_setup, " alias precmd 'if ( $$ == %d ) pwd>>%s;sleep 0.05'\n", rc, m_TCSH_FifoPath.c_str());
        
        if( !fd_is_valid(m_MasterFD) )
            std::cerr << "m_MasterFD is dead!" << std::endl;
        
        LOCK_GUARD(m_MasterWriteLock) {
            ssize_t write_res = write( m_MasterFD, prompt_setup, strlen(prompt_setup) );
            if( write_res == -1 ) {
                std::cout << "write() error: " << errno
                    << ", verbose: " << strerror(errno) << std::endl;
            }
        }
        
        // give the shell some time to parse the setup input
        std::this_thread::sleep_for(50ms);
    }
    else {
        // slave/child
        SetupTermios(slave_fd);
        SetTermWindow(slave_fd, m_TermSX, m_TermSY);
        SetupHandlesAndSID(slave_fd);
        
        chdir(_work_dir);
        
        // put basic environment stuff
        SetEnv(env);
        
        if( m_ShellType != ShellType::TCSH ) {
            // setup piping for CWD prompt
            // using FD g_PromptPipe becuse bash is closing fds [3,20) upon opening in logon mode (our case)
            rc = dup2(m_CwdPipe[1], g_PromptPipe);
            assert(rc == g_PromptPipe);
        }
        
        // say BASH to not put into history any command starting with space character
        putenv((char *)"HISTCONTROL=ignorespace");
        
        // close all file descriptors except [0], [1], [2] and [g_PromptPipe]
        // implicitly closing m_MasterFD, slave_fd and m_CwdPipe[1]
        // A BAD, BAAAD implementation - it tries to close ANY possible file descriptor for this process
        // consider a better way here
        for(int fd = 3, e = MaxFD(); fd < e; fd++)
            if(fd != g_PromptPipe)
                close(fd);
        
        // execution of the program
        execv( m_ShellPath.c_str(), g_ShellParams[(int)m_ShellType] );
        
        // we never get here in normal condition
        printf("fin.\n");
    }
    return true;
}

void ShellTask::ReadChildOutput()
{
    int rc;
    fd_set fd_in, fd_err;

    static const int input_sz = 65536;
    char input[65536];
    
    while( true ) {
        // Wait for data from standard input and master side of PTY
        FD_ZERO(&fd_in);
        FD_SET(m_MasterFD, &fd_in);
        FD_SET(m_CwdPipe[0], &fd_in);
        
        FD_ZERO(&fd_err);
        FD_SET(m_MasterFD, &fd_err);
        
        int max_fd = std::max((int)m_MasterFD, m_CwdPipe[0]);
        
        rc = select(max_fd + 1, &fd_in, NULL, &fd_err, NULL);
        if( m_ShellPID < 0 )
            goto end_of_all; // shell is dead
        
        if( rc < 0 ) {
            std::cerr << "select(max_fd + 1, &fd_in, NULL, &fd_err, NULL) returned "
                << rc << std::endl;
            // error on select(), let's think that shell has died
            // mb call ShellDied() here?
            goto end_of_all;
        }
        
        // check BASH_PROMPT output
        if( FD_ISSET(m_CwdPipe[0], &fd_in) ) {
            rc = (int)read(m_CwdPipe[0], input, input_sz);
            if(rc > 0)
                ProcessPwdPrompt(input, rc);
        }
        
        // If data on master side of PTY (some child's output)
        if( FD_ISSET(m_MasterFD, &fd_in) ) {
            // try to read a bit more - wait 1usec to see if any additional data will come in
            unsigned have_read = ReadInputAsMuchAsAvailable(m_MasterFD, input, input_sz);
            if( !m_TemporarySuppressed )
                DoCalloutOnChildOutput(input, have_read);
        }
        
        // check if child process died
        if( FD_ISSET(m_MasterFD, &fd_err) ) {
//            cout << "shell died: FD_ISSET(m_MasterFD, &fd_err)" << endl;
            if(!m_IsShuttingDown)
                dispatch_to_main_queue([=]{
                    ShellDied();
                });
            goto end_of_all;
        }
    } // End while
end_of_all:
    ;
}

void ShellTask::ProcessPwdPrompt(const void *_d, int _sz)
{
    std::string current_cwd = m_CWD;
    bool do_nr_hack = false;
    bool current_wd_changed = false;

    LOCK_GUARD(m_Lock) {
        char tmp[1024];
        memcpy(tmp, _d, _sz);
        tmp[_sz] = 0;
        while(strlen(tmp) > 0 && ( // need MOAR slow strlens in this while! gimme MOAR!!!!!
                                  tmp[strlen(tmp)-1] == '\n' ||
                                  tmp[strlen(tmp)-1] == '\r' ))
            tmp[strlen(tmp)-1] = 0;
        
        m_CWD = tmp;
        if( m_CWD.empty() || m_CWD.back() != '/' )
            m_CWD += '/';
        
        if(current_cwd != m_CWD) {
            current_cwd = m_CWD;
            current_wd_changed = true;
        }
        
        if(m_State == TaskState::ProgramExternal ||
           m_State == TaskState::ProgramInternal ) {
            // shell just finished running something - let's back it to StateShell state
            SetState(TaskState::Shell);
        }
        
        if( m_TemporarySuppressed &&
           (m_RequestedCWD.empty() || m_RequestedCWD == tmp) ) {
            m_TemporarySuppressed = false;
            if( !m_RequestedCWD.empty() ) {
                m_RequestedCWD = "";
                do_nr_hack = true;
            }
        }
    }
    
    if( m_RequestedCWD.empty() )
        DoOnPwdPromptCallout(current_cwd.c_str(), current_wd_changed);
    if( do_nr_hack )
        DoCalloutOnChildOutput("\n\r", 2);
}


void ShellTask::DoOnPwdPromptCallout( const char *_cwd, bool _changed ) const
{
    m_OnPwdPromptLock.lock();
    auto on_pwd = m_OnPwdPrompt;
    m_OnPwdPromptLock.unlock();
        
    if( on_pwd && *on_pwd )
        (*on_pwd)(_cwd, _changed);
}

void ShellTask::WriteChildInput( std::string_view _data )
{
    if( m_State == TaskState::Inactive || m_State == TaskState::Dead )
        return;
    if( _data.empty() )
        return;

    LOCK_GUARD(m_MasterWriteLock) {
        ssize_t rc = write( m_MasterFD, _data.data(), _data.size() );
        if( rc < 0 || rc !=  _data.size() )
            std::cerr << "write( m_MasterFD, _data.data(), _data.size() ) returned "
                << rc << std::endl;
    }
    
    if( (_data.back() == '\n' || _data.back() == '\r') && m_State == TaskState::Shell ) {
        LOCK_GUARD(m_Lock)
            SetState(TaskState::ProgramInternal);
    }
}

void ShellTask::CleanUp()
{
    LOCK_GUARD(m_Lock) {
        if(m_ShellPID > 0) {
            int pid = m_ShellPID;
            m_ShellPID = -1;
            kill(pid, SIGKILL);
            
            // possible and very bad workaround for sometimes appearing ZOMBIE BASHes
            struct timespec tm, tm2;
            tm.tv_sec  = 0;
            tm.tv_nsec = 10000000L; // 10 ms
            nanosleep(&tm, &tm2);
            
            int status;
            waitpid(pid, &status, 0);
        }
        
        if(m_MasterFD >= 0) {
            close(m_MasterFD);
            m_MasterFD = -1;
        }
        
        if(m_CwdPipe[0] >= 0) {
            close(m_CwdPipe[0]);
            m_CwdPipe[0] = m_CwdPipe[1] = -1;
        }
        
        if( !m_TCSH_FifoPath.empty() ) {
            unlink( m_TCSH_FifoPath.c_str() );
            m_TCSH_FifoPath.clear();
        }
        
        if( m_InputThread.joinable() )
            m_InputThread.join();
        
        m_TemporarySuppressed = false;
        m_RequestedCWD = "";
        m_CWD = "";
        
        SetState(TaskState::Inactive);
    }
}

void ShellTask::ShellDied()
{
    if( m_ShellPID > 0 ) { // no need to call it if PID is already set to invalid - we're in closing state
        SetState(TaskState::Dead);
        CleanUp();
    }
}

void ShellTask::SetState(TaskState _new_state)
{
    m_State = _new_state;
  
    if( m_OnStateChanged )
        m_OnStateChanged(m_State);
//    printf("TermTask state changed to %d\n", _new_state);
}

void ShellTask::ChDir(const char *_new_cwd)
{
    if( m_State != TaskState::Shell )
        return;
    
    auto requested_cwd = EnsureTrailingSlash(_new_cwd);
    LOCK_GUARD(m_Lock)
        if( m_CWD == requested_cwd )
            return; // do nothing if current working directory is the same as requested
    
    requested_cwd = EnsureNoTrailingSlash( requested_cwd ); // cd command don't like trailing slashes
    
    // file I/O here    
    if( !IsDirectoryAvailableForBrowsing(requested_cwd) )
        return;

    LOCK_GUARD(m_Lock) {
        m_TemporarySuppressed = true; // will show no output of shell when changing a directory
        m_RequestedCWD = requested_cwd;
    }
    
    std::string child_feed;
    child_feed += "\x03"; // pass ctrl+C to shell to ensure that no previous user input (if any) will stay
    child_feed += " cd '";
    child_feed += requested_cwd;
    child_feed += "'\n";
    WriteChildInput( child_feed );
}

bool ShellTask::IsCurrentWD(const char *_what) const
{
    char cwd[MAXPATHLEN];
    strcpy(cwd, _what);
    
    if( !IsPathWithTrailingSlash(cwd) )
        strcat(cwd, "/");
    
    return m_CWD == cwd;
}

void ShellTask::Execute(const char *_short_fn, const char *_at, const char *_parameters)
{
    if(m_State != TaskState::Shell)
        return;
    
    std::string cmd = EscapeShellFeed( _short_fn );
    
    // process cwd stuff if any
    char cwd[MAXPATHLEN];
    cwd[0] = 0;
    if(_at != 0)
    {
        strcpy(cwd, _at);
        if(IsPathWithTrailingSlash(cwd) && strlen(cwd) > 1) // cd command don't like trailing slashes
            cwd[strlen(cwd)-1] = 0;
        
        if(IsCurrentWD(cwd))
        {
            cwd[0] = 0;
        }
        else
        {
            if(!IsDirectoryAvailableForBrowsing(cwd)) // file I/O here
                return;
        }
    }
    
    
    char input[2048];
    if(cwd[0] != 0)
        sprintf(input, "cd '%s'; ./%s%s%s\n",
                cwd,
                cmd.c_str(),
                _parameters != nullptr ? " " : "",
                _parameters != nullptr ? _parameters : ""
                );
    else
        sprintf(input, "./%s%s%s\n",
                cmd.c_str(),
                _parameters != nullptr ? " " : "",
                _parameters != nullptr ? _parameters : ""
                );
    
    SetState(TaskState::ProgramExternal);
    WriteChildInput( input );
}

void ShellTask::ExecuteWithFullPath(const char *_path, const char *_parameters)
{
    if(m_State != TaskState::Shell)
        return;
    
    std::string cmd = EscapeShellFeed(_path);
    
    char input[2048];
    sprintf(input, "%s%s%s\n",
            cmd.c_str(),
            _parameters != nullptr ? " " : "",
            _parameters != nullptr ? _parameters : ""
            );

    SetState(TaskState::ProgramExternal);
    WriteChildInput( input );
}

std::vector<std::string> ShellTask::ChildrenList() const
{
    if( m_State == TaskState::Inactive || m_State == TaskState::Dead || m_ShellPID < 0 )
        return {};
    
    size_t proc_cnt = 0;
    kinfo_proc *proc_list;
    if( nc::utility::GetBSDProcessList(&proc_list, &proc_cnt) != 0 )
        return {};

    std::vector<std::string> result;
    for( int i = 0; i < proc_cnt; ++i ) {
        int pid = proc_list[i].kp_proc.p_pid;
        int ppid = proc_list[i].kp_eproc.e_ppid;
        
again:  if( ppid == m_ShellPID ) {
            char name[1024];
            int ret = proc_name( pid, name, sizeof(name) );
            result.emplace_back(ret > 0 ? name : proc_list[i].kp_proc.p_comm);
        }
        else if( ppid >= 1024 )
            for( int j = 0; j < proc_cnt; ++j )
                if( proc_list[j].kp_proc.p_pid == ppid ) {
                    ppid = proc_list[j].kp_eproc.e_ppid;
                    goto again;
                }
    }
    
    free( proc_list );
    return result;
}

int ShellTask::ShellChildPID() const
{
    if(m_State == TaskState::Inactive || m_State == TaskState::Dead || m_State == TaskState::Shell || m_ShellPID < 0)
        return -1;
    
    size_t proc_cnt = 0;
    kinfo_proc *proc_list;
    if(nc::utility::GetBSDProcessList(&proc_list, &proc_cnt) != 0)
        return -1;
    
    int child_pid = -1;
    
    for(int i = 0; i < proc_cnt; ++i) {
        int pid = proc_list[i].kp_proc.p_pid;
        int ppid = proc_list[i].kp_eproc.e_ppid;
        if( ppid == m_ShellPID ) {
            child_pid = pid;
            break;
        }
    }
    
    free(proc_list);
    return child_pid;
}

std::string ShellTask::CWD() const
{
    std::lock_guard<std::mutex> lock(m_Lock);
    return m_CWD;
}

void ShellTask::ResizeWindow(int _sx, int _sy)
{
    if( m_TermSX == _sx && m_TermSY == _sy )
        return;

    m_TermSX = _sx;
    m_TermSY = _sy;
    
    if( m_State != TaskState::Inactive && m_State != TaskState::Dead )
        Task::SetTermWindow(m_MasterFD, _sx, _sy);
}

void ShellTask::Terminate()
{
    CleanUp();
}

void ShellTask::SetOnPwdPrompt(std::function<void(const char *_cwd, bool _changed)> _callback )
{
    LOCK_GUARD(m_OnPwdPromptLock)
        m_OnPwdPrompt = to_shared_ptr( move(_callback) );
}

void ShellTask::SetOnStateChange( std::function<void(TaskState _new_state)> _callback )
{
    m_OnStateChanged = move( _callback );
}

ShellTask::TaskState ShellTask::State() const
{
    return m_State;
}

void ShellTask::SetShellPath(const std::string &_path)
{
    m_ShellPath = _path;
}

}
