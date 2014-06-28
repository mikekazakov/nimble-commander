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
        static vector< pair<int, CFStringRef> > encodings;
        static dispatch_once_t token = 0;
        dispatch_once(&token, ^{
#define _(a, b) encodings.emplace_back(a, (CFStringRef)CFBridgingRetain([NSString localizedNameOfStringEncoding:CFStringConvertEncodingToNSStringEncoding(b)]))
            _(ENCODING_MACOS_ROMAN_WESTERN, kTextEncodingMacRoman);
            _(ENCODING_UTF8,                0x08000100); // what is UTF8 encoding in CarbonCore?
            _(ENCODING_UTF16LE,             0x14000100); // -""- UTF16LE
            _(ENCODING_UTF16BE,             0x10000100); // -""- UTF16BE
            _(ENCODING_ISO_8859_1,          kTextEncodingISOLatin1);
            _(ENCODING_ISO_8859_2,          kTextEncodingISOLatin2);
            _(ENCODING_ISO_8859_3,          kTextEncodingISOLatin3);
            _(ENCODING_ISO_8859_4,          kTextEncodingISOLatin4);
            _(ENCODING_ISO_8859_5,          kTextEncodingISOLatinCyrillic);
            _(ENCODING_ISO_8859_6,          kTextEncodingISOLatinArabic);
            _(ENCODING_ISO_8859_7,          kTextEncodingISOLatinGreek);
            _(ENCODING_ISO_8859_8,          kTextEncodingISOLatinHebrew);
            _(ENCODING_ISO_8859_9,          kTextEncodingISOLatin5);
            _(ENCODING_ISO_8859_10,         kTextEncodingISOLatin6);
            _(ENCODING_ISO_8859_11,         0x0000020B); // wtf? where Thai ISO encoding has gone?
            _(ENCODING_ISO_8859_13,         kTextEncodingISOLatin7);
            _(ENCODING_ISO_8859_14,         kTextEncodingISOLatin8);
            _(ENCODING_ISO_8859_15,         kTextEncodingISOLatin9);
            _(ENCODING_ISO_8859_16,         kTextEncodingISOLatin10);
            _(ENCODING_OEM437,              kTextEncodingDOSLatinUS);
            _(ENCODING_OEM737,              kTextEncodingDOSGreek);
            _(ENCODING_OEM775,              kTextEncodingDOSBalticRim);
            _(ENCODING_OEM850,              kTextEncodingDOSLatin1);
            _(ENCODING_OEM851,              kTextEncodingDOSGreek1);
            _(ENCODING_OEM852,              kTextEncodingDOSLatin2);
            _(ENCODING_OEM855,              kTextEncodingDOSCyrillic);
            _(ENCODING_OEM857,              kTextEncodingDOSTurkish);
            _(ENCODING_OEM860,              kTextEncodingDOSPortuguese);
            _(ENCODING_OEM861,              kTextEncodingDOSIcelandic);
            _(ENCODING_OEM862,              kTextEncodingDOSHebrew);
            _(ENCODING_OEM863,              kTextEncodingDOSCanadianFrench);
            _(ENCODING_OEM864,              kTextEncodingDOSArabic);
            _(ENCODING_OEM865,              kTextEncodingDOSNordic);
            _(ENCODING_OEM866,              kTextEncodingDOSRussian);
            _(ENCODING_OEM869,              kTextEncodingDOSGreek2);
            _(ENCODING_WIN1250,             kTextEncodingWindowsLatin2);
            _(ENCODING_WIN1251,             kTextEncodingWindowsCyrillic);
            _(ENCODING_WIN1252,             kTextEncodingWindowsLatin1);
            _(ENCODING_WIN1253,             kTextEncodingWindowsGreek);
            _(ENCODING_WIN1254,             kTextEncodingWindowsLatin5);
            _(ENCODING_WIN1255,             kTextEncodingWindowsHebrew);
            _(ENCODING_WIN1256,             kTextEncodingWindowsArabic);
            _(ENCODING_WIN1257,             kTextEncodingWindowsBalticRim);
            _(ENCODING_WIN1258,             kTextEncodingWindowsVietnamese);
#undef _
        });
        return encodings;
    }
}
