// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Cocoa/Cocoa.h>
#include <SystemConfiguration/SystemConfiguration.h>
#include <IOKit/IOKitLib.h>
#include <sys/sysctl.h>
#include <libproc.h>
#include <mach/mach.h>
#include <mutex>
#include <Utility/ObjCpp.h>
#include <Utility/SystemInformation.h>
#include <Utility/StringExtras.h>
#include <Base/CFString.h>
#include <Base/CommonPaths.h>

namespace nc::utility {

// CPU_STATE_USER
// processor_info_array_t
int GetBSDProcessList(kinfo_proc **procList, size_t *procCount)
{
    int err;
    kinfo_proc *result;
    bool done;
    static const int name[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    // Declaring name as const requires us to cast it when passing it to
    // sysctl because the prototype doesn't include the const modifier.
    size_t length;

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

    result = nullptr;
    done = false;
    do {
        assert(result == nullptr);

        // Call sysctl with a NULL buffer.

        length = 0;
        err = sysctl(const_cast<int *>(name), (sizeof(name) / sizeof(*name)) - 1, nullptr, &length, nullptr, 0);
        if( err == -1 ) {
            err = errno;
        }

        // Allocate an appropriately sized buffer based on the results
        // from the previous call.

        if( err == 0 ) {
            result = static_cast<kinfo_proc *>(malloc(length));
            if( result == nullptr ) {
                err = ENOMEM;
            }
        }

        // Call sysctl again with the new buffer.  If we get an ENOMEM
        // error, toss away our buffer and start again.

        if( err == 0 ) {
            err = sysctl(const_cast<int *>(name), (sizeof(name) / sizeof(*name)) - 1, result, &length, nullptr, 0);
            if( err == -1 ) {
                err = errno;
            }
            if( err == 0 ) {
                done = true;
            }
            else if( err == ENOMEM ) {
                assert(result != nullptr);
                free(result);
                result = nullptr;
                err = 0;
            }
        }
    } while( err == 0 && !done );

    // Clean up and establish post conditions.

    if( err != 0 && result != nullptr ) {
        free(result);
        result = nullptr;
    }
    *procList = result;
    if( err == 0 ) {
        *procCount = length / sizeof(kinfo_proc);
    }

    assert((err == 0) == (*procList != nullptr));

    return err;
}

std::optional<MemoryInfo> GetMemoryInfo() noexcept
{
    static int pagesize = 0;
    static uint64_t memsize = 0;

    // get page size and hardware memory size (only once)
    static std::once_flag once;
    call_once(once, [] {
        int psmib[2] = {CTL_HW, HW_PAGESIZE};
        size_t length = sizeof(pagesize);
        sysctl(psmib, 2, &pagesize, &length, nullptr, 0);

        int memsizemib[2] = {CTL_HW, HW_MEMSIZE};
        length = sizeof(memsize);
        sysctl(memsizemib, 2, &memsize, &length, nullptr, 0);
    });

    // get general memory info
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    vm_statistics64 vmstat;
    if( host_statistics64(mach_host_self(), HOST_VM_INFO64, reinterpret_cast<host_info_t>(&vmstat), &count) !=
        KERN_SUCCESS )
        return {};

    const uint64_t wired_memory = static_cast<uint64_t>(vmstat.wire_count) * pagesize;
    const uint64_t active_memory = static_cast<uint64_t>(vmstat.active_count) * pagesize;
    const uint64_t inactive_memory = static_cast<uint64_t>(vmstat.inactive_count) * pagesize;
    const uint64_t free_memory = static_cast<uint64_t>(vmstat.free_count) * pagesize;
    const uint64_t file_cache_memory =
        static_cast<uint64_t>(vmstat.external_page_count + vmstat.purgeable_count) * pagesize;
    const uint64_t app_memory = static_cast<uint64_t>(vmstat.internal_page_count - vmstat.purgeable_count) * pagesize;
    const uint64_t compressed = static_cast<uint64_t>(vmstat.compressor_page_count) * pagesize;
    const uint64_t total_memory = wired_memory + active_memory + inactive_memory + free_memory;
    // Activity monitor shows higher values for "used memory", no idea how these numbers are
    // calculated
    const uint64_t used_memory =
        (static_cast<uint64_t>(vmstat.active_count) + static_cast<uint64_t>(vmstat.inactive_count) +
         static_cast<uint64_t>(vmstat.speculative_count) + static_cast<uint64_t>(vmstat.wire_count) +
         static_cast<uint64_t>(vmstat.compressor_page_count) - static_cast<uint64_t>(vmstat.purgeable_count) -
         static_cast<uint64_t>(vmstat.external_page_count)) *
        pagesize;

    MemoryInfo mem;
    mem.total = total_memory;
    mem.wired = wired_memory;
    mem.active = active_memory;
    mem.inactive = inactive_memory;
    mem.free = free_memory;
    mem.used = used_memory;
    mem.file_cache = file_cache_memory;
    mem.applications = app_memory;
    mem.compressed = compressed;

    // get the swap size
    int swapmib[2] = {CTL_VM, VM_SWAPUSAGE};
    struct xsw_usage swap_info;
    size_t length = sizeof(swap_info);
    if( sysctl(swapmib, 2, &swap_info, &length, nullptr, 0) < 0 )
        return {};
    mem.swap = swap_info.xsu_used;

    mem.total_hw = memsize;

    return mem;
}

std::optional<CPULoad> GetCPULoad() noexcept
{
    unsigned int *cpuInfo;
    mach_msg_type_number_t numCpuInfo;
    natural_t numCPUs = 0;
    const kern_return_t err = host_processor_info(mach_host_self(),
                                                  PROCESSOR_CPU_LOAD_INFO,
                                                  &numCPUs,
                                                  reinterpret_cast<processor_info_array_t *>(&cpuInfo),
                                                  &numCpuInfo);
    if( err != KERN_SUCCESS )
        return {};

    double system = 0.;
    double user = 0.;
    double idle = 0.;

    static unsigned int *prior = static_cast<unsigned int *>(calloc(CPU_STATE_MAX * numCPUs, sizeof(unsigned int)));
    [[maybe_unused]] static const unsigned int alloc_cpus = numCPUs;
    assert(alloc_cpus == numCPUs);

    for( unsigned i = 0; i < numCPUs; ++i ) {
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
    vm_deallocate(mach_task_self(), reinterpret_cast<vm_address_t>(cpuInfo), sizeof(unsigned int) * numCpuInfo);

    const double total = system + user + idle;
    system /= total;
    user /= total;
    idle /= total;

    // get historic load values
    int mib[2];
    mib[0] = CTL_VM;
    mib[1] = VM_LOADAVG;
    loadavg history = {};
    size_t len = sizeof(history);
    if( sysctl(mib, 2, &history, &len, nullptr, 0) != 0 )
        return {};
    assert(history.fscale != 0);

    // get number of processes and threads currently running
    static const processor_set_name_port_t processors_set = [] {
        processor_set_name_port_t pset;
        processor_set_default(mach_host_self(), &pset);
        return pset;
    }();
    struct processor_set_load_info ps_load_info = {};
    mach_msg_type_number_t count = PROCESSOR_SET_LOAD_INFO_COUNT;
    const kern_return_t ss_err = processor_set_statistics(
        processors_set, PROCESSOR_SET_LOAD_INFO, reinterpret_cast<processor_set_info_t>(&ps_load_info), &count);
    if( ss_err != KERN_SUCCESS )
        return {};

    CPULoad load;
    load.system = system;
    load.user = user;
    load.idle = idle;
    load.history[0] = static_cast<double>(history.ldavg[0]) / static_cast<double>(history.fscale);
    load.history[1] = static_cast<double>(history.ldavg[1]) / static_cast<double>(history.fscale);
    load.history[2] = static_cast<double>(history.ldavg[2]) / static_cast<double>(history.fscale);
    load.processes = ps_load_info.task_count;
    load.threads = ps_load_info.thread_count;

    return load;
}

std::chrono::seconds GetUptime() noexcept
{
    int mib[2];
    mib[0] = CTL_KERN;
    mib[1] = KERN_BOOTTIME;
    struct timeval boottime_raw;
    size_t len = sizeof(boottime_raw);
    if( sysctl(mib, 2, &boottime_raw, &len, nullptr, 0) != 0 )
        return {};
    const auto boottime = std::chrono::system_clock::time_point(
        std::chrono::microseconds(boottime_raw.tv_usec + (boottime_raw.tv_sec * 1000000)));
    const auto uptime = std::chrono::system_clock::now() - boottime;
    return std::chrono::duration_cast<std::chrono::seconds>(uptime);
}

static std::string ExtractReadableModelNameFromFrameworks(std::string_view _coded_name)
{
    NSDictionary *dict;

    // 1st attempt: ServerInformation.framework
    const auto server_information_framework = @"/System/Library/PrivateFrameworks/ServerInformation.framework";
    if( auto bundle = [NSBundle bundleWithPath:server_information_framework] )
        if( auto path = [bundle pathForResource:@"SIMachineAttributes" ofType:@"plist"] )
            dict = [NSDictionary dictionaryWithContentsOfFile:path];

    // 2nd attempt: ServerKit.framework
    const auto server_kit_framework = @"/System/Library/PrivateFrameworks/ServerKit.framework";
    if( dict == nil )
        if( auto bundle = [NSBundle bundleWithPath:server_kit_framework] )
            if( auto path = [bundle pathForResource:@"XSMachineAttributes" ofType:@"plist"] )
                dict = [NSDictionary dictionaryWithContentsOfFile:path];

    if( dict == nil )
        return {};

    const auto coded_name = [NSString stringWithUTF8StdStringView:_coded_name];
    if( coded_name == nil )
        return {};

    const auto info = objc_cast<NSDictionary>(dict[coded_name]);
    if( info == nil )
        return {};

    const auto localizable = objc_cast<NSDictionary>(info[@"_LOCALIZABLE_"]);
    if( localizable == nil )
        return {};

    const auto loc_model = objc_cast<NSString>(localizable[@"model"]);
    if( loc_model == nil )
        return {};

    auto human_model = loc_model;
    if( auto market_model = objc_cast<NSString>(localizable[@"marketingModel"]) ) {
        const auto cs = [NSCharacterSet characterSetWithCharactersInString:@"()"];
        const auto splitted = [market_model componentsSeparatedByCharactersInSet:cs];
        if( splitted.count == 3 )
            human_model = [NSString stringWithFormat:@"%@ (%@)", loc_model, splitted[1]];
    }

    return human_model.UTF8String;
}

static std::string ExtractReadableModelNameFromSystemProfiler()
{
    const auto path = base::CommonPaths::Library() + "Preferences/com.apple.SystemProfiler.plist";
    const auto url = [NSURL fileURLWithFileSystemRepresentation:path.c_str() isDirectory:false relativeToURL:nil];
    if( url == nil )
        return {};

    const auto prefs = [NSDictionary dictionaryWithContentsOfURL:url];
    if( prefs == nil )
        return {};

    const auto names = objc_cast<NSDictionary>(prefs[@"CPU Names"]);
    if( names == nil )
        return {};

    const auto country_id = NSLocale.autoupdatingCurrentLocale.countryCode;
    for( const id key in names.allKeys ) {
        if( [objc_cast<NSString>(key) hasSuffix:country_id] ) {
            if( const auto name = objc_cast<NSString>(names[key]) ) {
                return name.UTF8String;
            }
        }
    }
    return {};
}

bool GetSystemOverview(SystemOverview &_overview)
{
    // get machine name everytime
    if( auto computer_name = SCDynamicStoreCopyComputerName(nullptr, nullptr) ) {
        _overview.computer_name = ((__bridge NSString *)computer_name).UTF8String;
        CFRelease(computer_name);
    }

    // get user name everytime
    _overview.user_name = NSUserName().UTF8String;

    // get full user name everytime
    _overview.user_full_name = NSFullUserName().UTF8String;

    // get machine model once
    [[clang::no_destroy]] static std::string coded_model = "unknown";
    [[clang::no_destroy]] static std::string human_model = "N/A";
    static std::once_flag once;
    call_once(once, [] {
        char hw_model[256];
        size_t len = 256;
        if( sysctlbyname("hw.model", hw_model, &len, nullptr, 0) != 0 )
            return;
        coded_model = hw_model;

        if( auto name1 = ExtractReadableModelNameFromFrameworks(coded_model); !name1.empty() ) {
            human_model = name1;
        }
        else if( auto name2 = ExtractReadableModelNameFromSystemProfiler(); !name2.empty() ) {
            human_model = name2;
        }
    });

    _overview.human_model = human_model;
    _overview.coded_model = coded_model;

    return true;
}

bool IsThisProcessSandboxed() noexcept
{
    static const bool is_sandboxed = getenv("APP_SANDBOX_CONTAINER_ID") != nullptr;
    return is_sandboxed;
}

const std::string &GetBundleID() noexcept
{
    [[clang::no_destroy]] static const std::string bundle_id = []() -> std::string {
        if( CFStringRef bid = CFBundleGetIdentifier(CFBundleGetMainBundle()) )
            return base::CFStringGetUTF8StdString(bid);
        else
            return "unknown";
    }();
    return bundle_id;
}

} // namespace nc::utility
