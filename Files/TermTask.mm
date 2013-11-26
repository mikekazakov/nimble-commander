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

static void chldied (int dummy)
{
    /* Просто кончимся */
    //   termination (34);
    printf("Child died\n");
}

TermTask::TermTask():
    m_MasterFD(-1),
    m_SlaveFD(-1),
    m_OnChildOutput(0)
{
    pthread_mutex_init(&m_Lock, NULL);    
}

void TermTask::Launch(
            const char *_work_dir,
            const char *_prog_name,
            char *const _argv[],
            int _sx,
            int _sy          
            )
{
    m_MasterFD = posix_openpt(O_RDWR);
    grantpt(m_MasterFD);
    unlockpt(m_MasterFD);
    
    struct sigaction sact;
    /* Установим обработку сигнала о завершении потомка */
    sact.sa_handler = chldied;
    sigemptyset(&sact.sa_mask);
    sact.sa_flags = 0;
    sigaction(SIGCHLD, &sact, (struct sigaction *) NULL);
    
    m_SlaveFD = open(ptsname(m_MasterFD), O_RDWR);
    
    // init FIFO stuff for BASH' CWD
    /*
    g_snprintf (tcsh_fifo, sizeof (tcsh_fifo), "%s/mc.pipe.%d",
                mc_tmpdir (), (int) getpid ());
    if (mkfifo (tcsh_fifo, 0600) == -1)*/
    
/*    const char *fifo_name = "/users/migun/UBER_FIFO";
    int ret = mkfifo(fifo_name, 0600);
    m_CwdPipe = open(fifo_name, O_RDWR);*/
    
//    m_CwdPipe[1] = open(fifo_name, O_RDWR);
//    int cwd_pipe = m_CwdPipe[1];
    
//    int fildes[2];
//    pipe(Pipe);
    
    pipe(m_CwdPipe);
    
    
    // Create the child process
    if(fork())
    { // master
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            ReadChildOutput();
        });
    }
    else
    { // slave/child
        struct termios slave_orig_term_settings; // Saved terminal settings
//        struct termios new_term_settings; // Current terminal settings
        int rc;
        
        // Close the master side of the PTY
        close(m_MasterFD);
        
        // Save the defaults parameters of the slave side of the PTY
        rc = tcgetattr(m_SlaveFD, &slave_orig_term_settings);
        
        // Set RAW mode on slave side of PTY
        /*        new_term_settings = slave_orig_term_settings;
         cfmakeraw (&new_term_settings);
         tcsetattr (fds, TCSANOW, &new_term_settings);*/
//        slave_orig_term_settings.c_iflag = 0;
        slave_orig_term_settings.c_iflag = ICRNL | IXON | IXANY | IMAXBEL | BRKINT;
        
//        slave_orig_term_settings.c_oflag = ONLCR;
        slave_orig_term_settings.c_oflag = OPOST | ONLCR;
        
//        slave_orig_term_settings.c_cflag = CS8 | HUPCL;
        slave_orig_term_settings.c_cflag = CREAD | CS8 | HUPCL;
        
//        slave_orig_term_settings.c_lflag = ISIG | ICANON | ECHO | ECHOE | ECHOK;
        slave_orig_term_settings.c_lflag = ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL;
        
//        term->c_iflag = ICRNL | IXON | IXANY | IMAXBEL | BRKINT;
//        term->c_oflag = OPOST | ONLCR;
//        term->c_cflag = CREAD | CS8 | HUPCL;
//        term->c_lflag = ICANON | ISIG | IEXTEN | ECHO | ECHOE | ECHOK | ECHOKE | ECHOCTL;

        
        
        slave_orig_term_settings.c_ispeed = /*B38400*/ B230400;
        slave_orig_term_settings.c_ospeed = /*B38400*/ B230400;
        slave_orig_term_settings.c_cc [VINTR] = 3;   /* CTRL+C */
        slave_orig_term_settings.c_cc [VEOF] = 4;    /* CTRL+D */
        tcsetattr (m_SlaveFD, /*TCSADRAIN*/TCSANOW, &slave_orig_term_settings);
        
        struct winsize winsize;
        winsize.ws_col = _sx;
        winsize.ws_row = _sy;
        winsize.ws_xpixel = 0;
        winsize.ws_ypixel = 0;
        ioctl(m_SlaveFD, TIOCSWINSZ, (char *)&winsize);
        
        // The slave side of the PTY becomes the standard input and outputs of the child process
        close(0); // Close standard input (current terminal)
        close(1); // Close standard output (current terminal)
        close(2); // Close standard error (current terminal)
        
        dup(m_SlaveFD); // PTY becomes standard input (0)
        dup(m_SlaveFD); // PTY becomes standard output (1)
        dup(m_SlaveFD); // PTY becomes standard error (2)
        
        
        
//        int pipe = open(fifo_name, O_RDWR);
//        printf("pipe: %d\n", pipe);
        
        // Now the original file descriptor is useless
        close(m_SlaveFD);
        
        // Make the current process a new session leader
        setsid();
        
        // As the child is a session leader, set the controlling terminal to be the slave side of the PTY
        // (Mandatory for programs like the shell to make them manage correctly their outputs)
        ioctl(0, TIOCSCTTY, 1);
        chdir(_work_dir);
        
        
//        putenv((char*)"TERM=xterm-256color");
        putenv((char*)"TERM=xterm-16color");        
        putenv((char*)"Files.app");
        putenv((char*)"LC_ALL=en_US.UTF-8");
        putenv((char*)"LANG=en_US.UTF-8");
//        putenv((char*)"PROMPT_COMMAND='pwd>&1;kill -STOP $$'\n");
//        putenv((char*)"PROMPT_COMMAND='pwd>&1'\n");
//        putenv((char*)"PROMPT_COMMAND=/bin/pwd>&3");
//        putenv((char*)"PROMPT_COMMAND=/bin/pwd>&10");
//        putenv((char*)"PROMPT_COMMAND=/bin/pwd>/users/migun/UBER_FIFO");
//        putenv((char*)"PROMPT_COMMAND=/bin/pwd>&3");

/*        char rrrrr[256];
//        open("/users/migun/1", O_RDWR)
        int ret = open("/users/migun/1", O_RDWR|O_TRUNC);
        printf("open returned %d\n", ret);
        printf("dup2 returned %d\n", dup2(ret, 9));
        sprintf(rrrrr, "PROMPT_COMMAND=/bin/pwd>&%d", 9);
        printf("%s\n", rrrrr);
        putenv(rrrrr);*/
        char rrrrr[256];
        
        
        sprintf(rrrrr, "PROMPT_COMMAND=/bin/pwd>&%d", dup2(m_CwdPipe[1], 20));
        close(m_CwdPipe[1]);
        printf("%s\n", rrrrr);
        putenv(rrrrr);
        
//        write(20, "hello", 5);
        
    
        
//        putenv((char*)"LANG=C");
        
//        export
//        export
        
        // Execution of the program
        
/*        switch (subshell_type)
        {
            case BASH:
                g_snprintf (precmd, sizeof (precmd),
                            " PROMPT_COMMAND='pwd>&%d;kill -STOP $$'\n", subshell_pipe[WRITE]);
                break;*/
        
        
//        printf("alive\n");
        
//        char *param[2] = {"-L", 0};
//
        
//        execvp("/users/migun/11111111qqq", _argv);
        
        // NB!!!!! DO NOT PASS -L (LOGIN) PARAMETER TO BASH!!!
        // It will close [3..20) fds upon starting manually due to this param:
        // if (login_shell && interactive_shell)
        // {
        //     for (i = 3; i < 20; i++)
        //        close (i);
        // }
        // so no CWD piping can work
        
        execvp(_prog_name, _argv);
        
        // we never get here in normal condition
        printf("fin\n");
    }
    
}

void TermTask::ReadChildOutput()
{
    int rc;
    fd_set fd_in;
    // FATHER
    // Close the slave side of the PTY
    close(m_SlaveFD);
    int input_sz = 4096;
    char input[4096];
    
    while (1)
    {
        // Wait for data from standard input and master side of PTY
        FD_ZERO(&fd_in);
//        FD_SET(0, &fd_in);
        FD_SET(m_MasterFD, &fd_in);
        FD_SET(m_CwdPipe[0], &fd_in);
        int max_fd = m_MasterFD > m_CwdPipe[0] ? m_MasterFD : m_CwdPipe[0];
        
//        rc = select(m_SlaveFD + 1, &fd_in, NULL, NULL, NULL);
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
