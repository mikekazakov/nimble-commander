//
//  VFSArchiveUnRARInternals.h
//  Files
//
//  Created by Michael G. Kazakov on 03.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include <unrar/raros.hpp>
#include <unrar/dll.hpp>

namespace nc::vfs::unrar {

struct Entry
{
    string      rar_name;       // original full name in rar archive, for search and comparisons
    string      name;           // utf-8
    uint64_t    packed_size = 0;
    uint64_t    unpacked_size = 0;
    time_t      time = 0;
    uint32_t    uuid = 0;
    bool        isdir = false;
};

struct Directory
{
    string full_path; // full path to directory including trailing slash
    time_t time = 0;
    deque<Entry> entries;
};

struct SeekCache
{
    ~SeekCache();
    
    void    *rar_handle = 0;
    uint32_t uid = 0; // uid of a last read item. if client want to use such cache, their's uid should be bigger than uid
};

int VFSArchiveUnRARErrorToVFSError(int _rar_error);

}
