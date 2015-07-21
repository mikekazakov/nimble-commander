//
//  TermTask.cpp
//  TermPlays
//
//  Created by Michael G. Kazakov on 15.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

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
#include "TermShellTask.h"
#include "Common.h"
#include "sysinfo.h"

static const char *g_ShellProg     = "/bin/bash";
static       char *g_ShellParam[2] = {(char*)"-L", 0};
static const int   g_PromptPipe    = 20;
static const char *g_PromptStringPID  = "a=$$; b=%d; if [ $a -eq $b ]; then /bin/pwd>&20; fi";

static bool IsDirectoryAvailableForBrowsing(const char *_path)
{
    DIR *dirp = opendir(_path);
    if(dirp == 0)
        return false;
    closedir(dirp);
    return true;
}

TermShellTask::~TermShellTask()
{
    m_IsShuttingDown = true;
    CleanUp();
}

void TermShellTask::Launch(const char *_work_dir, int _sx, int _sy)
{
    if(m_InputThread.joinable())
        throw logic_error("TermShellTask::Launch called with joinable input thread");
    
    m_TermSX = _sx;
    m_TermSY = _sy;
    
    // remember current locale and stuff
    auto env = BuildEnv();
    
    m_MasterFD = posix_openpt(O_RDWR);
    assert(m_MasterFD >= 0);
    
    grantpt(m_MasterFD);
    unlockpt(m_MasterFD);
    
    int slave_fd = open(ptsname(m_MasterFD), O_RDWR);
    
    // init FIFO stuff for BASH' CWD
    int rc = pipe(m_CwdPipe);
    assert(rc == 0);
    
    // Create the child process
    if((rc = fork()))
    { // master
        m_ShellPID = rc;
        close(slave_fd);
        close(m_CwdPipe[1]);
        
        SetState(TaskState::Shell);
        
        m_InputThread = thread([=]{
            pthread_setname_np( ("TermShellTask background input thread, PID="s + to_string(m_ShellPID)).c_str() );
            ReadChildOutput();
        });
    }
    else
    { // slave/child
        SetupTermios(slave_fd);
        SetTermWindow(slave_fd, _sx, _sy);
        SetupHandlesAndSID(slave_fd);
        
        chdir(_work_dir);
        
        // put basic environment stuff
        SetEnv(env);
        
        // setup piping for CWD prompt
        // using FD g_PromptPipe becuse bash is closing fds [3,20) upon opening in logon mode (our case)
        rc = dup2(m_CwdPipe[1], g_PromptPipe);
        assert(rc == g_PromptPipe);
        
        // set bash prompt so it will report only when executed by original fork (to exclude execution by it's later forks)
        char bash_prompt[1024];
        sprintf(bash_prompt, g_PromptStringPID, (int)getpid());
        setenv("PROMPT_COMMAND", bash_prompt, 1);
        
        // say BASH to not put into history any command starting with space character
        putenv((char *)"HISTCONTROL=ignorespace");
        
        // close all file descriptors except [0], [1], [2] and [g_PromptPipe]
        // implicitly closing m_MasterFD, slave_fd and m_CwdPipe[1]
        // A BAD, BAAAD implementation - it tries to close ANY possible file descriptor for this process
        // consider a better way here
        static const int max_fd = (int)sysconf(_SC_OPEN_MAX);
        for(int fd = 3; fd < max_fd; fd++)
            if(fd != g_PromptPipe)
                close(fd);
        
        // execution of the program
        execv(g_ShellProg, g_ShellParam);
        
        // we never get here in normal condition
        printf("fin.\n");
    }
}

void TermShellTask::ReadChildOutput()
{
    int rc;
    fd_set fd_in, fd_err;

    static const int input_sz = 65536;
    char input[65536];
    
    while (1)
    {
        // Wait for data from standard input and master side of PTY
        FD_ZERO(&fd_in);
        FD_SET(m_MasterFD, &fd_in);
        FD_SET(m_CwdPipe[0], &fd_in);
        
        FD_ZERO(&fd_err);
        FD_SET(m_MasterFD, &fd_err);
        
        int max_fd = max((int)m_MasterFD, m_CwdPipe[0]);
        
        rc = select(max_fd + 1, &fd_in, NULL, &fd_err, NULL);
        if(rc < 0 || m_ShellPID < 0) {
            // error on select(), let's think that shell has died
            // mb call ShellDied() here?
            goto end_of_all;
        }
        
        // If data on master side of PTY (some child's output)
        if(FD_ISSET(m_MasterFD, &fd_in)) {
            // try to read a bit more - wait 1usec to see if any additional data will come in
            unsigned have_read = ReadInputAsMuchAsAvailable(m_MasterFD, input, input_sz);
            if(!m_TemporarySuppressed)
                DoCalloutOnChildOutput(input, have_read);
        }
        
        // check BASH_PROMPT output
        if (FD_ISSET(m_CwdPipe[0], &fd_in)) {
            rc = (int)read(m_CwdPipe[0], input, input_sz);
            if(rc > 0)
                ProcessBashPrompt(input, rc);
        }
                
        // check if child process died
        if(FD_ISSET(m_MasterFD, &fd_err)) {
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

void TermShellTask::ProcessBashPrompt(const void *_d, int _sz)
{
    string current_cwd;
    bool do_nr_hack = false;

    {
        lock_guard<mutex> lock(m_Lock);
        
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
        
        current_cwd = m_CWD;
        
        if(m_State == TaskState::ProgramExternal ||
           m_State == TaskState::ProgramInternal ) {
            // shell just finished running something - let's back it to StateShell state
            SetState(TaskState::Shell);
        }
        
        if(m_TemporarySuppressed && m_RequestedCWD == tmp) {
            m_TemporarySuppressed = false;
            m_RequestedCWD = "";
            do_nr_hack = true;
        }
    }
    
    if( m_OnBashPrompt && m_RequestedCWD.empty() )
        m_OnBashPrompt(current_cwd.c_str());
    if(do_nr_hack)
        DoCalloutOnChildOutput("\n\r", 2);
}

void TermShellTask::WriteChildInput(const void *_d, int _sz)
{
    if(m_State == TaskState::Inactive ||
       m_State == TaskState::Dead )
        return;
    
    if(_sz <= 0)
        return;

    lock_guard<mutex> lock(m_Lock);
    
    write(m_MasterFD, _d, _sz);
    
    if( ((char*)_d)[_sz-1] == '\n' ||
        ((char*)_d)[_sz-1] == '\r' )
        if(m_State == TaskState::Shell)
            SetState(TaskState::ProgramInternal);
}

void TermShellTask::CleanUp()
{
    lock_guard<mutex> lock(m_Lock);
    
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
    
    if( m_InputThread.joinable() )
        m_InputThread.join();
    
    m_TemporarySuppressed = false;
    m_RequestedCWD = "";
    m_CWD = "";
    
    SetState(TaskState::Inactive);
}

void TermShellTask::ShellDied()
{
    if(m_ShellPID > 0) // no need to call it if PID is already set to invalid - we're in closing state
    {
        SetState(TaskState::Dead);
        CleanUp();
    }
}

void TermShellTask::SetState(TaskState _new_state)
{
    m_State = _new_state;
  
    // do some fancy stuff here
    
//    printf("TermTask state changed to %d\n", _new_state);
}

void TermShellTask::ChDir(const char *_new_cwd)
{
    if(m_State != TaskState::Shell)
        return;
    
    if(IsCurrentWD(_new_cwd))
        return; // do nothing if current working directory is the same as requested
    
    char new_cwd[MAXPATHLEN];
    strcpy(new_cwd, _new_cwd);
    if(IsPathWithTrailingSlash(new_cwd) && strlen(new_cwd) > 1) // cd command don't like trailing slashes
       new_cwd[strlen(new_cwd)-1] = 0;
    
    if(!IsDirectoryAvailableForBrowsing(new_cwd)) // file I/O here
        return;

    m_TemporarySuppressed = true; // will show no output of bash when changing a directory
    m_RequestedCWD = new_cwd;
    
    WriteChildInput("\x03", 1); // pass ctrl+C to shell to ensure that no previous user input (if any) will stay
    WriteChildInput(" cd '", 5);
    WriteChildInput(new_cwd, (int)strlen(new_cwd));
    WriteChildInput("'\n", 2);
}

bool TermShellTask::IsCurrentWD(const char *_what) const
{
    char cwd[MAXPATHLEN];
    strcpy(cwd, _what);
    
    if(!IsPathWithTrailingSlash(cwd))
        strcat(cwd, "/");
    
    return m_CWD == cwd;
}

void TermShellTask::Execute(const char *_short_fn, const char *_at, const char *_parameters)
{
    if(m_State != TaskState::Shell)
        return;
    
    char cmd[MAXPATHLEN];
    EscapeShellFeed(_short_fn, cmd, MAXPATHLEN); // black magic inside
    
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
                cmd,
                _parameters != nullptr ? " " : "",
                _parameters != nullptr ? _parameters : ""
                );
    else
        sprintf(input, "./%s%s%s\n",
                cmd,
                _parameters != nullptr ? " " : "",
                _parameters != nullptr ? _parameters : ""
                );
    
    SetState(TaskState::ProgramExternal);
    WriteChildInput(input, (int)strlen(input));
}

void TermShellTask::ExecuteWithFullPath(const char *_path, const char *_parameters)
{
    if(m_State != TaskState::Shell)
        return;
    
    char cmd[MAXPATHLEN];
    EscapeShellFeed(_path, cmd, MAXPATHLEN); // black magic inside
    
    char input[2048];
    sprintf(input, "%s%s%s\n",
            cmd,
            _parameters != nullptr ? " " : "",
            _parameters != nullptr ? _parameters : ""
            );

    SetState(TaskState::ProgramExternal);
    WriteChildInput(input, (int)strlen(input));
}

int TermShellTask::EscapeShellFeed(const char *_feed, char *_escaped, size_t _buf_sz)
{
    if(_feed == nullptr)
        return -1;
    
    // TODO: OPTIMIZE!
    NSString *orig = [NSString stringWithUTF8String:_feed];
    if(!orig)
        return -1;
    
    // TODO: rewrite this NS-style shit with plain C-strings manipulations
    static NSCharacterSet *escapeCharsSet = [NSCharacterSet characterSetWithCharactersInString:@" ()\\!"];
    
    NSMutableString *destString = [@"" mutableCopy];
    NSScanner *scanner = [NSScanner scannerWithString:orig];
    scanner.charactersToBeSkipped = nil;
    while (![scanner isAtEnd]) {
        NSString *tempString;
        [scanner scanUpToCharactersFromSet:escapeCharsSet intoString:&tempString];
        if([scanner isAtEnd]){
            [destString appendString:tempString];
        }
        else {
            if(tempString != nil)
                [destString appendFormat:@"%@\\%@", tempString, [orig substringWithRange:NSMakeRange([scanner scanLocation], 1)]];
            else
                [destString appendFormat:@"\\%@", [orig substringWithRange:NSMakeRange([scanner scanLocation], 1)]];
            [scanner setScanLocation:[scanner scanLocation]+1];
        }
    }
    
    const char *res = destString.UTF8String;
    size_t res_sz = destString.length;
    
    if(res_sz >= _buf_sz)
    {
        strncpy(_escaped, res, _buf_sz-1);
        _escaped[_buf_sz-1] = 0;
        return (int)_buf_sz;
    }
    strcpy(_escaped, res);
    return (int)res_sz;
}

vector<string> TermShellTask::ChildrenList()
{
    if(m_State == TaskState::Inactive || m_State == TaskState::Dead || m_ShellPID < 0)
        return vector<string>();
    
    size_t proc_cnt = 0;
    kinfo_proc *proc_list;
    if(sysinfo::GetBSDProcessList(&proc_list, &proc_cnt) != 0)
        return vector<string>();

    vector<string> result;
    
    for(int i = 0; i < proc_cnt; ++i)
    {
        int pid = proc_list[i].kp_proc.p_pid;
        int ppid = proc_list[i].kp_eproc.e_ppid;
        
again:  if(ppid == m_ShellPID)
        {
            char name[1024];
            int ret = proc_name(pid, name, sizeof(name));
            result.emplace_back(ret > 0 ? name : proc_list[i].kp_proc.p_comm);
        }
        else if(ppid >= 1024)
            for(int j = 0; j < proc_cnt; ++j)
                if(proc_list[j].kp_proc.p_pid == ppid)
                {
                    ppid = proc_list[j].kp_eproc.e_ppid;
                    goto again;
                }
    }
    
    free(proc_list);
    return result;
}

string TermShellTask::CWD() const
{
    lock_guard<mutex> lock(m_Lock);
    return m_CWD;
}

void TermShellTask::ResizeWindow(int _sx, int _sy)
{
    if(m_TermSX == _sx && m_TermSY == _sy)
        return;

    m_TermSX = _sx;
    m_TermSY = _sy;
    
    if(m_State != TaskState::Inactive && m_State != TaskState::Dead)
        TermTask::SetTermWindow(m_MasterFD, _sx, _sy);
}

void TermShellTask::Terminate()
{
    CleanUp();
}

void TermShellTask::SetOnBashPrompt(function<void(const char *_cwd)> _callback )
{
    m_OnBashPrompt = move(_callback);
}
