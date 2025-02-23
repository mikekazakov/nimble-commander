// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <optional>
#include <chrono>

typedef struct kinfo_proc kinfo_proc;

namespace nc::utility {

struct MemoryInfo {
    // this is calculated from a sum of amounts of pages
    uint64_t total;

    // actual installed memory, can be *less* than total due to compression
    uint64_t total_hw;

    uint64_t active;
    uint64_t inactive;
    uint64_t free;

    // physical memory containing data that cannot be compressed or swapped to disk
    uint64_t wired;

    // = applications + wired + compressed
    uint64_t used;

    // amount of compressed data temporarily moved to disk to make room for recently used data
    uint64_t swap;

    // size of files cached by the system into unused memory to improve performance
    uint64_t file_cache;

    // physical memory allocated by apps and system processes
    uint64_t applications;

    // physical memory used to store a compressed version of data that has not been used recently
    uint64_t compressed;
};

struct CPULoad {
    double system;
    double user;
    double idle;
    // system + user + idle = 1.0
    double history[3]; // 'uptime'-style load - last 1, 5 and 15 minutes
    int processes;
    int threads;
};

struct SystemOverview {
    std::string computer_name;
    std::string user_name;
    std::string user_full_name;
    std::string human_model; // like MacBook Pro (mid 2012), or MacBook Air (early 2013),localizable
    std::string coded_model; // like "Macmini6,2"
};

std::optional<MemoryInfo> GetMemoryInfo() noexcept;

/**
 * Synchronously reads the current CPU load, divided in system, user and idle
 */
std::optional<CPULoad> GetCPULoad() noexcept;

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

const std::string &GetBundleID() noexcept;

std::chrono::seconds GetUptime() noexcept;

} // namespace nc::utility
