//
//  EncodingsAdditions.c
//  Files
//
//  Created by Michael G. Kazakov on 13.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <stdio.h>
#import <string.h>
#import "Encodings.h"

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

namespace encodings
{
    
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

}
