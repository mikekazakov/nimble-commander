// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "EncodingDetection.h"

namespace nc::vfs::arc {

CFStringEncoding DetectEncoding( const void* _bytes, size_t _sz )
{
    NSData *data = [NSData dataWithBytesNoCopy:(void*)_bytes
                                        length:_sz
                                  freeWhenDone:false];
    
    NSStringEncoding ns_enc = [NSString stringEncodingForData:data
                                           encodingOptions:nil
                                           convertedString:nil
                                       usedLossyConversion:nil];
    if( ns_enc == 0 )
        return kCFStringEncodingMacRoman;
    
    CFStringEncoding cf_enc = CFStringConvertNSStringEncodingToEncoding(ns_enc);
    if( cf_enc == kCFStringEncodingInvalidId )
        return kCFStringEncodingMacRoman;

    return cf_enc;
}

}
