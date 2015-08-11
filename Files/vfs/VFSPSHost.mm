//
//  VFSPSHost.mm
//  Files
//
//  Created by Michael G. Kazakov on 26.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#define __APPLE_API_PRIVATE
#import "../3rd_party/apple_sandbox.h"
#import <libproc.h>
#import <sys/sysctl.h>
#import <sys/resource.h>
#import <sys/proc_info.h>
#import <pwd.h>
#import <stdio.h>
#import <stdlib.h>
#import "sysinfo.h"
#import "Common.h"
#import "VFSPSHost.h"
#import "VFSPSInternal.h"
#import "VFSPSListing.h"
#import "VFSPSFile.h"

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
    static const string x86 = "x86";
    static const string x86_64 = "x86-64";
    static const string na = "N/A";
    
    if(_type == CPU_TYPE_X86_64)    return x86_64;
    else if(_type == CPU_TYPE_X86)  return x86;
    else                            return na;
}

// from https://gist.github.com/nonowarn/770696
static void print_argv_of_pid(int pid, string &_out)
{
    int    mib[3], argmax, nargs, c = 0;
    size_t    size;
    char    *procargs, *sp, *np, *cp;
    int show_args = 1;
    
//    fprintf(stderr, "Getting argv of PID %d\n", pid);
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_ARGMAX;
    
    size = sizeof(argmax);
    if (sysctl(mib, 2, &argmax, &size, NULL, 0) == -1) {
        goto ERROR_A;
    }
    
    /* Allocate space for the arguments. */
    procargs = (char *)malloc(argmax);
    if (procargs == NULL) {
        goto ERROR_A;
    }
    
    
    /*
     * Make a sysctl() call to get the raw argument space of the process.
     * The layout is documented in start.s, which is part of the Csu
     * project.  In summary, it looks like:
     *
     * /---------------\ 0x00000000
     * :               :
     * :               :
     * |---------------|
     * | argc          |
     * |---------------|
     * | arg[0]        |
     * |---------------|
     * :               :
     * :               :
     * |---------------|
     * | arg[argc - 1] |
     * |---------------|
     * | 0             |
     * |---------------|
     * | env[0]        |
     * |---------------|
     * :               :
     * :               :
     * |---------------|
     * | env[n]        |
     * |---------------|
     * | 0             |
     * |---------------| <-- Beginning of data returned by sysctl() is here.
     * | argc          |
     * |---------------|
     * | exec_path     |
     * |:::::::::::::::|
     * |               |
     * | String area.  |
     * |               |
     * |---------------| <-- Top of stack.
     * :               :
     * :               :
     * \---------------/ 0xffffffff
     */
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROCARGS2;
    mib[2] = pid;
    
    
    size = (size_t)argmax;
    if (sysctl(mib, 3, procargs, &size, NULL, 0) == -1) {
        goto ERROR_B;
    }
    
    memcpy(&nargs, procargs, sizeof(nargs));
    cp = procargs + sizeof(nargs);
    
    /* Skip the saved exec_path. */
    for (; cp < &procargs[size]; cp++) {
        if (*cp == '\0') {
            /* End of exec_path reached. */
            break;
        }
    }
    if (cp == &procargs[size]) {
        goto ERROR_B;
    }
    
    /* Skip trailing '\0' characters. */
    for (; cp < &procargs[size]; cp++) {
        if (*cp != '\0') {
            /* Beginning of first argument reached. */
            break;
        }
    }
    if (cp == &procargs[size]) {
        goto ERROR_B;
    }
    /* Save where the argv[0] string starts. */
    sp = cp;
    
    /*
     * Iterate through the '\0'-terminated strings and convert '\0' to ' '
     * until a string is found that has a '=' character in it (or there are
     * no more strings in procargs).  There is no way to deterministically
     * know where the command arguments end and the environment strings
     * start, which is why the '=' character is searched for as a heuristic.
     */
    for (np = NULL; c < nargs && cp < &procargs[size]; cp++) {
        if (*cp == '\0') {
            c++;
            if (np != NULL) {
                /* Convert previous '\0'. */
                *np = ' ';
            } else {
                /* *argv0len = cp - sp; */
            }
            /* Note location of current '\0'. */
            np = cp;
            
            if (!show_args) {
                /*
                 * Don't convert '\0' characters to ' '.
                 * However, we needed to know that the
                 * command name was terminated, which we
                 * now know.
                 */
                break;
            }
        }
    }
    
    /*
     * sp points to the beginning of the arguments/environment string, and
     * np should point to the '\0' terminator for the string.
     */
    if (np == NULL || np == sp) {
        /* Empty or unterminated string. */
        goto ERROR_B;
    }
    
    /* Make a copy of the string. */
//    printf("%s\n", sp);
    _out = sp;
    
    /* Clean up. */
    free(procargs);
    return;
    
ERROR_B:
    free(procargs);
ERROR_A:;
}

class VFSPSHostConfiguration
{
public:
    const char *Tag() const
    {
        return VFSPSHost::Tag;
    }
    
    const char *Junction() const
    {
        return "";
    }
    
    bool operator==(const VFSPSHostConfiguration&) const
    {
        return true;
    }
};


VFSPSHost::VFSPSHost():
    VFSHost("", shared_ptr<VFSHost>(0)),
    m_UpdateQ(make_shared<SerialQueueT>(__FILES_IDENTIFIER__".VFSPSHost"))
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

VFSConfiguration VFSPSHost::Configuration() const
{
    static auto c = VFSPSHostConfiguration();
    return c;
}

VFSMeta VFSPSHost::Meta()
{
    VFSMeta m;
    m.Tag = Tag;
    m.SpawnWithConfig = [](const VFSHostPtr &_parent, const VFSConfiguration& _config) {
        return GetSharedOrNew();
    };
    return m;
}

shared_ptr<VFSPSHost> VFSPSHost::GetSharedOrNew()
{
    static mutex mt;
    static weak_ptr<VFSPSHost> cache;
    
    lock_guard<mutex> lock(mt);
    if(auto host = cache.lock())
        return host;
    
    auto host = make_shared<VFSPSHost>();
    cache = host;
    return host;
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
        if(!configuration::is_for_app_store)
            curr.sandboxed = sandbox_check(curr.pid, NULL, SANDBOX_FILTER_NONE) != 0;
        
        curr.rusage_avail = false;
        memset(&curr.rusage, 0, sizeof(curr.rusage));
        if(proc_pid_rusage(curr.pid, RUSAGE_INFO_V2, (void**)&curr.rusage) == 0)
            curr.rusage_avail = true;
        
        char pidpath[1024] = {0};
        proc_pidpath(curr.pid, pidpath, sizeof(pidpath));
        curr.bin_path = pidpath;
        
        
        if(const char *s = strrchr(pidpath, '/'))
            curr.name = s+1;
        else
            curr.name = kip.kp_proc.p_comm;
        
        print_argv_of_pid(curr.pid, curr.arguments);
        
        procs[kip_i] = curr;
    }
    
    free(proc_list);
    
    return move(procs);
}

void VFSPSHost::UpdateCycle()
{
    auto weak_this = weak_ptr<VFSPSHost>(SharedPtr());
    m_UpdateQ->Run([=](auto _q){
        if(_q->IsStopped())
            return;

        auto procs = GetProcs();
        if(!_q->IsStopped())
        {
            auto me = weak_this;
            dispatch_to_main_queue([=,procs=move(procs)]{
                if(!me.expired())
                    me.lock()->CommitProcs(move(procs));
            });
            
            dispatch_to_main_queue_after(2s, [=]{
                if(!me.expired())
                    me.lock()->UpdateCycle();
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
        char filename[MAXPATHLEN];
        sprintf(filename, "%5i - %s.txt", i.pid, i.name.c_str());
        newdata->plain_filenames.emplace_back(filename);
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
    
    result += "Name: "s + _info.name + "\n";
    result += "Process id: "s + to_string(_info.pid) + "\n";
    result += "Process group id: "s + to_string(_info.gid) + "\n";
    result += "Process parent id: "s + to_string(_info.ppid) + " (" + parent_name + ")\n";
    result += "Process user id: "s + to_string(_info.p_uid) + " (" + user_name + ")\n";
    result += "Process priority: "s + to_string(_info.priority) + "\n";
    result += "Process \"nice\" value: "s + to_string(_info.nice) + "\n";
    result += "Started at: "s +
        [ProcDateFormatter() stringFromDate:[NSDate dateWithTimeIntervalSince1970:_info.start_time]].UTF8String +
        "\n";
    result += "Status: "s + ProcStatus(_info.status) + "\n";
    result += "Architecture: "s + ArchType(_info.cpu_type) + "\n";
    if(!configuration::is_for_app_store)
        result += "Sandboxed: "s + (_info.sandboxed ? "yes" : "no") + "\n";
    result += "Image file: "s + (_info.bin_path.empty() ? "N/A" : _info.bin_path) + "\n";
    result += "Arguments: "s + (_info.arguments.empty() ? "N/A" : _info.arguments) + "\n";
    
    if( _info.rusage_avail )
    {
        auto bread = to_string(_info.rusage.ri_diskio_bytesread);
        auto bwritten = to_string(_info.rusage.ri_diskio_byteswritten);
        (bread.length() < bwritten.length() ? bread : bwritten).insert(0,
                                                                       max(bread.length(), bwritten.length()) -
                                                                        min(bread.length(), bwritten.length()),
                                                                       ' '); // right align
        result += "Disk I/O bytes read:    "s + bread + "\n";
        result += "Disk I/O bytes written: "s + bwritten + "\n";
        result += "Memory resident size: "s +  to_string(_info.rusage.ri_resident_size) + "\n";
        result += "Idle wake ups: "s + to_string(_info.rusage.ri_pkg_idle_wkups) + "\n";
    }
    
    return result;
}

int VFSPSHost::FetchDirectoryListing(const char *_path,
                                  unique_ptr<VFSListing> &_target,
                                  int _flags,
                                  VFSCancelChecker _cancel_checker)
{
    EnsureUpdateRunning();
    
    if(!_path || strcmp(_path, "/") != 0)
        return VFSError::NotFound;
    
    _target = make_unique<VFSPSListing>(_path, SharedPtr(), m_Data);

    return VFSError::Ok;
}

bool VFSPSHost::IsDirectory(const char *_path,
                         int _flags,
                         VFSCancelChecker _cancel_checker)
{
    if(_path == 0 ||
       strcmp(_path, "/") != 0)
        return false;
    return true;
}

int VFSPSHost::CreateFile(const char* _path,
                       shared_ptr<VFSFile> &_target,
                       VFSCancelChecker _cancel_checker)
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
    _target = file;
    return VFSError::Ok;
}

int VFSPSHost::Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker)
{
    static VFSStat::meaningT m;
    static once_flag once;
    call_once(once, []{
        memset(&m, sizeof(m), 0);
        m.size = 1;
        m.mode = 1;
        m.mtime = 1;
        m.atime = 1;
        m.ctime = 1;
        m.btime = 1;
    });
    
    lock_guard<mutex> lock(m_Lock);
    
    if(_path == nullptr)
        return VFSError::InvalidCall;
    
    auto index = ProcIndexFromFilepath(_path);
    
    if(index < 0)
        return VFSError::NotFound;
    
    memset(&_st, 0, sizeof(_st));
    _st.size = m_Data->files[index].length();
    _st.mode = S_IFREG | S_IRUSR | S_IRGRP;
    _st.mtime.tv_sec = m_Data->taken_time;
    _st.atime.tv_sec = m_Data->taken_time;
    _st.ctime.tv_sec = m_Data->taken_time;
    _st.btime.tv_sec = m_Data->taken_time;
    _st.meaning = m;
    
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

bool VFSPSHost::IsDirChangeObservingAvailable(const char *_path)
{
    return true;
}

VFSHostDirObservationTicket VFSPSHost::DirChangeObserve(const char *_path, function<void()> _handler)
{
    // currently we don't care about _path, since this fs has only one directory - root
    auto ticket = m_LastTicket++;
    m_UpdateHandlers.emplace_back(ticket, _handler);
    return VFSHostDirObservationTicket(ticket, shared_from_this());
}

void VFSPSHost::StopDirChangeObserving(unsigned long _ticket)
{
    auto it = find_if(begin(m_UpdateHandlers),
                      end(m_UpdateHandlers),
                      [=](const auto &i){ return i.first == _ticket; } );
    if(it != end(m_UpdateHandlers))
        m_UpdateHandlers.erase(it);
}

int VFSPSHost::IterateDirectoryListing(const char *_path, function<bool(const VFSDirEnt &_dirent)> _handler)
{
    assert(_path != 0);
    if(_path[0] != '/' || _path[1] != 0)
        return VFSError::NotFound;
    
    char buf[1024];
    strcpy(buf, _path);

    m_Lock.lock();
    auto snapshot = m_Data;
    m_Lock.unlock();
        
    for(auto &i: snapshot->plain_filenames)
    {
        VFSDirEnt dir;
        strcpy(dir.name, i.c_str());
        dir.name_len = i.size();
        dir.type = VFSDirEnt::Reg;
        
        if(!_handler(dir))
            break;
    }
    
    return VFSError::Ok;
}

string VFSPSHost::VerboseJunctionPath() const
{
    return "[psfs]:";
}

int VFSPSHost::StatFS(const char *_path, VFSStatFS &_stat, VFSCancelChecker _cancel_checker)
{
    _stat.volume_name = "Processes List";
    _stat.avail_bytes = _stat.free_bytes = 0;
    
    lock_guard<mutex> lock(m_Lock);
    int total_size = 0;
    for_each( begin(m_Data->files), end(m_Data->files), [&](auto &i){ total_size += i.length(); } );
    _stat.total_bytes = total_size;
    return 0;
}

bool VFSPSHost::ShouldProduceThumbnails() const
{
    return false;
}
