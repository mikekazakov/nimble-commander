// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <libproc.h>
#include <sys/sysctl.h>
#include <map>
#include "Host.h"

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
    
    std::string  name;
    
    // path to running binary
    std::string bin_path;
    
    // arguments to binary if available
    std::string arguments;
    
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
    time_t                      taken_time;
    std::vector<ProcInfo>       procs;

    std::map<pid_t, unsigned>   pid_to_index;
    
    // content itself
    std::vector<std::string>    files;
    
    // like "75 - KernelEventAgent.txt"
    std::vector<std::string>    plain_filenames;
};

}
