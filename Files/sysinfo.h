//
//  sysinfo.h
//  Files
//
//  Created by Michael G. Kazakov on 08.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

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
    NSString *computer_name;
    NSString *user_full_name;
    NSString *human_model; // like MacBook Pro (mid 2012), or MacBook Air (early 2013), localizable
};

enum class OSXVersion
{
    OSX_Old     = 1060,
    OSX_7       = 1070,
    OSX_8       = 1080,
    OSX_9       = 1090,
    OSX_Unknown = 100500
};
    
bool GetMemoryInfo(MemoryInfo &_mem);
    
/**
 * Synchronously reads current CPU load, divided in system, user and idle
 *
 * @param _load - CPULoad structure to fill
 * @return true on success
 */
bool GetCPULoad(CPULoad &_load);
    
/**
 * Returns currently running OSX Version or 
 * OSX_Unknown if it's not possible to determine current version (future release maybe)  or
 * OSX_Below if current system is Snow Leopard or older
 * Loads this info on first use, then return cached data instantly
 */
OSXVersion GetOSXVersion();


/**
 * Returns common information about system, such as computer name, computer model, user name etc
 */
bool GetSystemOverview(SystemOverview &_overview);

}
