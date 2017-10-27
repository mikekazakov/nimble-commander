// Copyright (C) 2013-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <string>
#include <Cocoa/Cocoa.h>
#include <mutex>

#include <Utility/Encodings.h>
//#import <Foundation/Foundation.h>
//#import <Quartz/Quartz.h>


namespace encodings
{

// don't care about ordering here
#define _(a) {#a, a}
static struct
{
    const char *name;
    int         encoding;
} g_Names [] = {
    _(ENCODING_INVALID),
    _(ENCODING_OEM437),
    _(ENCODING_OEM737),
    _(ENCODING_OEM775),
    _(ENCODING_OEM850),
    _(ENCODING_OEM851),
    _(ENCODING_OEM852),
    _(ENCODING_OEM855),
    _(ENCODING_OEM857),
    _(ENCODING_OEM860),
    _(ENCODING_OEM861),
    _(ENCODING_OEM862),
    _(ENCODING_OEM863),
    _(ENCODING_OEM864),
    _(ENCODING_OEM865),
    _(ENCODING_OEM866),
    _(ENCODING_OEM869),
    _(ENCODING_WIN1250),
    _(ENCODING_WIN1251),
    _(ENCODING_WIN1252),
    _(ENCODING_WIN1253),
    _(ENCODING_WIN1254),
    _(ENCODING_WIN1255),
    _(ENCODING_WIN1256),
    _(ENCODING_WIN1257),
    _(ENCODING_WIN1258),
    _(ENCODING_MACOS_ROMAN_WESTERN),
    _(ENCODING_ISO_8859_1),
    _(ENCODING_ISO_8859_2),
    _(ENCODING_ISO_8859_3),
    _(ENCODING_ISO_8859_4),
    _(ENCODING_ISO_8859_5),
    _(ENCODING_ISO_8859_6),
    _(ENCODING_ISO_8859_7),
    _(ENCODING_ISO_8859_8),
    _(ENCODING_ISO_8859_9),
    _(ENCODING_ISO_8859_10),
    _(ENCODING_ISO_8859_11),
    _(ENCODING_ISO_8859_13),
    _(ENCODING_ISO_8859_14),
    _(ENCODING_ISO_8859_15),
    _(ENCODING_ISO_8859_16),
    _(ENCODING_UTF8),
    _(ENCODING_UTF16LE),
    _(ENCODING_UTF16BE)
};
#undef _
    
const char *NameFromEncoding(int _encoding)
{
    for(auto i: g_Names)
        if(i.encoding == _encoding)
            return i.name;
    return "ENCODING_INVALID";
}

int EncodingFromName(const char* _name)
{
    for(auto i: g_Names)
        if(strcmp(i.name, _name) == 0)
            return i.encoding;
    return ENCODING_INVALID;
}
    
int BytesForCodeUnit(int _encoding)
{
    if(_encoding == ENCODING_INVALID)
        return 0;
    
    if(_encoding == ENCODING_UTF16BE || _encoding == ENCODING_UTF16LE )
        return 2;
    
    return 1;
}

void InterpretAsUnichar(
                            int _encoding,
                            const unsigned char* _input,
                            size_t _input_size,          // in bytes
                            unsigned short *_output_buf, // should be at least _input_size unichars long
                            uint32_t       *_indexes_buf, // should be at least _input_size 32b words long, can be NULL
                            size_t *_output_sz           // size of an _output_buf
                            )
{
    if(_encoding >= ENCODING_SINGLE_BYTES_FIRST__ && _encoding <= ENCODING_SINGLE_BYTES_LAST__)
    {
        InterpretSingleByteBufferAsUniCharPreservingBufferSize(_input,
                                                               _input_size,
                                                               _output_buf,
                                                               _encoding);
        *_output_sz = _input_size;
        if(_indexes_buf)
            for(uint32_t i = 0; i < _input_size; ++i)
                _indexes_buf[i] = i;
    }
    else if(_encoding == ENCODING_UTF8)
    {
        if(_indexes_buf)
            InterpretUTF8BufferAsIndexedUTF16(
                                                _input,
                                                _input_size,
                                                _output_buf,
                                                _indexes_buf,
                                                _output_sz,
                                                0xFFFD
                                                );
        else
            InterpretUTF8BufferAsUTF16(
                                                _input,
                                                _input_size,
                                                _output_buf,
                                                _output_sz,
                                                0xFFFD
                                                );
    }
    else if(_encoding == ENCODING_UTF16LE)
    {
        InterpretUTF16LEBufferAsUniChar(_input,
                                        _input_size,
                                        _output_buf,
                                        _output_sz,
                                        0xFFFD);
        if(_indexes_buf)
            for(uint32_t i = 0; i < *_output_sz; ++i)
                _indexes_buf[i] = i*2;
    }
    else if(_encoding == ENCODING_UTF16BE)
    {
        InterpretUTF16BEBufferAsUniChar(_input,
                                        _input_size,
                                        _output_buf,
                                        _output_sz,
                                        0xFFFD);
        if(_indexes_buf)
            for(uint32_t i = 0; i < *_output_sz; ++i)
                _indexes_buf[i] = i*2;
    }
    else
        assert(0);
}
    
bool IsValidEncoding(int _encoding)
{
    if(_encoding >= ENCODING_SINGLE_BYTES_FIRST__ && _encoding <= ENCODING_SINGLE_BYTES_LAST__)
        return true;
    if(_encoding == ENCODING_UTF8)
        return true;
    if(_encoding == ENCODING_UTF16LE)
        return true;
    if(_encoding == ENCODING_UTF16BE)
        return true;
    return false;
}
    
int ToCFStringEncoding(int _encoding)
{
    switch (_encoding) {
        case ENCODING_MACOS_ROMAN_WESTERN: return kTextEncodingMacRoman;
        case ENCODING_UTF8:                return 0x08000100; // what is UTF8 encoding in CarbonCore?
        case ENCODING_UTF16LE:             return 0x14000100; // -""- UTF16LE
        case ENCODING_UTF16BE:             return 0x10000100; // -""- UTF16BE
        case ENCODING_ISO_8859_1:          return kTextEncodingISOLatin1;
        case ENCODING_ISO_8859_2:          return kTextEncodingISOLatin2;
        case ENCODING_ISO_8859_3:          return kTextEncodingISOLatin3;
        case ENCODING_ISO_8859_4:          return kTextEncodingISOLatin4;
        case ENCODING_ISO_8859_5:          return kTextEncodingISOLatinCyrillic;
        case ENCODING_ISO_8859_6:          return kTextEncodingISOLatinArabic;
        case ENCODING_ISO_8859_7:          return kTextEncodingISOLatinGreek;
        case ENCODING_ISO_8859_8:          return kTextEncodingISOLatinHebrew;
        case ENCODING_ISO_8859_9:          return kTextEncodingISOLatin5;
        case ENCODING_ISO_8859_10:         return kTextEncodingISOLatin6;
        case ENCODING_ISO_8859_11:         return 0x0000020B; // wtf? where Thai ISO encoding has gone?
        case ENCODING_ISO_8859_13:         return kTextEncodingISOLatin7;
        case ENCODING_ISO_8859_14:         return kTextEncodingISOLatin8;
        case ENCODING_ISO_8859_15:         return kTextEncodingISOLatin9;
        case ENCODING_ISO_8859_16:         return kTextEncodingISOLatin10;
        case ENCODING_OEM437:              return kTextEncodingDOSLatinUS;
        case ENCODING_OEM737:              return kTextEncodingDOSGreek;
        case ENCODING_OEM775:              return kTextEncodingDOSBalticRim;
        case ENCODING_OEM850:              return kTextEncodingDOSLatin1;
        case ENCODING_OEM851:              return kTextEncodingDOSGreek1;
        case ENCODING_OEM852:              return kTextEncodingDOSLatin2;
        case ENCODING_OEM855:              return kTextEncodingDOSCyrillic;
        case ENCODING_OEM857:              return kTextEncodingDOSTurkish;
        case ENCODING_OEM860:              return kTextEncodingDOSPortuguese;
        case ENCODING_OEM861:              return kTextEncodingDOSIcelandic;
        case ENCODING_OEM862:              return kTextEncodingDOSHebrew;
        case ENCODING_OEM863:              return kTextEncodingDOSCanadianFrench;
        case ENCODING_OEM864:              return kTextEncodingDOSArabic;
        case ENCODING_OEM865:              return kTextEncodingDOSNordic;
        case ENCODING_OEM866:              return kTextEncodingDOSRussian;
        case ENCODING_OEM869:              return kTextEncodingDOSGreek2;
        case ENCODING_WIN1250:             return kTextEncodingWindowsLatin2;
        case ENCODING_WIN1251:             return kTextEncodingWindowsCyrillic;
        case ENCODING_WIN1252:             return kTextEncodingWindowsLatin1;
        case ENCODING_WIN1253:             return kTextEncodingWindowsGreek;
        case ENCODING_WIN1254:             return kTextEncodingWindowsLatin5;
        case ENCODING_WIN1255:             return kTextEncodingWindowsHebrew;
        case ENCODING_WIN1256:             return kTextEncodingWindowsArabic;
        case ENCODING_WIN1257:             return kTextEncodingWindowsBalticRim;
        case ENCODING_WIN1258:             return kTextEncodingWindowsVietnamese;
        default:                           return -1;
    }
}

int FromCFStringEncoding(int _encoding)
{
    switch (_encoding) {
        case kTextEncodingMacRoman:             return ENCODING_MACOS_ROMAN_WESTERN;
        case 0x08000100:                        return ENCODING_UTF8;
        case 0x14000100:                        return ENCODING_UTF16LE;
        case 0x10000100:                        return ENCODING_UTF16BE;
        case 0x00000100:                        return ENCODING_UTF16LE; // generic UTF16 - currently maps to UTF16LE
        case kTextEncodingISOLatin1:            return ENCODING_ISO_8859_1;
        case kTextEncodingISOLatin2:            return ENCODING_ISO_8859_2;
        case kTextEncodingISOLatin3:            return ENCODING_ISO_8859_3;
        case kTextEncodingISOLatin4:            return ENCODING_ISO_8859_4;
        case kTextEncodingISOLatinCyrillic:     return ENCODING_ISO_8859_5;
        case kTextEncodingISOLatinArabic:       return ENCODING_ISO_8859_6;
        case kTextEncodingISOLatinGreek:        return ENCODING_ISO_8859_7;
        case kTextEncodingISOLatinHebrew:       return ENCODING_ISO_8859_8;
        case kTextEncodingISOLatin5:            return ENCODING_ISO_8859_9;
        case kTextEncodingISOLatin6:            return ENCODING_ISO_8859_10;
        case 0x0000020B:                        return ENCODING_ISO_8859_11;
        case kTextEncodingISOLatin7:            return ENCODING_ISO_8859_13;
        case kTextEncodingISOLatin8:            return ENCODING_ISO_8859_14;
        case kTextEncodingISOLatin9:            return ENCODING_ISO_8859_15;
        case kTextEncodingISOLatin10:           return ENCODING_ISO_8859_16;
        case kTextEncodingDOSLatinUS:           return ENCODING_OEM437;
        case kTextEncodingDOSGreek:             return ENCODING_OEM737;
        case kTextEncodingDOSBalticRim:         return ENCODING_OEM775;
        case kTextEncodingDOSLatin1:            return ENCODING_OEM850;
        case kTextEncodingDOSGreek1:            return ENCODING_OEM851;
        case kTextEncodingDOSLatin2:            return ENCODING_OEM852;
        case kTextEncodingDOSCyrillic:          return ENCODING_OEM855;
        case kTextEncodingDOSTurkish:           return ENCODING_OEM857;
        case kTextEncodingDOSPortuguese:        return ENCODING_OEM860;
        case kTextEncodingDOSIcelandic:         return ENCODING_OEM861;
        case kTextEncodingDOSHebrew:            return ENCODING_OEM862;
        case kTextEncodingDOSCanadianFrench:    return ENCODING_OEM863;
        case kTextEncodingDOSArabic:            return ENCODING_OEM864;
        case kTextEncodingDOSNordic:            return ENCODING_OEM865;
        case kTextEncodingDOSRussian:           return ENCODING_OEM866;
        case kTextEncodingDOSGreek2:            return ENCODING_OEM869;
        case kTextEncodingWindowsLatin2:        return ENCODING_WIN1250;
        case kTextEncodingWindowsCyrillic:      return ENCODING_WIN1251;
        case kTextEncodingWindowsLatin1:        return ENCODING_WIN1252;
        case kTextEncodingWindowsGreek:         return ENCODING_WIN1253;
        case kTextEncodingWindowsLatin5:        return ENCODING_WIN1254;
        case kTextEncodingWindowsHebrew:        return ENCODING_WIN1255;
        case kTextEncodingWindowsArabic:        return ENCODING_WIN1256;
        case kTextEncodingWindowsBalticRim:     return ENCODING_WIN1257;
        case kTextEncodingWindowsVietnamese:    return ENCODING_WIN1258;
        default:                                return ENCODING_INVALID;
    }
}
    
const vector< pair<int, CFStringRef> >& LiteralEncodingsList()
{
    static vector< pair<int, CFStringRef> > encodings;
    static once_flag token;
    call_once(token, []{
#define _(a) encodings.emplace_back(a, (CFStringRef)CFBridgingRetain(\
    [NSString localizedNameOfStringEncoding:CFStringConvertEncodingToNSStringEncoding(ToCFStringEncoding(a))]))
        _(ENCODING_MACOS_ROMAN_WESTERN);
        _(ENCODING_UTF8);
        _(ENCODING_UTF16LE);
        _(ENCODING_UTF16BE);
        _(ENCODING_ISO_8859_1);
        _(ENCODING_ISO_8859_2);
        _(ENCODING_ISO_8859_3);
        _(ENCODING_ISO_8859_4);
        _(ENCODING_ISO_8859_5);
        _(ENCODING_ISO_8859_6);
        _(ENCODING_ISO_8859_7);
        _(ENCODING_ISO_8859_8);
        _(ENCODING_ISO_8859_9);
        _(ENCODING_ISO_8859_10);
        _(ENCODING_ISO_8859_11);
        _(ENCODING_ISO_8859_13);
        _(ENCODING_ISO_8859_14);
        _(ENCODING_ISO_8859_15);
        _(ENCODING_ISO_8859_16);
        _(ENCODING_OEM437);
        _(ENCODING_OEM737);
        _(ENCODING_OEM775);
        _(ENCODING_OEM850);
        _(ENCODING_OEM851);
        _(ENCODING_OEM852);
        _(ENCODING_OEM855);
        _(ENCODING_OEM857);
        _(ENCODING_OEM860);
        _(ENCODING_OEM861);
        _(ENCODING_OEM862);
        _(ENCODING_OEM863);
        _(ENCODING_OEM864);
        _(ENCODING_OEM865);
        _(ENCODING_OEM866);
        _(ENCODING_OEM869);
        _(ENCODING_WIN1250);
        _(ENCODING_WIN1251);
        _(ENCODING_WIN1252);
        _(ENCODING_WIN1253);
        _(ENCODING_WIN1254);
        _(ENCODING_WIN1255);
        _(ENCODING_WIN1256);
        _(ENCODING_WIN1257);
        _(ENCODING_WIN1258);
#undef _
    });
    return encodings;
}

int FromComAppleTextEncodingXAttr(const char *_xattr_value)
{
    if(_xattr_value == nullptr)
        return ENCODING_INVALID;
 
    const char *p = strchr(_xattr_value, ';');
    if(p == nullptr)
        return ENCODING_INVALID;
    
    ++p;
    if(*p == 0)
        return ENCODING_INVALID;
  
    return FromCFStringEncoding(stoi(p));
}
    
}
