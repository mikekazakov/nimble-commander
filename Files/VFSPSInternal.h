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
    
    string  name;
    
    // path to running binary
    string bin_path;
    
    
};


struct VFSPSHost::Snapshot
{
    vector<ProcInfo> procs;
    vector<string>   files;
    
    vector<string>   plain_filenames;
};
