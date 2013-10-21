//
//  AppleDoubleEA.h
//  Files
//
//  Created by Michael G. Kazakov on 20.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <stdint.h>

struct AppleDoubleEA
{
    // no allocations, only pointing at original memory buffer
    const void* data;
    const char* name; // null-terminated UTF-8 string
    uint32_t    data_sz;
    uint32_t    name_len; // length excluding zero-terminator. no zero-length names are allowed
};

 /**
  * ExtractEAFromAppleDouble interpret memory block of EAs packed into AppleDouble file, usually for archives
  * return NULL or array of AppleDoubleEA allocated with malloc
  * caller is responsible for deallocating this memory
  */
AppleDoubleEA *ExtractEAFromAppleDouble(const void *_memory_buf,
                                       size_t      _memory_size,
                                       size_t     *_ea_count
                                       );
