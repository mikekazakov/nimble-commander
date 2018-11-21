// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <libproc.h>
#include <sys/resource.h>
#include <sys/proc_info.h>
#include <pwd.h>
#include <Utility/SystemInformation.h>
#include <RoutedIO/RoutedIO.h>
#include "../ListingInput.h"
#include "Host.h"
#include "Internal.h"
#include "File.h"

namespace nc::vfs {
    using namespace std::literals;
    
const char *PSHost::UniqueTag = "psfs";

static NSDateFormatter *ProcDateFormatter()
{
    static NSDateFormatter *formatter = nil;
    std::once_flag flag;
    call_once(flag, []{
        auto fmt = [[NSDateFormatter alloc] init];
        [fmt setTimeStyle:NSDateFormatterShortStyle];
        [fmt setDateStyle:NSDateFormatterShortStyle];
        formatter = fmt;
    });
    return formatter;
}

static const std::string& ProcStatus(int _st)
{
    static const std::string strings[] = {
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

static const std::string& ArchType(int _type)
{
    static const std::string x86 = "x86";
    static const std::string x86_64 = "x86-64";
    static const std::string na = "N/A";
    
    if(_type == CPU_TYPE_X86_64)    return x86_64;
    else if(_type == CPU_TYPE_X86)  return x86;
    else                            return na;
}

// from https://gist.github.com/nonowarn/770696
static void print_argv_of_pid(int pid, std::string &_out)
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
        return PSHost::UniqueTag;
    }
    
    const char *Junction() const
    {
        return "";
    }
    
    bool operator==(const VFSPSHostConfiguration&) const
    {
        return true;
    }
    
    const char *VerboseJunction() const
    {
        return "[psfs]:";
    }
};

PSHost::PSHost():
    Host("", std::shared_ptr<Host>(0), UniqueTag),
    m_UpdateQ("PSHost")
{
    CommitProcs(GetProcs());
}

PSHost::~PSHost()
{
//    m_UpdateQ->Stop();
}

VFSConfiguration PSHost::Configuration() const
{
    static auto c = VFSPSHostConfiguration();
    return c;
}

VFSMeta PSHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = [](const VFSHostPtr &_parent, const VFSConfiguration& _config, VFSCancelChecker _cancel_checker) {
        return GetSharedOrNew();
    };
    return m;
}

std::shared_ptr<PSHost> PSHost::GetSharedOrNew()
{
    static std::mutex mt;
    static std::weak_ptr<PSHost> cache;
    
    std::lock_guard<std::mutex> lock(mt);
    if(auto host = cache.lock())
        return host;
    
    auto host = std::make_shared<PSHost>();
    cache = host;
    return host;
}

std::vector<PSHost::ProcInfo> PSHost::GetProcs()
{
    size_t proc_cnt = 0;
    kinfo_proc *proc_list = 0;
    nc::utility::GetBSDProcessList(&proc_list, &proc_cnt);
    
    std::vector<ProcInfo> procs(proc_cnt);
    for( size_t kip_i = 0; kip_i < proc_cnt; ++kip_i ) {
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
//        if( !ActivationManager::ForAppStore() )
//            curr.sandboxed = sandbox_check(curr.pid, NULL, SANDBOX_FILTER_NONE) != 0;
        
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
    
    return procs;
}

void PSHost::UpdateCycle()
{
    auto weak_this = std::weak_ptr<PSHost>(SharedPtr());
    m_UpdateQ.Run([=]{
        if(m_UpdateQ.IsStopped())
            return;

        auto procs = GetProcs();
        if(!m_UpdateQ.IsStopped())
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

void PSHost::EnsureUpdateRunning()
{
    if(m_UpdateStarted == false)
    {
        m_UpdateStarted = true;
        UpdateCycle();
    }
}

void PSHost::CommitProcs(std::vector<ProcInfo> _procs)
{
    std::lock_guard<std::mutex> lock(m_Lock);

    auto newdata = std::make_shared<Snapshot>();
    
    newdata->taken_time = time_t(NSDate.date.timeIntervalSince1970);
    newdata->procs.swap(_procs);
    newdata->files.reserve(newdata->procs.size());
    newdata->plain_filenames.reserve(newdata->procs.size());
    
    for(unsigned i = 0; i < (unsigned)newdata->procs.size(); ++i)
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

std::string PSHost::ProcInfoIntoFile(const ProcInfo& _info, std::shared_ptr<Snapshot> _data)
{
    using std::to_string;
    std::string result;
    
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
//    if( !ActivationManager::ForAppStore() )
//        result += "Sandboxed: "s + (_info.sandboxed ? "yes" : "no") + "\n";
    result += "Image file: "s + (_info.bin_path.empty() ? "N/A" : _info.bin_path) + "\n";
    result += "Arguments: "s + (_info.arguments.empty() ? "N/A" : _info.arguments) + "\n";
    
    if( _info.rusage_avail )
    {
        auto bread = to_string(_info.rusage.ri_diskio_bytesread);
        auto bwritten = to_string(_info.rusage.ri_diskio_byteswritten);
        (bread.length() < bwritten.length() ? bread : bwritten).insert(0,
                                                                       std::max(bread.length(), bwritten.length()) -
                                                                        std::min(bread.length(), bwritten.length()),
                                                                       ' '); // right align
        result += "Disk I/O bytes read:    "s + bread + "\n";
        result += "Disk I/O bytes written: "s + bwritten + "\n";
        result += "Memory resident size: "s +  to_string(_info.rusage.ri_resident_size) + "\n";
        result += "Idle wake ups: "s + to_string(_info.rusage.ri_pkg_idle_wkups) + "\n";
    }
    
    return result;
}

int PSHost::FetchDirectoryListing(const char *_path,
                                     std::shared_ptr<VFSListing> &_target,
                                     unsigned long _flags,
                                     const VFSCancelChecker &_cancel_checker)
{
    EnsureUpdateRunning();
    
    if(!_path || strcmp(_path, "/") != 0)
        return VFSError::NotFound;
    
    auto data = m_Data;
    
    // set up or listing structure
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = _path;
    listing_source.sizes.reset( variable_container<>::type::dense );
    listing_source.atimes.reset( variable_container<>::type::common );
    listing_source.atimes[0] = data->taken_time;
    listing_source.btimes.reset( variable_container<>::type::common );
    listing_source.btimes[0] = data->taken_time;
    listing_source.ctimes.reset( variable_container<>::type::common );
    listing_source.ctimes[0] = data->taken_time;
    listing_source.mtimes.reset( variable_container<>::type::common );
    listing_source.mtimes[0] = data->taken_time;
    
    for( int index = 0, index_e = (int)data->procs.size(); index != index_e; ++index ) {
        listing_source.filenames.emplace_back( data->plain_filenames[index] );
        listing_source.unix_modes.emplace_back( S_IFREG | S_IRUSR | S_IRGRP );
        listing_source.unix_types.emplace_back( DT_REG );
        listing_source.sizes.insert( index, data->files[index].size() );
    }
    
    _target = VFSListing::Build(std::move(listing_source));
    return 0;
}

bool PSHost::IsDirectory(const char *_path,
                            unsigned long _flags,
                            const VFSCancelChecker &_cancel_checker)
{
    if(_path == 0 ||
       strcmp(_path, "/") != 0)
        return false;
    return true;
}

int PSHost::CreateFile(const char* _path,
                          std::shared_ptr<VFSFile> &_target,
                          const VFSCancelChecker &_cancel_checker)
{
    std::lock_guard<std::mutex> lock(m_Lock);
    
    if(_path == nullptr)
        return VFSError::InvalidCall;
    
    auto index = ProcIndexFromFilepath_Unlocked(_path);
    
    if(index < 0)
        return VFSError::NotFound;
    
    auto file = std::make_shared<PSFile>(_path, SharedPtr(), m_Data->files[index]);
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

int PSHost::Stat(const char *_path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker)
{
    static VFSStat::meaningT m;
    static std::once_flag once;
    call_once(once, []{
        memset(&m, sizeof(m), 0);
        m.size = 1;
        m.mode = 1;
        m.mtime = 1;
        m.atime = 1;
        m.ctime = 1;
        m.btime = 1;
    });
    
    std::lock_guard<std::mutex> lock(m_Lock);
    
    if(_path == nullptr)
        return VFSError::InvalidCall;
    
    auto index = ProcIndexFromFilepath_Unlocked(_path);
    
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

int PSHost::ProcIndexFromFilepath_Unlocked(const char *_filepath)
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

bool PSHost::IsDirChangeObservingAvailable(const char *_path)
{
    return true;
}

HostDirObservationTicket PSHost::DirChangeObserve(const char *_path, std::function<void()> _handler)
{
    // currently we don't care about _path, since this fs has only one directory - root
    auto ticket = m_LastTicket++;
    m_UpdateHandlers.emplace_back(ticket, _handler);
    return HostDirObservationTicket(ticket, shared_from_this());
}

void PSHost::StopDirChangeObserving(unsigned long _ticket)
{
    auto it = find_if(begin(m_UpdateHandlers),
                      end(m_UpdateHandlers),
                      [=](const auto &i){ return i.first == _ticket; } );
    if(it != end(m_UpdateHandlers))
        m_UpdateHandlers.erase(it);
}

int PSHost::IterateDirectoryListing(const char *_path, const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
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
        dir.name_len = uint16_t(i.size());
        dir.type = VFSDirEnt::Reg;
        
        if(!_handler(dir))
            break;
    }
    
    return VFSError::Ok;
}

int PSHost::StatFS(const char *_path, VFSStatFS &_stat, const VFSCancelChecker &_cancel_checker)
{
    _stat.volume_name = "Processes List";
    _stat.avail_bytes = _stat.free_bytes = 0;
    
    std::lock_guard<std::mutex> lock(m_Lock);
    int total_size = 0;
    for_each( begin(m_Data->files), end(m_Data->files), [&](auto &i){ total_size += i.length(); } );
    _stat.total_bytes = total_size;
    return 0;
}

// return true if process has died, if it didn't on timeout - returns false
// on any errors returns nullopt
static std::optional<bool> WaitForProcessToDie( int pid )
{
    int kq = kqueue();
    if( kq == -1 )
        return std::nullopt;
    
    struct kevent ke;
    EV_SET(&ke, pid, EVFILT_PROC, EV_ADD, NOTE_EXIT, 0, NULL);
    
    int i = kevent(kq, &ke, 1, NULL, 0, NULL);
    if( i == -1 )
        return std::nullopt;
    
    memset(&ke, 0x00, sizeof(struct kevent));
    struct timespec tm;
    tm.tv_sec  = 5;
    tm.tv_nsec = 0;
    i = kevent(kq, NULL, 0, &ke, 1, &tm);
    if( i == -1 )
        return std::nullopt;
    
    if( ke.fflags & NOTE_EXIT )
        return true;

    return false;
}

int PSHost::Unlink(const char *_path, const VFSCancelChecker &_cancel_checker)
{
    if(_path == nullptr)
        return VFSError::InvalidCall;
    
    int gid = -1;
    int pid = -1;
    {
        std::lock_guard<std::mutex> lock(m_Lock);
        
        auto index = ProcIndexFromFilepath_Unlocked(_path);
        if(index < 0)
            return VFSError::NotFound;
        
        auto &proc = m_Data->procs[index];
        gid = proc.gid;
        pid = proc.pid;
    }
    
    // 1st try - being gentle, sending SIGTERM
    int ret = RoutedIO::Default.killpg( gid, SIGTERM );
    if( ret == -1 ) {
        if( errno == ESRCH )
            return VFSError::Ok;
        if( errno == EPERM )
            return VFSError::FromErrno();
        return VFSError::FromErrno();
    }
    
    if( auto died_opt = WaitForProcessToDie(pid) ) {
        if( *died_opt )
            return VFSError::Ok; // goodnight, sweet prince...
        else {
            // 2nd try - process refused to kill itself in 5 seconds by SIGTERM, well, send SIGKILL to him...
            ret = RoutedIO::Default.killpg( gid, SIGKILL );
            if( ret == -1 ) {
                if( errno == ESRCH )
                    return VFSError::Ok;
                if( errno == EPERM )
                    return VFSError::FromErrno();
                return VFSError::FromErrno();
            }
            // no need to wait after signal 9, seems so..
            return VFSError::Ok;
        }
    }
    else
        return VFSError::Ok; // what to return here??
}

}
