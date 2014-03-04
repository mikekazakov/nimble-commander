//
//  VFSArchiveUnRARInternals.h
//  Files
//
//  Created by Michael G. Kazakov on 03.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <string>
#import <deque>

using namespace std;

struct VFSArchiveUnRAREntry
{
    string      rar_name; // original name in rar archive, for search and comparisons
    string      name;     // utf-8
    CFStringRef cfname;   // no allocations, pointing at name
    
    uint64_t    unpacked_size;
    time_t      time;
    uint32_t    uuid;
    bool        isdir;
    

    VFSArchiveUnRAREntry():
        cfname(NULL)
    {
    }
    
    ~VFSArchiveUnRAREntry()
    {
        if(cfname != 0)
        {
//            auto a = CFGetRetainCount(cfname);
///            assert(CFGetRetainCount(cfname) == 1); // ??????
            CFRelease(cfname);
            cfname = 0;
        }
    }
    
    VFSArchiveUnRAREntry(const VFSArchiveUnRAREntry&) = delete;
    VFSArchiveUnRAREntry(const VFSArchiveUnRAREntry&&) = delete;
    void operator=(const VFSArchiveUnRAREntry&) = delete;
};


struct VFSArchiveUnRARDirectory
{
    string full_path; // full path to directory including trailing slash
    time_t      time = 0;
//    string short_path;
    
    
    deque<VFSArchiveUnRAREntry> entries;
};
