//
//  TermTask.cpp
//  TermPlays
//
//  Created by Michael G. Kazakov on 15.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <sys/select.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <string.h>
#include "TermTask.h"
#include "Common.h"

static const char *g_ShellProg     = "/bin/bash";
static       char *g_ShellParam[2] = {(char*)"-L", 0};
static const int   g_PromptPipe    = 20;
static const char *g_PromptString  = "PROMPT_COMMAND=/bin/pwd>&20";

TermTask::TermTask():
    m_MasterFD(-1),
    m_OnChildOutput(0),
    m_State(StateInactive),
    m_ShellPID(-1),
    m_TemporarySuppressed(false)
{
    m_CwdPipe[0] = m_CwdPipe[1] = -1;
    m_RequestedCWD[0] = 0;
    m_CWD[0] = 0;
}

TermTask::~TermTask()
{
    CleanUp();
}

void TermTask::Launch(const char *_work_dir, int _sx, int _sy)
{
    signal(SIGCHLD, SIG_IGN); /* Silently (and portably) reap children. */
    
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
        
        SetState(StateShell);
        
        // TODO: consider using thread here, not a queue (mind maximum running queues issue)
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            ReadChildOutput();
        });
    }
    else
    { // slave/child
        struct termios term_sett; // Saved terminal settings
        
        // Save the defaults parameters of the slave side of the PTY
        rc = tcgetattr(slave_fd, &term_sett);
        term_sett.c_iflag = ICRNL | IXON | IXANY | IMAXBEL | BRKINT;
        term_sett.c_oflag = OPOST | ONLCR;
        term_sett.c_cflag = CREAD | CS8 | HUPCL;
        term_sett.c_lflag = ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL;
        term_sett.c_ispeed = /*B38400*/ B230400;
        term_sett.c_ospeed = /*B38400*/ B230400;
        term_sett.c_cc [VINTR] = 3;   /* CTRL+C */
        term_sett.c_cc [VEOF] = 4;    /* CTRL+D */
        tcsetattr (slave_fd, /*TCSADRAIN*/TCSANOW, &term_sett);
        
        struct winsize winsize;
        winsize.ws_col = _sx;
        winsize.ws_row = _sy;
        winsize.ws_xpixel = 0;
        winsize.ws_ypixel = 0;
        ioctl(slave_fd, TIOCSWINSZ, (char *)&winsize);
        
        // The slave side of the PTY becomes the standard input and outputs of the child process
        close(0); // Close standard input (current terminal)
        close(1); // Close standard output (current terminal)
        close(2); // Close standard error (current terminal)
        
        dup(slave_fd); // PTY becomes standard input (0)
        dup(slave_fd); // PTY becomes standard output (1)
        dup(slave_fd); // PTY becomes standard error (2)
        
        // Make the current process a new session leader
        setsid();
        
        // As the child is a session leader, set the controlling terminal to be the slave side of the PTY
        // (Mandatory for programs like the shell to make them manage correctly their outputs)
        ioctl(0, TIOCSCTTY, 1);
        chdir(_work_dir);
        
        // putenv is a bit better than setenv in terms of performance(no mallocs), so try to use it wisely
        
        // basic terminal environment setup
        putenv ((char *) "TERM=xterm-16color");
        putenv ((char *) "TERM_PROGRAM=Files.app");
        
        // need real config here
        setenv("LC_ALL", "en_US.UTF-8", 1);
        setenv("LANG", "en_US.UTF-8", 1);

        // setup piping for CWD prompt
        // using FD g_PromptPipe becuse bash is closing fds [3,20) upon opening in logon mode (our case)
        rc = dup2(m_CwdPipe[1], g_PromptPipe);
        assert(rc == g_PromptPipe);
        putenv((char*)g_PromptString);
        
        // say BASH to not put into history any command starting with space character
        putenv((char *)"HISTCONTROL=ignorespace");
        
        // close all file descriptors except [0], [1], [2] and [g_PromptPipe]
        // implicitly closing m_MasterFD, slave_fd and m_CwdPipe[1]
        // A BAD, BAAAD implementation - it tries to close ANY possible file descriptor for this process
        // consider a better way here
        int max_fd = (int)sysconf(_SC_OPEN_MAX);
        for(int fd = 3; fd < max_fd; fd++)
            if(fd != g_PromptPipe)
                close(fd);
        
        // execution of the program
        execv(g_ShellProg, g_ShellParam);
        
        // we never get here in normal condition
        printf("fin.\n");
    }
}

void TermTask::ReadChildOutput()
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
        
        int max_fd = m_MasterFD > m_CwdPipe[0] ? m_MasterFD : m_CwdPipe[0];
        
        rc = select(max_fd + 1, &fd_in, NULL, &fd_err, NULL);
        if(rc < 0 || m_ShellPID < 0)
        {
            // error on select(), let's think that shell has died
            // mb call ShellDied() here?
            goto end_of_all;
        }
        
        // If data on master side of PTY (some child's output)
        if(FD_ISSET(m_MasterFD, &fd_in))
        {
            rc = (int)read(m_MasterFD, input, input_sz);
            if (rc > 0)
            {
//                printf("has output\n");                      
                if(m_OnChildOutput && !m_TemporarySuppressed)
                    m_OnChildOutput(input, rc);
            }
            else
            {
                if (rc < 0)
                {
                    fprintf(stderr, "Error %d on read master PTY\n", errno);
                    exit(1);
                }
            }
                    /*
                     if(bytesread < 0 && !(errno == EAGAIN || errno == EINTR)) {
                     [self brokenPipe];
                     return;
                     }
                     */
//                    continue;
        }
                
        // check BASH_PROMPT output
        if (FD_ISSET(m_CwdPipe[0], &fd_in))
        {
            rc = (int)read(m_CwdPipe[0], input, input_sz);
            if(rc > 0)
            {
                ProcessBashPrompt(input, rc);
            }
        }
                
        // check if child process died
        if(FD_ISSET(m_MasterFD, &fd_err))
        {
            ShellDied();
            goto end_of_all;
        }
    } // End while
end_of_all:
    ;
}

void TermTask::ProcessBashPrompt(const void *_d, int _sz)
{
    m_Lock.lock();
    
    char tmp[1024];
    memcpy(tmp, _d, _sz);
    tmp[_sz] = 0;
    while(strlen(tmp) > 0 && ( // need MOAR slow strlens in this while! gimme MOAR!!!!!
                              tmp[strlen(tmp)-1] == '\n' ||
                              tmp[strlen(tmp)-1] == '\r' ))
        tmp[strlen(tmp)-1] = 0;
    
    strcpy(m_CWD, tmp);
    
    if(m_OnBashPrompt)
        m_OnBashPrompt(tmp);
    
    if(m_State == TermState::StateProgramExternal ||
       m_State == TermState::StateProgramInternal )
    {
        // shell just finished running something - let's back it to StateShell state
        SetState(StateShell);
    }
    
    if(m_TemporarySuppressed && strcmp(tmp, m_RequestedCWD) == 0)
    {
        m_TemporarySuppressed = false;
        m_RequestedCWD[0] = 0;
            
        if(m_OnChildOutput)
            m_OnChildOutput("\n\r", 2); // hack

    }
    
    m_Lock.unlock();
}

void TermTask::WriteChildInput(const void *_d, int _sz)
{
    if(m_State == StateInactive ||
       m_State == StateDead )
        return;
    
    if(_sz <= 0)
        return;
    
    m_Lock.lock();
    
    
    write(m_MasterFD, _d, _sz);
    
    
    if( ((char*)_d)[_sz-1] == '\n' ||
        ((char*)_d)[_sz-1] == '\r' )
        if(m_State == StateShell)
            SetState(StateProgramInternal);
    
    m_Lock.unlock();
}

void TermTask::CleanUp()
{
    m_Lock.lock();
    
    if(m_ShellPID > 0)
    {
        int pid = m_ShellPID;
        m_ShellPID = -1;
        kill(pid, SIGKILL);
        // waitpid(pid, 0, 0);
    }
    
    if(m_MasterFD >= 0)
    {
        close(m_MasterFD);
        m_MasterFD = -1;
    }
    
    if(m_CwdPipe[0] >= 0)
    {
        close(m_CwdPipe[0]);
        m_CwdPipe[0] = m_CwdPipe[1] = -1;
    }
    
    m_TemporarySuppressed = false;
    m_RequestedCWD[0] = 0;
    m_CWD[0] = 0;
    
    SetState(StateInactive);
    
    m_Lock.unlock();
}

void TermTask::ShellDied()
{
    if(m_ShellPID > 0) // no need to call it if PID is already set to invalid - we're in closing state
    {
        SetState(StateDead);
        CleanUp();
    }
}

void TermTask::SetState(TermTask::TermState _new_state)
{
    m_State = _new_state;
    
    printf("TermTask state changed to %d\n", _new_state);
}

void TermTask::ChDir(const char *_new_cwd)
{
    char new_cwd[MAXPATHLEN];
    strcpy(new_cwd, _new_cwd);
    if(IsPathWithTrailingSlash(new_cwd) && strlen(new_cwd) > 1) // cd command don't like trailing slashes
        new_cwd[strlen(new_cwd)-1] = 0;
    
    if(strcmp(m_CWD, new_cwd) == 0) // do nothing if current working directory is the same as requested
        return;
    
    if(!IsDirectoryAvailableForBrowsing(new_cwd)) // file I/O here
        return;
    
    // escape special symbols
    NSString *orig = [NSString stringWithUTF8String:new_cwd];
    if(!orig) return;
//    NSString *escap = [orig stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//    if(!escap) return;
    const char *cwd = [/*escap*/ orig UTF8String];
    
    m_TemporarySuppressed = true; // will show no output of bash when changing a directory
    strcpy(m_RequestedCWD, new_cwd);
    
    WriteChildInput(" cd '", 5);
    WriteChildInput(cwd, (int)strlen(cwd));
    WriteChildInput("'\n", 2);
}

void TermTask::Execute(const char *_short_fn)
{
    // TODO: OPTIMIZE!
    NSString *orig = [NSString stringWithUTF8String:_short_fn];
    if(!orig) return;
    
    NSMutableString *destString = [@"" mutableCopy];
    NSCharacterSet *escapeCharsSet = [NSCharacterSet characterSetWithCharactersInString:@" ()\\"];
    
    NSScanner *scanner = [NSScanner scannerWithString:orig];
    while (![scanner isAtEnd]) {
        NSString *tempString;
        [scanner scanUpToCharactersFromSet:escapeCharsSet intoString:&tempString];
        if([scanner isAtEnd]){
            [destString appendString:tempString];
        }
        else {
            [destString appendFormat:@"%@\\%@", tempString, [orig substringWithRange:NSMakeRange([scanner scanLocation], 1)]];
            [scanner setScanLocation:[scanner scanLocation]+1];
        }
    }
    
    
    const char *utf8 = [destString UTF8String];
    WriteChildInput("./", 2);
    WriteChildInput(utf8, (int)strlen(utf8));
    WriteChildInput("\n", 1);
//    const char *ut = [/*escap*/ orig UTF8String];
}
