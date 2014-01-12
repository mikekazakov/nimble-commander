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
#import <sys/resource.h>
#import <pwd.h>
#import <stdio.h>
#import <stdlib.h>
#import "sysinfo.h"
#import "Common.h"
#import "VFSPSHost.h"
#import "VFSPSInternal.h"
#import "VFSPSListing.h"
#import "VFSPSFile.h"

using namespace std;

const char *VFSPSHost::Tag = "psfs";

static NSDateFormatter *ProcDateFormatter()
{
    static NSDateFormatter *formatter = nil;
    if(formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
        [formatter setDateStyle:NSDateFormatterShortStyle];
    }
    return formatter;
}

static const string& ProcStatus(int _st)
{
    static const string strings[] = {
        "",
        "SIDL (process being created by fork)",
        "SRUN (currently runnable)",
        "SSLEEP (sleeping on an address)",
        "SSTOP (process debugging or suspension)",
        "SZOMB (awaiting collection by parent)"
    };
    if(_st >= 0 && _st <= SZOMB)
        return strings[_st];
    return strings[0];
}

static cpu_type_t ArchTypeFromPID(pid_t _pid)
{
    int err;
    cpu_type_t  cpuType;
    size_t      cpuTypeSize;
    int         mib[CTL_MAXNAME];
    size_t      mibLen;
    mibLen  = CTL_MAXNAME;
    err = sysctlnametomib("sysctl.proc_cputype", mib, &mibLen);
    if (err == -1)
        return 0;

    if (err == 0)
    {
        assert(mibLen < CTL_MAXNAME);
        mib[mibLen] = _pid;
        mibLen += 1;
        
        cpuTypeSize = sizeof(cpuType);
        err = sysctl(mib, (unsigned)mibLen, &cpuType, &cpuTypeSize, 0, 0);
        if (err == 0)
            return cpuType;
    }
    
    return 0;
}

static const string& ArchType(int _type)
{
    static string x86 = "x86";
    static string x86_64 = "x86-64";
    static string na = "N/A";
    
    if(_type == CPU_TYPE_X86_64)    return x86_64;
    else if(_type == CPU_TYPE_X86)  return x86;
    else                            return na;
}

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
    
    vector<ProcInfo> procs(proc_cnt);
    for(int kip_i = 0; kip_i < proc_cnt; ++kip_i)
    {
        const kinfo_proc &kip = proc_list[kip_i];
        
        ProcInfo curr;
        curr.pid = kip.kp_proc.p_pid;
        curr.ppid = kip.kp_eproc.e_ppid;
        curr.gid = kip.kp_eproc.e_pgid;
        curr.status = kip.kp_proc.p_stat;
        curr.start_time = kip.kp_proc.p_starttime.tv_sec;
        curr.priority = kip.kp_proc.p_priority;
        curr.nice = kip.kp_proc.p_nice;
        curr.p_uid = kip.kp_eproc.e_pcred.p_ruid;
        curr.c_uid = kip.kp_eproc.e_ucred.cr_uid;
        curr.cpu_type = ArchTypeFromPID(curr.pid);
        
        if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_9)
        {
            curr.rusage_avail = false;
            memset(&curr.rusage, 0, sizeof(curr.rusage));
            if(proc_pid_rusage(curr.pid, RUSAGE_INFO_V2, (void**)&curr.rusage) == 0)
                curr.rusage_avail = true;
        }
        
        char pidpath[1024] = {0};
        proc_pidpath(curr.pid, pidpath, sizeof(pidpath));
        curr.bin_path = pidpath;
        
        
        if(const char *s = strrchr(pidpath, '/'))
            curr.name = s+1;
        else
            curr.name = kip.kp_proc.p_comm;
        
        procs[kip_i] = curr;
    }
    
    free(proc_list);
    
    return move(procs);
}

void VFSPSHost::UpdateCycle()
{
    auto weak_this = weak_ptr<VFSPSHost>(SharedPtr());
    m_UpdateQ->Run(^(SerialQueue _q){
        if(_q->IsStopped())
            return;

        __block auto procs = GetProcs();
        if(!_q->IsStopped())
        {
            dispatch_to_main_queue(^{
                if(!weak_this.expired())
                    weak_this.lock()->CommitProcs(move(procs));
            });
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2000000000 /* 2 sec*/), dispatch_get_main_queue(), ^{
                if(!weak_this.expired())
                    weak_this.lock()->UpdateCycle();
            });
        }
    });
}

void VFSPSHost::EnsureUpdateRunning()
{
    if(m_UpdateStarted == false)
    {
        m_UpdateStarted = true;
        UpdateCycle();
    }
}

void VFSPSHost::CommitProcs(vector<ProcInfo> _procs)
{
    lock_guard<mutex> lock(m_Lock);

    auto newdata = make_shared<Snapshot>();
    
    newdata->taken_time = [[NSDate date] timeIntervalSince1970];
    newdata->procs.swap(_procs);
    newdata->files.reserve(newdata->procs.size());
    newdata->plain_filenames.reserve(newdata->procs.size());
    
    for(int i = 0; i < newdata->procs.size(); ++i)
        newdata->pid_to_index[ newdata->procs[i].pid ] = i;
    
    for(auto &i: newdata->procs)
    {
        newdata->files.push_back(ProcInfoIntoFile(i, newdata));
        newdata->plain_filenames.push_back( /*string("/") + */to_string(i.pid) + " - " + i.name + ".txt" );
    }
    
    m_Data = newdata;
    
    for(auto &i:m_UpdateHandlers)
        i.second();
}

string VFSPSHost::ProcInfoIntoFile(const ProcInfo& _info, shared_ptr<Snapshot> _data)
{
    string result;
    
    const char * parent_name = "N/A";
    {
        auto it = _data->pid_to_index.find(_info.ppid);
        if(it != end(_data->pid_to_index))
            parent_name = _data->procs[it->second].name.c_str();
    }
    
    const char *user_name = "N/A";
    if(struct passwd *pwd = getpwuid(_info.p_uid))
        user_name = pwd->pw_name;
    
    result += string("Name: ") + _info.name + "\n";
    result += string("Process id: ") + to_string(_info.pid) + "\n";
    result += string("Process group id: ") + to_string(_info.gid) + "\n";
    result += string("Process parent id: ") + to_string(_info.ppid) + " (" + parent_name + ")\n";
    result += string("Process user id: ") + to_string(_info.p_uid) + " (" + user_name + ")\n";
    result += string("Process priority: ") + to_string(_info.priority) + "\n";
    result += string("Process \"nice\" value: ") + to_string(_info.nice) + "\n";
    result += string("Started at: ") +
        [ProcDateFormatter() stringFromDate:[NSDate dateWithTimeIntervalSince1970:_info.start_time]].UTF8String +
        "\n";
    result += string("Status: ") + ProcStatus(_info.status) + "\n";
    result += string("Architecture: ") + ArchType(_info.cpu_type) + "\n";
    result += string("Image file: ") + (_info.bin_path.empty() ? "N/A" : _info.bin_path) + "\n";

    if(sysinfo::GetOSXVersion() >= sysinfo::OSXVersion::OSX_9 &&
       _info.rusage_avail)
    {
        auto bread = to_string(_info.rusage.ri_diskio_bytesread);
        auto bwritten = to_string(_info.rusage.ri_diskio_byteswritten);
        (bread.length() < bwritten.length() ? bread : bwritten).insert(0,
                                                                       max(bread.length(), bwritten.length()) -
                                                                        min(bread.length(), bwritten.length()),
                                                                       ' '); // right align
        result += string("Disk I/O bytes read:    ") + bread + "\n";
        result += string("Disk I/O bytes written: ") + bwritten + "\n";
        result += string("Memory resident size: ") +  to_string(_info.rusage.ri_resident_size) + "\n";
        result += string("Idle wake ups: ") + to_string(_info.rusage.ri_pkg_idle_wkups) + "\n";
    }
    
    return result;
}

int VFSPSHost::FetchDirectoryListing(const char *_path,
                                  shared_ptr<VFSListing> *_target,
                                  int _flags,
                                  bool (^_cancel_checker)())
{
    EnsureUpdateRunning();
    
    if(!_path || strcmp(_path, "/") != 0)
        return VFSError::NotFound;
    
    *_target = make_shared<VFSPSListing>(_path, SharedPtr(), m_Data);

    return VFSError::Ok;
}

bool VFSPSHost::IsDirectory(const char *_path,
                         int _flags,
                         bool (^_cancel_checker)())
{
    if(_path == 0 ||
       strcmp(_path, "/") != 0)
        return false;
    return true;
}

int VFSPSHost::CreateFile(const char* _path,
                       shared_ptr<VFSFile> *_target,
                       bool (^_cancel_checker)())
{
    lock_guard<mutex> lock(m_Lock);
    
    if(_path == nullptr)
        return VFSError::InvalidCall;
    
    auto index = ProcIndexFromFilepath(_path);
    
    if(index < 0)
        return VFSError::NotFound;
    
    auto file = make_shared<VFSPSFile>(_path, SharedPtr(), m_Data->files[index]);
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    *_target = file;
    return VFSError::Ok;
}

int VFSPSHost::Stat(const char *_path, struct stat &_st, int _flags, bool (^_cancel_checker)())
{
    lock_guard<mutex> lock(m_Lock);
    
    if(_path == nullptr)
        return VFSError::InvalidCall;
    
    auto index = ProcIndexFromFilepath(_path);
    
    if(index < 0)
        return VFSError::NotFound;
    
    memset(&_st, 0, sizeof(_st));
    _st.st_size = m_Data->files[index].length();
    _st.st_mode = S_IFREG | S_IRUSR | S_IRGRP;
    _st.st_mtimespec.tv_sec = m_Data->taken_time;
    _st.st_atimespec.tv_sec = m_Data->taken_time;
    _st.st_ctimespec.tv_sec = m_Data->taken_time;
    _st.st_birthtimespec.tv_sec = m_Data->taken_time;

    return VFSError::Ok;
}

int VFSPSHost::ProcIndexFromFilepath(const char *_filepath)
{
    if(_filepath == nullptr)
        return -1;
    
    if(_filepath[0] != '/')
        return -1;
    
    auto plain_fn = _filepath + 1;
    
    auto it = find(begin(m_Data->plain_filenames),
                   end(m_Data->plain_filenames),
                   plain_fn);
    if(it == end(m_Data->plain_filenames))
        return -1;
    
    return int(it - begin(m_Data->plain_filenames));
}

unsigned long VFSPSHost::DirChangeObserve(const char *_path, void (^_handler)())
{
    // currently we don't care about _path, since this fs has only one directory - root
    auto ticket = m_LastTicket++;
    m_UpdateHandlers.emplace_back(ticket, _handler);
    return ticket;
}

void VFSPSHost::StopDirChangeObserving(unsigned long _ticket)
{
    auto it = find_if(begin(m_UpdateHandlers),
                      end(m_UpdateHandlers),
                      [=](pair<unsigned long, void (^)()> &i){ return i.first == _ticket; } );
    if(it != end(m_UpdateHandlers))
        m_UpdateHandlers.erase(it);
}
