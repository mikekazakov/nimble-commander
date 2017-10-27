// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>

using namespace std;

typedef struct kinfo_proc kinfo_proc;

namespace sysinfo
{
    
struct MemoryInfo
{
    uint64_t total;    // this is calculated from a sum of amounts of pages
    uint64_t total_hw; // actual installed memory, will be greater than total
    uint64_t wired;
    uint64_t active;
    uint64_t inactive;
    uint64_t free;
    uint64_t used;
    uint64_t swap;
};
    
struct CPULoad
{
    double system;
    double user;
    double idle;
    // system + user + idle = 1.0
};
    
struct SystemOverview
{
    string computer_name;
    string user_full_name;
    string human_model; // like MacBook Pro (mid 2012), or MacBook Air (early 2013), localizable
    string coded_model; // like "Macmini6,2"
};

enum class OSXVersion
{
    OSX_9       = 1090,
    OSX_10      = 1100,
    OSX_11      = 1110,
    OSX_12      = 1120,
    OSX_13      = 1130,
    OSX_Unknown = 100500
};
    
bool GetMemoryInfo(MemoryInfo &_mem) noexcept;
    
/**
 * Synchronously reads current CPU load, divided in system, user and idle
 *
 * @param _load - CPULoad structure to fill
 * @return true on success
 */
bool GetCPULoad(CPULoad &_load) noexcept;
    
/**
 * Returns currently running OSX Version or 
 * OSX_Unknown if it's not possible to determine current version (future release maybe)  or
 * OSX_Below if current system is Snow Leopard or older
 * Loads this info on first use, then return cached data instantly
 */
OSXVersion GetOSXVersion() noexcept;

/**
 * Returns common information about system, such as computer name, computer model, user name etc
 */
bool GetSystemOverview(SystemOverview &_overview);

/**
 * Returns a list of all BSD processes on the system.  This routine
 * allocates the list and puts it in *procList and a count of the
 * number of entries in *procCount.  You are responsible for freeing
 * this list (use "free" from System framework).
 * On success, the function returns 0.
 * On error, the function returns a BSD errno value.
 */
int GetBSDProcessList(kinfo_proc **procList, size_t *procCount);

bool IsThisProcessSandboxed() noexcept;

const string& GetBundleID() noexcept;
    
}
