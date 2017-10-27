// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.

#pragma once

#include <VFS/VFS.h>

namespace nc::vfs {

struct AppleDoubleEA
{
    // no allocations, only pointing at original memory buffer
    const void* data;
    const char* name; // null-terminated UTF-8 string
    uint32_t    data_sz;
    uint32_t    name_len; // length excluding zero-terminator. no zero-length names are allowed
};

 /**
  * ExtractEAFromAppleDouble interpret memory block of EAs packed into AppleDouble file, usually for archives.
  * Return NULL or array of AppleDoubleEA (number of _ea_count) allocated with malloc.
  * Caller is responsible for deallocating this memory.
  */
vector<AppleDoubleEA> ExtractEAFromAppleDouble(const void *_memory_buf, size_t _memory_size);

void *BuildAppleDoubleFromEA(VFSFile &_file,
                             size_t *_buf_sz);

}
