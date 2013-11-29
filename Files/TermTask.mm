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

static const char *g_ShellProg     = "/bin/bash";
static       char *g_ShellParam[2] = {(char*)"-L", 0};
static const int   g_PromptPipe    = 20;
static const char *g_PromptString  = "/bin/pwd>&20";

TermTask::TermTask():
    m_MasterFD(-1),
    m_OnChildOutput(0),
    m_State(StateInactive),
    m_ShellPID(-1)
{
    m_CwdPipe[0] = m_CwdPipe[1] = -1;
}

TermTask::~TermTask()
{
    CleanUp();
}

void TermTask::Launch(const char *_work_dir, int _sx, int _sy)
{
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
        
        // basic terminal environment setup
        setenv("TERM", "xterm-16color", 1);
        setenv("TERM_PROGRAM", "Files.app", 1);
        
        // need real config here
        setenv("LC_ALL", "en_US.UTF-8", 1);
        setenv("LANG", "en_US.UTF-8", 1);

        // setup piping for CWD prompt
        // using FD g_PromptPipe becuse bash is closing fds [3,20) upon opening in logon mode (our case)
        rc = dup2(m_CwdPipe[1], g_PromptPipe);
        assert(rc == g_PromptPipe);
        setenv("PROMPT_COMMAND", g_PromptString, 1);
        
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
        switch(rc)
        {
            case -1 : fprintf(stderr, "Error %d on select()\n", errno);
                exit(1);
                
            default :
            {
                // If data on master side of PTY (some child's output)
                if(FD_ISSET(m_MasterFD, &fd_in))
                {
                    rc = (int)read(m_MasterFD, input, input_sz);
                    if (rc > 0)
                    {
                        if(m_OnChildOutput)
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
                }
                
                // check if child process died
                if(FD_ISSET(m_MasterFD, &fd_err))
                {
                    ShellDied();
                    goto end_of_all;
                }
                
                // check BASH_PROMPT output
                if (FD_ISSET(m_CwdPipe[0], &fd_in))
                {
                    rc = (int)read(m_CwdPipe[0], input, input_sz);
                    if(rc > 0)
                    {
                        if(m_OnBashPrompt)
                            m_OnBashPrompt(input, rc);
                        
                        if(m_State == TermState::StateProgramExternal ||
                           m_State == TermState::StateProgramInternal )
                        {
                            // shell just finished running something - let's back it to StateShell state
                            SetState(StateShell);
                        }
                    }
                }
            }
        } // End switch
    } // End while
end_of_all:
    ;
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
    {
        if(m_State == StateShell)
        {
            SetState(StateProgramInternal);
        }
    }
    
    
    m_Lock.unlock();
}

void TermTask::CleanUp()
{
    m_Lock.lock();
    
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
    
    m_ShellPID = -1;
    
    SetState(StateInactive);
    
    m_Lock.unlock();
}

void TermTask::ShellDied()
{
    SetState(StateDead);
    CleanUp();
}

void TermTask::SetState(TermTask::TermState _new_state)
{
    m_State = _new_state;
    
    printf("TermTask state changed to %d\n", _new_state);
}

void TermTask::ChDir(const char *_new_cwd)
{
    // escape special symbols
    NSString *orig = [NSString stringWithUTF8String:_new_cwd];
    if(!orig) return;
//    NSString *escap = [orig stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
//    if(!escap) return;
    const char *cwd = [/*escap*/ orig UTF8String];
    
    WriteChildInput(" cd '", 5);
    WriteChildInput(cwd, (int)strlen(cwd));
    WriteChildInput("'\n", 2);
//    char r = 13;
//    WriteChildInput(, 1);
//    write_all (mc_global.tty.subshell_pty, "\n", 1);
    
}
