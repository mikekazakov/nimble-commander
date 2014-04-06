//
//  TermSingleTask.cpp
//  Files
//
//  Created by Michael G. Kazakov on 04.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <sys/ioctl.h>
#include <sys/sysctl.h>

#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/stat.h>

#include <errno.h>
#include <fcntl.h>
#include <grp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <util.h>
#include <syslog.h>

#include <vector>
#include <string>

#include "TermTaskCommon.h"
#include "TermSingleTask.h"

static vector<string> SplitArgs(const char *_args)
{
    vector<string> vec;
    
    char *args = strdup(_args);
    int sz = (int)strlen(args);
    int lp = 0;
    for(int i = 0; i < sz; ++i)
    {
        if(args[i] == '\\')
        {
            memmove(args + i, args+i+1, sz - i + 1);
            sz--;
        }
        else if(args[i] == ' ')
        {
            if(i - lp > 0)
                vec.emplace_back(args + lp, i - lp);
            lp = i+1;
        }
    }
    
    if(sz - lp > 0)
        vec.emplace_back(args + lp, sz - lp);
    
    free(args);
    
    return vec;
}

TermSingleTask::TermSingleTask()
{
}

TermSingleTask::~TermSingleTask()
{
}

void TermSingleTask::Launch(const char *_full_binary_path, const char *_params, int _sx, int _sy)
{
    m_TermSX = _sx;
    m_TermSY = _sy;
    
    // remember current locale and encoding
    char locenc[256];
    sprintf(locenc, "%s.UTF-8", [[NSLocale currentLocale] localeIdentifier].UTF8String);
    
    m_MasterFD = posix_openpt(O_RDWR);
    assert(m_MasterFD >= 0);
    
    grantpt(m_MasterFD);
    unlockpt(m_MasterFD);
    
    int slave_fd = open(ptsname(m_MasterFD), O_RDWR);
    
    int rc;
    
    // Create the child process
    if((rc = fork()))
    { // master
        m_TaskPID = rc;
        close(slave_fd);
//        close(m_CwdPipe[1]);
        
//        SetState(StateShell);
        
        // TODO: consider using thread here, not a queue (mind maximum running queues issue)
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            ReadChildOutput();
        });
    }
    else
    { // slave/child
        TermTask::SetupTermios(slave_fd);
        TermTask::SetTermWindow(slave_fd, _sx, _sy);
        
        // Make the current process a new session leader
        setsid();
        
        // As the child is a session leader, set the controlling terminal to be the slave side of the PTY
        // (Mandatory for programs like the shell to make them manage correctly their outputs)
        ioctl(0, TIOCSCTTY, 1);
        
        // The slave side of the PTY becomes the standard input and outputs of the child process
        close(0); // Close standard input (current terminal)
        close(1); // Close standard output (current terminal)
        close(2); // Close standard error (current terminal)
        
        dup(slave_fd); // PTY becomes standard input (0)
        dup(slave_fd); // PTY becomes standard output (1)
        dup(slave_fd); // PTY becomes standard error (2)
        
        
//        chdir(_work_dir);
        chdir("/Users/migun/");        
//        setenv("PWD", "/Users/migun/", 1);
        
        // putenv is a bit better than setenv in terms of performance(no mallocs), so try to use it wisely
        
        // basic terminal environment setup
        putenv ((char *) "TERM=xterm-16color");
        putenv ((char *) "TERM_PROGRAM=Files.app");
        
        // need real config here
        setenv("LANG"  , locenc, 1);
        setenv("LC_ALL", locenc, 1);
        // we possibly need to also set LC_COLLATE, LC_CTYPE, LC_MESSAGES, LC_MONETARY, LC_NUMERIC and LC_TIME.
        
        // setup piping for CWD prompt
        // using FD g_PromptPipe becuse bash is closing fds [3,20) upon opening in logon mode (our case)
//        rc = dup2(m_CwdPipe[1], g_PromptPipe);
//        assert(rc == g_PromptPipe);
        
        // set bash prompt so it will report only when executed by original fork (to exclude execution by it's later forks)
//        char bash_prompt[1024];
//        sprintf(bash_prompt, g_PromptStringPID, (int)getpid());
//        setenv("PROMPT_COMMAND", bash_prompt, 1);
        
        // say BASH to not put into history any command starting with space character
//        putenv((char *)"HISTCONTROL=ignorespace");
        
        // close all file descriptors except [0], [1], [2] and [g_PromptPipe]
        // implicitly closing m_MasterFD and slave_fd
        // A BAD, BAAAD implementation - it tries to close ANY possible file descriptor for this process
        // consider a better way here
        int max_fd = (int)sysconf(_SC_OPEN_MAX);
        for(int fd = 3; fd < max_fd; fd++)
            close(fd);

        // find out binary name to put as argv[0]
        const char *img_name = strrchr(_full_binary_path, '/');
        if(img_name)
            img_name++;
        else
            img_name = _full_binary_path;
        
        // split _params into an array of argv[1], argv[2] etc
        vector<string> args = SplitArgs(_params);
        char **argvs = (char**) malloc(sizeof(char*) * (args.size() + 2));
        argvs[0] = strdup(img_name);
        for(int i = 0; i < args.size(); ++i)
            argvs[i+1] = strdup(args[i].c_str());
        argvs[args.size()+1] = NULL;
        
        // execution of the program
        execv(_full_binary_path, argvs);
        
        // we never get here in normal condition
        exit(1);
    }
    
    
}

void TermSingleTask::WriteChildInput(const void *_d, int _sz)
{
    if(_sz <= 0)
        return;
    
    m_Lock.lock();
    write(m_MasterFD, _d, _sz);
    m_Lock.unlock();
}

void TermSingleTask::ReadChildOutput()
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
        
        FD_ZERO(&fd_err);
        FD_SET(m_MasterFD, &fd_err);
        
        int max_fd = m_MasterFD;
        
        rc = select(max_fd + 1, &fd_in, NULL, &fd_err, NULL);
        if(rc < 0 || m_TaskPID < 0)
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
                if(m_OnChildOutput/* && !m_TemporarySuppressed*/)
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
        
        // check if child process died
        if(FD_ISSET(m_MasterFD, &fd_err))
        {
/*            rc = (int)read(m_MasterFD, input, input_sz);
            if(rc > 0)
            {
                int a = 10;
                
                
            }*/
//            ShellDied();
            rc = (int)read(m_MasterFD, input, input_sz);
//            rc = (int)read(m_MasterFD, tmp, 255);
/*            if(rc >= 0)
            {
                tmp[rc] = 0;
                printf("%s\n", tmp);
            }*/
            
            
            
            goto end_of_all;
        }
    } // End while
end_of_all:
//    NSLog(@"died.\n");

    if(m_OnChildDied)
        m_OnChildDied();
}

void TermSingleTask::EscapeSpaces(char *_buf)
{
    size_t sz = strlen(_buf);
    for(size_t i = 0; i < sz; ++i)
        if(_buf[i] == ' ')
        {
            memmove(_buf + i + 1, _buf + i, sz - i + 1);
            _buf[i] = '\\';
            ++sz;
            ++i;
        }
}

void TermSingleTask::ResizeWindow(int _sx, int _sy)
{
    if(m_TermSX == _sx && m_TermSY == _sy)
        return;
    
    m_TermSX = _sx;
    m_TermSY = _sy;
    
//    if(m_State != StateInactive && m_State != StateDead)
    TermTask::SetTermWindow(m_MasterFD, _sx, _sy);
}
