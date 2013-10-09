//
//  sysinfo.mm
//  Files
//
//  Created by Michael G. Kazakov on 08.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//


#import <sys/sysctl.h>
//#import <sys/proc.h>
//#import <sys/user.h>
//#import <sys/stat.h>
//#import <sys/ioctl.h>
//#import <sys/mount.h>
//#import <sys/resourcevar.h>
//#import <sys/vmmeter.h>
//#import <sys/resource.h>
//#import <mach/host_info.h>
//#import <mach/mach_host.h>
//#import <mach/task_info.h>
//#import <mach/task.h>
#import <mach/mach.h>
//#import <mach/mach_error.h>
//#import <mach/policy.h>
//#import <mach/thread_info.h>
//#import <mach/processor_info.h>
//#import <stdint.h>
//#import <libproc.h>
#import "sysinfo.h"



typedef struct kinfo_proc kinfo_proc;
//CPU_STATE_USER
//processor_info_array_t
static int GetBSDProcessList(kinfo_proc **procList, size_t *procCount)
// Returns a list of all BSD processes on the system.  This routine
// allocates the list and puts it in *procList and a count of the
// number of entries in *procCount.  You are responsible for freeing
// this list (use "free" from System framework).
// On success, the function returns 0.
// On error, the function returns a BSD errno value.
{
    int                 err;
    kinfo_proc *        result;
    bool                done;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    // Declaring name as const requires us to cast it when passing it to
    // sysctl because the prototype doesn't include the const modifier.
    size_t              length;
    
    //    assert( procList != NULL);
    //    assert(*procList == NULL);
    //    assert(procCount != NULL);
    
    *procCount = 0;
    
    // We start by calling sysctl with result == NULL and length == 0.
    // That will succeed, and set length to the appropriate length.
    // We then allocate a buffer of that size and call sysctl again
    // with that buffer.  If that succeeds, we're done.  If that fails
    // with ENOMEM, we have to throw away our buffer and loop.  Note
    // that the loop causes use to call sysctl with NULL again; this
    // is necessary because the ENOMEM failure case sets length to
    // the amount of data returned, not the amount of data that
    // could have been returned.
    
    result = NULL;
    done = false;
    do {
        assert(result == NULL);
        
        // Call sysctl with a NULL buffer.
        
        length = 0;
        err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                     NULL, &length,
                     NULL, 0);
        if (err == -1) {
            err = errno;
        }
        
        // Allocate an appropriately sized buffer based on the results
        // from the previous call.
        
        if (err == 0) {
            result = (kinfo_proc *) malloc(length);
            if (result == NULL) {
                err = ENOMEM;
            }
        }
        
        // Call sysctl again with the new buffer.  If we get an ENOMEM
        // error, toss away our buffer and start again.
        
        if (err == 0) {
            err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                         result, &length,
                         NULL, 0);
            if (err == -1) {
                err = errno;
            }
            if (err == 0) {
                done = true;
            } else if (err == ENOMEM) {
                assert(result != NULL);
                free(result);
                result = NULL;
                err = 0;
            }
        }
    } while (err == 0 && ! done);
    
    // Clean up and establish post conditions.
    
    if (err != 0 && result != NULL) {
        free(result);
        result = NULL;
    }
    *procList = result;
    if (err == 0) {
        *procCount = length / sizeof(kinfo_proc);
    }
    
    assert( (err == 0) == (*procList != NULL) );
    
    return err;
}


namespace sysinfo
{

    
    
    
bool GetMemoryInfo(MemoryInfo &_mem)
{
    int psmib[2] = {CTL_HW, HW_PAGESIZE};
    int pagesize;
    size_t length;
    
    // get page size
    length = sizeof (pagesize);
    if (sysctl(psmib, 2, &pagesize, &length, NULL, 0) < 0)
        return false;
    
    // get general memory info
    mach_msg_type_number_t count = HOST_VM_INFO_COUNT;
    vm_statistics_data_t vmstat;
    if (host_statistics (mach_host_self (), HOST_VM_INFO, (host_info_t) &vmstat, &count) != KERN_SUCCESS)
        return false;
    uint64_t total_memory = vmstat.wire_count +
                            vmstat.active_count +
                            vmstat.inactive_count +
                            vmstat.free_count/* +
                            vmstat.zero_fill_count */;
    total_memory *= pagesize;
    uint64_t wired_memory = vmstat.wire_count * pagesize;
    uint64_t active_memory = vmstat.active_count * pagesize;
    uint64_t inactive_memory = vmstat.inactive_count * pagesize;
    uint64_t free_memory = vmstat.free_count * pagesize;
//    uint64_t speculative_memory = vmstat.speculative_count * pagesize;

//    printf("%d", vmstat.free_count - vmstat.speculative_count);
    
    // checked - nearly as "memory used" in activity monitor
    // but shows roughly +400-500 Mb of used memory. straaaange...
    uint64_t used_memory = total_memory - free_memory;
    
    _mem.total = total_memory;
    _mem.wired = wired_memory;
    _mem.active = active_memory;
    _mem.inactive = inactive_memory;
    _mem.free = free_memory;
    _mem.used = used_memory;
    
    //get the swap size
	int swapmib[2] = {CTL_VM,VM_SWAPUSAGE};
    struct xsw_usage swap_info;
	length = sizeof(swap_info);
    if( sysctl(swapmib, 2, &swap_info, &length, NULL, NULL) < 0)
        return false;
    _mem.swap = swap_info.xsu_used;
    
    int memsizemib[2] = {CTL_HW,HW_MEMSIZE};
    uint64_t memsize;
	length = sizeof(memsize);
    if( sysctl(memsizemib, 2, &memsize, &length, NULL, NULL) < 0)
        return false;
    _mem.total_hw = memsize;
    
    return true;
}
    
bool GetCPULoad(CPULoad &_load)
{
    unsigned int *cpuInfo;
    mach_msg_type_number_t numCpuInfo;
    natural_t numCPUs = 0;
    kern_return_t err = host_processor_info(mach_host_self(),
                                            PROCESSOR_CPU_LOAD_INFO,
                                            &numCPUs,
                                            (processor_info_array_t*)&cpuInfo,
                                            &numCpuInfo);
    if(err != KERN_SUCCESS)
        return false;

    double system = 0.;
    double user = 0.;
    double idle = 0.;
    
    static unsigned int *prior = 0;
    static unsigned int alloc_cpus = 0;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        prior = (unsigned int*) calloc(CPU_STATE_MAX * numCPUs, sizeof(unsigned int));
        alloc_cpus = numCPUs;
    });
    assert(alloc_cpus == numCPUs);
    
    for(unsigned i = 0; i < numCPUs; ++i)
    {
        system += cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM];
        system += cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE];
        user += cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER];
        idle += cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE];
        
        system -= prior[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM];
        system -= prior[(CPU_STATE_MAX * i) + CPU_STATE_NICE];
        user -= prior[(CPU_STATE_MAX * i) + CPU_STATE_USER];
        idle -= prior[(CPU_STATE_MAX * i) + CPU_STATE_IDLE];
    }

    memcpy(prior, cpuInfo, sizeof(integer_t) * numCpuInfo);
    vm_deallocate(mach_task_self(), (vm_address_t)cpuInfo, sizeof(unsigned int) * numCpuInfo);
        
    double total = system + user + idle;
    system /= total;
    user /= total;
    idle /= total;
    
    _load.system = system;
    _load.user = user;
    _load.idle = idle;
    
    return true;
}

OSXVersion GetOSXVersion()
{
    static OSXVersion version = OSXVersion::OSX_Unknown;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if(NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"])
        {
            id prod_ver = [d objectForKey:@"ProductVersion"];
            if(prod_ver != nil && [prod_ver isKindOfClass:[NSString class]])
            {
                NSString *prod_ver_s = prod_ver;
                if([prod_ver_s isEqualToString:@"10.9"]) version = OSXVersion::OSX_9;
                else if([prod_ver_s isEqualToString:@"10.8"]) version = OSXVersion::OSX_8;
                else if([prod_ver_s isEqualToString:@"10.7"]) version = OSXVersion::OSX_7;
                else if([prod_ver_s isEqualToString:@"10.6"]) version = OSXVersion::OSX_Old;
                else if([prod_ver_s isEqualToString:@"10.5"]) version = OSXVersion::OSX_Old;
                else if([prod_ver_s isEqualToString:@"10.4"]) version = OSXVersion::OSX_Old;
            }
        }
    });
    return version;
}
    
}