// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
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
#include <signal.h>
#include <Habanero/dispatch_cpp.h>

#include "SingleTask.h"

namespace nc::term {

static std::vector<std::string> SplitArgs(const char *_args)
{
    std::vector<std::string> vec;
    
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

static const char *ImgNameFromPath(const char *_path)
{
    const char *img_name = strrchr(_path, '/');
    if(img_name)
        img_name++;
    else
        img_name = _path;
    return img_name;
}

SingleTask::SingleTask()
{
}

SingleTask::~SingleTask()
{
    CleanUp();
}

void SingleTask::Launch(const char *_full_binary_path, const char *_params, int _sx, int _sy)
{
    m_TermSX = _sx;
    m_TermSY = _sy;
    
    // user's home dir to set as cwd
    struct passwd *pw = getpwuid(getuid());
    
    // find out binary name to put as argv[0]
    const char *img_name = ImgNameFromPath(_full_binary_path);
    m_TaskBinaryName = img_name;
    
    // remember current locale and stuff
    auto env = BuildEnv();
    
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
        
        // TODO: consider using single shared thread here, not a queue (mind maximum running queues issue)
        dispatch_async(dispatch_get_global_queue(0, 0), [=]{
            ReadChildOutput();
        });
    }
    else
    { // slave/child
        SetupTermios(slave_fd);
        SetTermWindow(slave_fd, _sx, _sy);
        SetupHandlesAndSID(slave_fd);
        
        
        // where should CWD be? let it be in home dir
        if(pw)
            chdir(pw->pw_dir);

        // put basic environment stuff
        SetEnv(env);

        // closing any used file descriptors
        CloseAllFDAbove3();
        
        // split _params into an array of argv[1], argv[2] etc
        std::vector<std::string> args = SplitArgs(_params);
        char **argvs = (char**) malloc(sizeof(char*) * (args.size() + 2));
        argvs[0] = strdup(img_name);
        for(size_t i = 0; i < args.size(); ++i)
            argvs[i+1] = strdup(args[i].c_str());
        argvs[args.size()+1] = NULL;
        
        // execution of the program
        execvp(_full_binary_path, argvs);
        
        // we never get here in normal condition
        exit(1);
    }
}

void SingleTask::WriteChildInput(const void *_d, size_t _sz)
{
    if(m_MasterFD < 0 || m_TaskPID < 0 || _sz == 0)
        return;
    
    std::lock_guard<std::mutex> lock(m_Lock);
    write(m_MasterFD, _d, _sz);
}

void SingleTask::ReadChildOutput()
{
    int rc;
    fd_set fd_in, fd_err;
    
    // just for cases when select() don't catch child death - we force to ask it for every 2 seconds
    struct timeval timeout = {2, 0};
    
    static const int input_sz = 65536;
    char input[65536];
    
    while(1)
    {
        // Wait for data from standard input and master side of PTY
        FD_ZERO(&fd_in);
        FD_SET(m_MasterFD, &fd_in);
        
        FD_ZERO(&fd_err);
        FD_SET(m_MasterFD, &fd_err);
        
        int max_fd = m_MasterFD;
        
        rc = select(max_fd + 1, &fd_in, NULL, &fd_err, &timeout);
        if(rc < 0 || m_TaskPID < 0)
            goto end_of_all; // error on select(), let's think that task has died

        // If data on master side of PTY (some child's output)
        if(FD_ISSET(m_MasterFD, &fd_in)) {
            rc = (int)read(m_MasterFD, input, input_sz);
            if (rc > 0) {
                DoCalloutOnChildOutput(input, rc);
            }
            else if(rc < 0) {
                std::cerr << "Error " << errno << " on read master PTY" << std::endl;
                goto end_of_all;
            }
        }
        
        // check if child process died
        if(FD_ISSET(m_MasterFD, &fd_err))
        {
            // is that right - that we treat any err output as signal that task is dead?
            read(m_MasterFD, input, input_sz);
            goto end_of_all;
        }
    }
end_of_all:

    if( m_OnChildDied != nullptr )
        m_OnChildDied();
    CleanUp();
}

void SingleTask::EscapeSpaces(char *_buf)
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

void SingleTask::ResizeWindow(int _sx, int _sy)
{
    if(m_MasterFD < 0 || m_TaskPID < 0)
        return;
    
    if(m_TermSX == _sx && m_TermSY == _sy)
        return;
    
    std::lock_guard<std::mutex> lock(m_Lock);
    
    m_TermSX = _sx;
    m_TermSY = _sy;
    
    SetTermWindow(m_MasterFD, _sx, _sy);
}

void SingleTask::CleanUp()
{
    std::lock_guard<std::mutex> lock(m_Lock);
    
    if(m_TaskPID > 0)
    {
        int pid = m_TaskPID;
        m_TaskPID = -1;
        kill(pid, SIGKILL);
        
        // possible and very bad workaround for sometimes appearing ZOMBIE BASHes
        struct timespec tm, tm2;
        tm.tv_sec  = 0;
        tm.tv_nsec = 10000000L; // 10 ms
        nanosleep(&tm, &tm2);
        
        int status;
        waitpid(pid, &status, 0);
    }
    
    if(m_MasterFD >= 0)
    {
        close(m_MasterFD);
        m_MasterFD = -1;
    }
}

}
