// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Cocoa/Cocoa.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>

#include <Utility/Encodings.h>

namespace nc::utility {

// don't care about ordering here
#define _(a) {#a, Encoding::a}
static struct {
    const char *name;
    Encoding encoding;
} g_Names[] = {_(ENCODING_INVALID),     _(ENCODING_OEM437),      _(ENCODING_OEM737),
               _(ENCODING_OEM775),      _(ENCODING_OEM850),      _(ENCODING_OEM851),
               _(ENCODING_OEM852),      _(ENCODING_OEM855),      _(ENCODING_OEM857),
               _(ENCODING_OEM860),      _(ENCODING_OEM861),      _(ENCODING_OEM862),
               _(ENCODING_OEM863),      _(ENCODING_OEM864),      _(ENCODING_OEM865),
               _(ENCODING_OEM866),      _(ENCODING_OEM869),      _(ENCODING_WIN1250),
               _(ENCODING_WIN1251),     _(ENCODING_WIN1252),     _(ENCODING_WIN1253),
               _(ENCODING_WIN1254),     _(ENCODING_WIN1255),     _(ENCODING_WIN1256),
               _(ENCODING_WIN1257),     _(ENCODING_WIN1258),     _(ENCODING_MACOS_ROMAN_WESTERN),
               _(ENCODING_ISO_8859_1),  _(ENCODING_ISO_8859_2),  _(ENCODING_ISO_8859_3),
               _(ENCODING_ISO_8859_4),  _(ENCODING_ISO_8859_5),  _(ENCODING_ISO_8859_6),
               _(ENCODING_ISO_8859_7),  _(ENCODING_ISO_8859_8),  _(ENCODING_ISO_8859_9),
               _(ENCODING_ISO_8859_10), _(ENCODING_ISO_8859_11), _(ENCODING_ISO_8859_13),
               _(ENCODING_ISO_8859_14), _(ENCODING_ISO_8859_15), _(ENCODING_ISO_8859_16),
               _(ENCODING_UTF8),        _(ENCODING_UTF16LE),     _(ENCODING_UTF16BE)};
#undef _

const char *NameFromEncoding(Encoding _encoding)
{
    for( auto i : g_Names )
        if( i.encoding == _encoding )
            return i.name;
    return "ENCODING_INVALID";
}

Encoding EncodingFromName(const char *_name)
{
    for( auto i : g_Names )
        if( strcmp(i.name, _name) == 0 )
            return i.encoding;
    return Encoding::ENCODING_INVALID;
}

int BytesForCodeUnit(Encoding _encoding)
{
    if( _encoding == Encoding::ENCODING_INVALID )
        return 0;

    if( _encoding == Encoding::ENCODING_UTF16BE || _encoding == Encoding::ENCODING_UTF16LE )
        return 2;

    return 1;
}

void InterpretAsUnichar(Encoding _encoding,
                        const unsigned char *_input,
                        size_t _input_size,          // in bytes
                        unsigned short *_output_buf, // should be at least _input_size unichars long
                        uint32_t *_indexes_buf,      // should be at least _input_size 32b words long, can be NULL
                        size_t *_output_sz           // size of an _output_buf
)
{
    if( _encoding >= Encoding::ENCODING_SINGLE_BYTES_FIRST__ && _encoding <= Encoding::ENCODING_SINGLE_BYTES_LAST__ ) {
        InterpretSingleByteBufferAsUniCharPreservingBufferSize(_input, _input_size, _output_buf, _encoding);
        *_output_sz = _input_size;
        if( _indexes_buf )
            for( uint32_t i = 0; i < _input_size; ++i )
                _indexes_buf[i] = i;
    }
    else if( _encoding == Encoding::ENCODING_UTF8 ) {
        if( _indexes_buf )
            InterpretUTF8BufferAsIndexedUTF16(_input, _input_size, _output_buf, _indexes_buf, _output_sz, 0xFFFD);
        else
            InterpretUTF8BufferAsUTF16(_input, _input_size, _output_buf, _output_sz, 0xFFFD);
    }
    else if( _encoding == Encoding::ENCODING_UTF16LE ) {
        InterpretUTF16LEBufferAsUniChar(_input, _input_size, _output_buf, _output_sz, 0xFFFD);
        if( _indexes_buf )
            for( uint32_t i = 0; i < *_output_sz; ++i )
                _indexes_buf[i] = i * 2;
    }
    else if( _encoding == Encoding::ENCODING_UTF16BE ) {
        InterpretUTF16BEBufferAsUniChar(_input, _input_size, _output_buf, _output_sz, 0xFFFD);
        if( _indexes_buf )
            for( uint32_t i = 0; i < *_output_sz; ++i )
                _indexes_buf[i] = i * 2;
    }
    else
        assert(0);
}

bool IsValidEncoding(Encoding _encoding)
{
    if( _encoding >= Encoding::ENCODING_SINGLE_BYTES_FIRST__ && _encoding <= Encoding::ENCODING_SINGLE_BYTES_LAST__ )
        return true;
    if( _encoding == Encoding::ENCODING_UTF8 )
        return true;
    if( _encoding == Encoding::ENCODING_UTF16LE )
        return true;
    if( _encoding == Encoding::ENCODING_UTF16BE )
        return true;
    return false;
}

int ToCFStringEncoding(Encoding _encoding)
{
    switch( _encoding ) {
        case Encoding::ENCODING_MACOS_ROMAN_WESTERN:
            return kTextEncodingMacRoman;
        case Encoding::ENCODING_UTF8:
            return 0x08000100; // what is UTF8 encoding in CarbonCore?
        case Encoding::ENCODING_UTF16LE:
            return 0x14000100; // -""- UTF16LE
        case Encoding::ENCODING_UTF16BE:
            return 0x10000100; // -""- UTF16BE
        case Encoding::ENCODING_ISO_8859_1:
            return kTextEncodingISOLatin1;
        case Encoding::ENCODING_ISO_8859_2:
            return kTextEncodingISOLatin2;
        case Encoding::ENCODING_ISO_8859_3:
            return kTextEncodingISOLatin3;
        case Encoding::ENCODING_ISO_8859_4:
            return kTextEncodingISOLatin4;
        case Encoding::ENCODING_ISO_8859_5:
            return kTextEncodingISOLatinCyrillic;
        case Encoding::ENCODING_ISO_8859_6:
            return kTextEncodingISOLatinArabic;
        case Encoding::ENCODING_ISO_8859_7:
            return kTextEncodingISOLatinGreek;
        case Encoding::ENCODING_ISO_8859_8:
            return kTextEncodingISOLatinHebrew;
        case Encoding::ENCODING_ISO_8859_9:
            return kTextEncodingISOLatin5;
        case Encoding::ENCODING_ISO_8859_10:
            return kTextEncodingISOLatin6;
        case Encoding::ENCODING_ISO_8859_11:
            return 0x0000020B; // wtf? where Thai ISO encoding has gone?
        case Encoding::ENCODING_ISO_8859_13:
            return kTextEncodingISOLatin7;
        case Encoding::ENCODING_ISO_8859_14:
            return kTextEncodingISOLatin8;
        case Encoding::ENCODING_ISO_8859_15:
            return kTextEncodingISOLatin9;
        case Encoding::ENCODING_ISO_8859_16:
            return kTextEncodingISOLatin10;
        case Encoding::ENCODING_OEM437:
            return kTextEncodingDOSLatinUS;
        case Encoding::ENCODING_OEM737:
            return kTextEncodingDOSGreek;
        case Encoding::ENCODING_OEM775:
            return kTextEncodingDOSBalticRim;
        case Encoding::ENCODING_OEM850:
            return kTextEncodingDOSLatin1;
        case Encoding::ENCODING_OEM851:
            return kTextEncodingDOSGreek1;
        case Encoding::ENCODING_OEM852:
            return kTextEncodingDOSLatin2;
        case Encoding::ENCODING_OEM855:
            return kTextEncodingDOSCyrillic;
        case Encoding::ENCODING_OEM857:
            return kTextEncodingDOSTurkish;
        case Encoding::ENCODING_OEM860:
            return kTextEncodingDOSPortuguese;
        case Encoding::ENCODING_OEM861:
            return kTextEncodingDOSIcelandic;
        case Encoding::ENCODING_OEM862:
            return kTextEncodingDOSHebrew;
        case Encoding::ENCODING_OEM863:
            return kTextEncodingDOSCanadianFrench;
        case Encoding::ENCODING_OEM864:
            return kTextEncodingDOSArabic;
        case Encoding::ENCODING_OEM865:
            return kTextEncodingDOSNordic;
        case Encoding::ENCODING_OEM866:
            return kTextEncodingDOSRussian;
        case Encoding::ENCODING_OEM869:
            return kTextEncodingDOSGreek2;
        case Encoding::ENCODING_WIN1250:
            return kTextEncodingWindowsLatin2;
        case Encoding::ENCODING_WIN1251:
            return kTextEncodingWindowsCyrillic;
        case Encoding::ENCODING_WIN1252:
            return kTextEncodingWindowsLatin1;
        case Encoding::ENCODING_WIN1253:
            return kTextEncodingWindowsGreek;
        case Encoding::ENCODING_WIN1254:
            return kTextEncodingWindowsLatin5;
        case Encoding::ENCODING_WIN1255:
            return kTextEncodingWindowsHebrew;
        case Encoding::ENCODING_WIN1256:
            return kTextEncodingWindowsArabic;
        case Encoding::ENCODING_WIN1257:
            return kTextEncodingWindowsBalticRim;
        case Encoding::ENCODING_WIN1258:
            return kTextEncodingWindowsVietnamese;
        default:
            return -1;
    }
}

Encoding FromCFStringEncoding(int _encoding)
{
    switch( _encoding ) {
        case kTextEncodingMacRoman:
            return Encoding::ENCODING_MACOS_ROMAN_WESTERN;
        case 0x08000100:
            return Encoding::ENCODING_UTF8;
        case 0x14000100:
            return Encoding::ENCODING_UTF16LE;
        case 0x10000100:
            return Encoding::ENCODING_UTF16BE;
        case 0x00000100:
            return Encoding::ENCODING_UTF16LE; // generic UTF16 - currently maps to UTF16LE
        case kTextEncodingISOLatin1:
            return Encoding::ENCODING_ISO_8859_1;
        case kTextEncodingISOLatin2:
            return Encoding::ENCODING_ISO_8859_2;
        case kTextEncodingISOLatin3:
            return Encoding::ENCODING_ISO_8859_3;
        case kTextEncodingISOLatin4:
            return Encoding::ENCODING_ISO_8859_4;
        case kTextEncodingISOLatinCyrillic:
            return Encoding::ENCODING_ISO_8859_5;
        case kTextEncodingISOLatinArabic:
            return Encoding::ENCODING_ISO_8859_6;
        case kTextEncodingISOLatinGreek:
            return Encoding::ENCODING_ISO_8859_7;
        case kTextEncodingISOLatinHebrew:
            return Encoding::ENCODING_ISO_8859_8;
        case kTextEncodingISOLatin5:
            return Encoding::ENCODING_ISO_8859_9;
        case kTextEncodingISOLatin6:
            return Encoding::ENCODING_ISO_8859_10;
        case 0x0000020B:
            return Encoding::ENCODING_ISO_8859_11;
        case kTextEncodingISOLatin7:
            return Encoding::ENCODING_ISO_8859_13;
        case kTextEncodingISOLatin8:
            return Encoding::ENCODING_ISO_8859_14;
        case kTextEncodingISOLatin9:
            return Encoding::ENCODING_ISO_8859_15;
        case kTextEncodingISOLatin10:
            return Encoding::ENCODING_ISO_8859_16;
        case kTextEncodingDOSLatinUS:
            return Encoding::ENCODING_OEM437;
        case kTextEncodingDOSGreek:
            return Encoding::ENCODING_OEM737;
        case kTextEncodingDOSBalticRim:
            return Encoding::ENCODING_OEM775;
        case kTextEncodingDOSLatin1:
            return Encoding::ENCODING_OEM850;
        case kTextEncodingDOSGreek1:
            return Encoding::ENCODING_OEM851;
        case kTextEncodingDOSLatin2:
            return Encoding::ENCODING_OEM852;
        case kTextEncodingDOSCyrillic:
            return Encoding::ENCODING_OEM855;
        case kTextEncodingDOSTurkish:
            return Encoding::ENCODING_OEM857;
        case kTextEncodingDOSPortuguese:
            return Encoding::ENCODING_OEM860;
        case kTextEncodingDOSIcelandic:
            return Encoding::ENCODING_OEM861;
        case kTextEncodingDOSHebrew:
            return Encoding::ENCODING_OEM862;
        case kTextEncodingDOSCanadianFrench:
            return Encoding::ENCODING_OEM863;
        case kTextEncodingDOSArabic:
            return Encoding::ENCODING_OEM864;
        case kTextEncodingDOSNordic:
            return Encoding::ENCODING_OEM865;
        case kTextEncodingDOSRussian:
            return Encoding::ENCODING_OEM866;
        case kTextEncodingDOSGreek2:
            return Encoding::ENCODING_OEM869;
        case kTextEncodingWindowsLatin2:
            return Encoding::ENCODING_WIN1250;
        case kTextEncodingWindowsCyrillic:
            return Encoding::ENCODING_WIN1251;
        case kTextEncodingWindowsLatin1:
            return Encoding::ENCODING_WIN1252;
        case kTextEncodingWindowsGreek:
            return Encoding::ENCODING_WIN1253;
        case kTextEncodingWindowsLatin5:
            return Encoding::ENCODING_WIN1254;
        case kTextEncodingWindowsHebrew:
            return Encoding::ENCODING_WIN1255;
        case kTextEncodingWindowsArabic:
            return Encoding::ENCODING_WIN1256;
        case kTextEncodingWindowsBalticRim:
            return Encoding::ENCODING_WIN1257;
        case kTextEncodingWindowsVietnamese:
            return Encoding::ENCODING_WIN1258;
        default:
            return Encoding::ENCODING_INVALID;
    }
}

const std::vector<std::pair<Encoding, CFStringRef>> &LiteralEncodingsList()
{
    [[clang::no_destroy]] static std::vector<std::pair<Encoding, CFStringRef>> encodings;
    static std::once_flag token;
    std::call_once(token, [] {
#define _(a)                                                                                                           \
    encodings.emplace_back(Encoding::a,                                                                                \
                           static_cast<CFStringRef>(CFBridgingRetain(                                                  \
                               [NSString localizedNameOfStringEncoding:CFStringConvertEncodingToNSStringEncoding(      \
                                                                           ToCFStringEncoding(Encoding::a))])))
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

Encoding FromComAppleTextEncodingXAttr(const char *_xattr_value)
{
    if( _xattr_value == nullptr )
        return Encoding::ENCODING_INVALID;

    const char *p = strchr(_xattr_value, ';');
    if( p == nullptr )
        return Encoding::ENCODING_INVALID;

    ++p;
    if( *p == 0 )
        return Encoding::ENCODING_INVALID;

    return FromCFStringEncoding(std::stoi(p));
}

} // namespace nc::utility
