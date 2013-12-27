//
//  VFSPSHost.mm
//  Files
//
//  Created by Michael G. Kazakov on 26.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <vector>
#import <libproc.h>
#import <sys/sysctl.h>
#import <stdio.h>
#import <stdlib.h>
#import "sysinfo.h"

#import "VFSPSHost.h"
#import "VFSPSInternal.h"
#import "VFSPSListing.h"

using namespace std;

const char *VFSPSHost::Tag = "psfs";

VFSPSHost::VFSPSHost():
    VFSHost("", shared_ptr<VFSHost>(0)),
    m_UpdateQ(make_shared<SerialQueueT>("info.filesmanager.VFSPSHost"))
{
    CommitProcs(GetProcs());
}

VFSPSHost::~VFSPSHost()
{
    m_UpdateQ->Stop();
}

const char *VFSPSHost::FSTag() const
{
    return Tag;
}

vector<VFSPSHost::ProcInfo> VFSPSHost::GetProcs()
{
    size_t proc_cnt = 0;
    kinfo_proc *proc_list = 0;
    sysinfo::GetBSDProcessList(&proc_list, &proc_cnt);
    
    vector<ProcInfo> procs;
    for(int kip_i = 0; kip_i < proc_cnt; ++kip_i)
    {
        const kinfo_proc &kip = proc_list[kip_i];
        
        ProcInfo curr;
        curr.pid = kip.kp_proc.p_pid;
        curr.ppid = kip.kp_eproc.e_ppid;
        curr.gid = kip.kp_eproc.e_pgid;
        
        char pidpath[1024] = {0};
        proc_pidpath(curr.pid, pidpath, sizeof(pidpath));
        
        curr.bin_path = pidpath;
        
        if(const char *s = strrchr(pidpath, '/'))
            curr.name = s+1;
        else
            curr.name = kip.kp_proc.p_comm;
        
        
        procs.push_back(curr);
    }
    
    free(proc_list);
    
    return move(procs);
}

void VFSPSHost::UpdateCycle()
{
    auto shared_this = SharedPtr();
    m_UpdateQ->Run(^(SerialQueue _q){
        if(_q->IsStopped())
            return;

        auto procs = GetProcs();
        if(!_q->IsStopped())
        {
            shared_this->CommitProcs(move(procs));
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2000000000 /* 2 sec*/), dispatch_get_main_queue(), ^{
                shared_this->UpdateCycle();
            });
        }
    });
}

void VFSPSHost::CommitProcs(vector<ProcInfo> _procs)
{
    auto newdata = make_shared<Snapshot>();
    
    newdata->taken_time = [[NSDate date] timeIntervalSince1970];
    newdata->procs = _procs;
    
    for(auto &i: newdata->procs)
    {
        newdata->files.push_back(ProcInfoIntoFile(i));
        newdata->plain_filenames.push_back( /*string("/") + */to_string(i.pid) + " - " + i.name );
    }
    
    m_Data = newdata;
}

string VFSPSHost::ProcInfoIntoFile(const ProcInfo& _info)
{
    return string("name: ") + _info.name + "\nbinary: " + _info.bin_path;
}

int VFSPSHost::FetchDirectoryListing(const char *_path,
                                  shared_ptr<VFSListing> *_target,
                                  int _flags,
                                  bool (^_cancel_checker)())
{
    if(!_path || strcmp(_path, "/") != 0)
        return VFSError::NotFound;
    
    *_target = make_shared<VFSPSListing>(_path, SharedPtr(), m_Data);

    return VFSError::Ok;
}
