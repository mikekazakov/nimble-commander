// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <unrar/raros.hpp>
#include <unrar/dll.hpp>
#include <string>
#include <stdint.h>
#include <deque>
#include <time.h>

namespace nc::vfs::unrar {

struct Entry
{
    std::string rar_name;       // original full name in rar archive, for search and comparisons
    std::string name;           // utf-8
    uint64_t    packed_size = 0;
    uint64_t    unpacked_size = 0;
    time_t      time = 0;
    uint32_t    uuid = 0;
    bool        isdir = false;
};

struct Directory
{
    std::string full_path; // full path to directory including trailing slash
    time_t time = 0;
    std::deque<Entry> entries;
};

struct SeekCache
{
    ~SeekCache();
    
    void    *rar_handle = 0;
    uint32_t uid = 0; // uid of a last read item. if client want to use such cache, their's uid should be bigger than uid
};

int VFSArchiveUnRARErrorToVFSError(int _rar_error);

}
