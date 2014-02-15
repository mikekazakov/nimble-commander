//
//  EncodingsList.c
//  Files
//
//  Created by Michael G. Kazakov on 21.07.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Encodings.h"

namespace encodings
{
    const vector< pair<int, CFStringRef> >& LiteralEncodingsList()
    {
        // we don't need freeing upon application termination (atexit), sojust use 'new'
        static vector< pair<int, CFStringRef> > *encodings = 0;
        static dispatch_once_t token = 0;
        dispatch_once(&token, ^{
            encodings = new vector< pair<int, CFStringRef> >;
#define _(a, b) encodings->emplace_back(a, (CFStringRef)b)
            _(ENCODING_MACOS_ROMAN_WESTERN, @"Western (Mac OS Roman)");
            _(ENCODING_OEM866, @"OEM 866 (DOS)");
            _(ENCODING_WIN1251, @"Windows 1251");
            _(ENCODING_UTF8, @"UTF-8");
            _(ENCODING_UTF16LE, @"UTF-16 LE");
            _(ENCODING_UTF16BE, @"UTF-16 BE");
            _(ENCODING_ISO_8859_1, @"Western (ISO Latin 1)");
            _(ENCODING_ISO_8859_2, @"Central European (ISO Latin 2)");
            _(ENCODING_ISO_8859_3, @"Western (ISO Latin 3)");
            _(ENCODING_ISO_8859_4, @"Central European (ISO Latin 4)");
            _(ENCODING_ISO_8859_5, @"Cyrillic (ISO 8859-5)");
            _(ENCODING_ISO_8859_6, @"Arabic (ISO 8859-6)");
            _(ENCODING_ISO_8859_7, @"Greek (ISO 8859-7)");
            _(ENCODING_ISO_8859_8, @"Hebrew (ISO 8859-8)");
            _(ENCODING_ISO_8859_9, @"Turkish (ISO Latin 5)");
            _(ENCODING_ISO_8859_10, @"Nordic (ISO Latin 6)");
            _(ENCODING_ISO_8859_11, @"Thai (ISO 8859-11)");
            _(ENCODING_ISO_8859_13, @"Baltic (ISO Latin 7)");
            _(ENCODING_ISO_8859_14, @"Celtic (ISO Latin 8)");
            _(ENCODING_ISO_8859_15, @"Western (ISO Latin 9)");
            _(ENCODING_ISO_8859_16, @"Romanian (ISO Latin 10)");
#undef _
        });
        return *encodings;
    }
}
