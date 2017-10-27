// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
struct StaticDataBlockAnalysis
{
    bool is_binary;
    bool can_be_utf8;
    bool can_be_utf16_le;
    bool likely_utf16_le;
    bool can_be_utf16_be;
    bool likely_utf16_be;
    
};

bool IsValidUTF8String( const void *_data, size_t _bytes_amount );

int DoStaticDataBlockAnalysis(const void *_data,
                              size_t _bytes_amount,
                              StaticDataBlockAnalysis *_output
                              );
// return 0 upon success
