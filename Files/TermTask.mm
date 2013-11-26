//
//  TermTask.cpp
//  TermPlays
//
//  Created by Michael G. Kazakov on 15.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <stdlib.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <sys/select.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <string.h>
#include <signal.h>
#include <dispatch/dispatch.h>
#include "TermTask.h"

static const char *g_ShellProg = "/bin/bash";
static       char *g_ShellParam[2] = {(char*)"-L", 0};

static void chldied (int dummy)
{
    /* Просто кончимся */
    //   termination (34);
    printf("Child died\n");
}

TermTask::TermTask():
    m_MasterFD(-1),
    m_OnChildOutput(0)
{
    pthread_mutex_init(&m_Lock, NULL);    
}

void TermTask::Launch(const char *_work_dir, int _sx, int _sy)
{
    int rc;
    m_MasterFD = posix_openpt(O_RDWR);
    grantpt(m_MasterFD);
    unlockpt(m_MasterFD);
    
    struct sigaction sact;
    /* Установим обработку сигнала о завершении потомка */
    sact.sa_handler = chldied;
    sigemptyset(&sact.sa_mask);
    sact.sa_flags = 0;
    sigaction(SIGCHLD, &sact, (struct sigaction *) NULL);
    
    int slave_fd = open(ptsname(m_MasterFD), O_RDWR);
    
    // init FIFO stuff for BASH' CWD
    rc = pipe(m_CwdPipe);
    assert(rc == 0);
    
    // Create the child process
    if(fork())
    { // master
        close(slave_fd);
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            ReadChildOutput();
        });
    }
    else
    { // slave/child
        struct termios term_sett; // Saved terminal settings

        // Close the master side of the PTY
        close(m_MasterFD);
        
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
        
        // Now the original file descriptor is useless
        close(slave_fd);
        
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
        // using FD 20 becuse bash is closing fds [3,20) upon opening in logon mode (our case)
        rc = dup2(m_CwdPipe[1], 20);
        assert(rc == 20);
        close(m_CwdPipe[1]);
        setenv("PROMPT_COMMAND", "/bin/pwd>&20", 1);
        
        // execution of the program
        execv(g_ShellProg, g_ShellParam);
        
        // we never get here in normal condition
        printf("fin.\n");
    }
}

void TermTask::ReadChildOutput()
{
    int rc;
    fd_set fd_in;

    static const int input_sz = 65536;
    char input[65536];
    
    while (1)
    {
        // Wait for data from standard input and master side of PTY
        FD_ZERO(&fd_in);
        FD_SET(m_MasterFD, &fd_in);
        FD_SET(m_CwdPipe[0], &fd_in);
        int max_fd = m_MasterFD > m_CwdPipe[0] ? m_MasterFD : m_CwdPipe[0];
        
        rc = select(max_fd + 1, &fd_in, NULL, NULL, NULL);
        switch(rc)
        {
            case -1 : fprintf(stderr, "Error %d on select()\n", errno);
                exit(1);
                
            default :
            {
                // If data on master side of PTY
                if (FD_ISSET(m_MasterFD, &fd_in))
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
                }
                
                // check BASH_PROMPT output
                if (FD_ISSET(m_CwdPipe[0], &fd_in))
                {
                    char buf[1024];
                    rc = (int)read(m_CwdPipe[0], buf, 1024);
                    if(rc > 0)
                    {
//                        buf[rc] = 0;
//                        printf("%s\n", buf);
                        if(m_OnBashPrompt)
                            m_OnBashPrompt(buf, rc);
                    }
                }
            }
        } // End switch
    } // End while
}

void TermTask::SetOnChildOutput(void (^_h)(const void* _d, int _sz))
{
    m_OnChildOutput = _h;
}

void TermTask::WriteChildInput(const void *_d, int _sz)
{
    pthread_mutex_lock(&m_Lock);
    write(m_MasterFD, _d, _sz);
    pthread_mutex_unlock(&m_Lock);
}
