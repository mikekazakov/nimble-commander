// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <libproc.h>
#import <sys/sysctl.h>

#import "Host.h"

namespace nc::vfs {

struct PSHost::ProcInfo
{
    // process id
    pid_t	pid;
    
    // process group id
    pid_t	gid;
    
    // process parent id
    pid_t	ppid;
    
    uid_t   p_uid; // process uid;
    uid_t   c_uid; // current (effective) uid;
    
    string  name;
    
    // path to running binary
    string bin_path;
    
    // arguments to binary if available
    string arguments;
    
    time_t start_time;
    
    // is this process sandboxed
    bool    sandboxed = false;
    
    int    status;
    
    int     priority;
    int     nice;
    int     cpu_type; // refer /mach/machine.h
    
    struct rusage_info_v2 rusage; // cool stuff from proc_pid_rusage
    bool rusage_avail;
};

struct PSHost::Snapshot
{
    time_t                  taken_time;
    vector<ProcInfo>        procs;

    map<pid_t, unsigned>    pid_to_index;
    
    // content itself
    vector<string>          files;
    
    // like "75 - KernelEventAgent.txt"
    vector<string>          plain_filenames;
};

}
