//
//  DataBlockAnalysis.cpp
//  Files
//
//  Created by Michael G. Kazakov on 30.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <algorithm>
#import "DataBlockAnalysis.h"


static const size_t g_MaxBytesProc = 256;

// we're not supporting UTF-16 or UCS-2 now!
// a very few checks implemented now, will be expanding later
int DoStaticDataBlockAnalysis(const void *_data,
                              size_t _bytes_amount,
                              StaticDataBlockAnalysis *_output
                              )
{
    if(_bytes_amount < 4) // we need some reasonable data amount to do any prediction
        return -1;

    size_t zr_count = 0; // zeros count in a file
    size_t inv_utf8 = 0; // invalid utf-8 sequences appearances
    
    const unsigned char *bytes = (const unsigned char*) _data;
    
    for(size_t i = 0, e = _bytes_amount; i < e; ++i) // check for null presence
        zr_count += !bytes[i];
    
    for(size_t i = 0, e = _bytes_amount, n = 0; i < e; ++i) // check UTF-8 sequence
    {
        unsigned char b = bytes[i];
        if(n == 0)
        {
            if((b & 0x80) == 0)
            {
                continue;
            }
            else if((b & 0xE0) == 0xC0)
            {
                n = 1;
                continue;
            }
            else if((b & 0xF0) == 0xE0)
            {
                n = 2;
                continue;
            }
            else
            {
                inv_utf8++;
                continue;
            }
        }
        else
        {
            if((b & 0xC0) != 0x80)
            {
                inv_utf8++;
                n = 0;
            }
            else
            {
                --n;
            }
        }
    }
    
    _output->is_binary = zr_count != 0;
    _output->can_be_utf8 = inv_utf8 == 0;
    
    return 0;
}
