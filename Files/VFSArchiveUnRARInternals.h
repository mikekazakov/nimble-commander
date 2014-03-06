//
//  VFSArchiveUnRARInternals.h
//  Files
//
//  Created by Michael G. Kazakov on 03.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include "3rd_party/unrar/unrar-5.0.14/raros.hpp"
#include "3rd_party/unrar/unrar-5.0.14/dll.hpp"
#import <string>
#import <deque>

using namespace std;

struct VFSArchiveUnRAREntry
{
    VFSArchiveUnRAREntry();
    ~VFSArchiveUnRAREntry();
    VFSArchiveUnRAREntry(const VFSArchiveUnRAREntry&) = delete;
    VFSArchiveUnRAREntry(const VFSArchiveUnRAREntry&&) = delete;
    void operator=(const VFSArchiveUnRAREntry&) = delete;
    
    string      rar_name;       // original full name in rar archive, for search and comparisons
    string      name;           // utf-8
    CFStringRef cfname = 0;     // no allocations, pointing at name
    uint64_t    packed_size = 0;
    uint64_t    unpacked_size = 0;
    time_t      time = 0;
    uint32_t    uuid = 0;
    bool        isdir = false;
};

struct VFSArchiveUnRARDirectory
{
    string full_path; // full path to directory including trailing slash
    time_t time = 0;
    deque<VFSArchiveUnRAREntry> entries;
};

struct VFSArchiveUnRARSeekCache
{
    ~VFSArchiveUnRARSeekCache();
    
    void    *rar_handle = 0;
    uint32_t uid = 0; // uid of a last read item. if client want to use such cache, their's uid should be bigger than uid
};

int VFSArchiveUnRARErrorToVFSError(int _rar_error);
