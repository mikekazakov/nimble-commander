//
//  VFSPSInternal.h
//  Files
//
//  Created by Michael G. Kazakov on 26.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import <libproc.h>
#import <sys/sysctl.h>

#import "VFSPSHost.h"

struct VFSPSHost::ProcInfo
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
    
    int    status;
    
    int     priority;
    int     nice;
    int     cpu_type; // refer /mach/machine.h
    
    struct rusage_info_v2 rusage; // cool stuff from proc_pid_rusage
    bool rusage_avail;
};

struct VFSPSHost::Snapshot
{
    time_t                  taken_time;
    vector<ProcInfo>        procs;

    map<pid_t, unsigned>    pid_to_index;
    
    // content itself
    vector<string>          files;
    
    // like "75 - KernelEventAgent.txt"
    vector<string>          plain_filenames;
};
