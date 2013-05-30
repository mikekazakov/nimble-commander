//
//  DataBlockAnalysis.h
//  Files
//
//  Created by Michael G. Kazakov on 30.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//


struct StaticDataBlockAnalysis
{
    bool is_binary;
    bool can_be_utf8;

    
    
};

int DoStaticDataBlockAnalysis(const void *_data,
                              size_t _bytes_amount,
                              StaticDataBlockAnalysis *_output
                              );
// return 0 upon success
