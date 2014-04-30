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

static struct
{
    const char *name;
    int         encoding;
} g_Names [] = {
    {"ENCODING_INVALID", ENCODING_INVALID},
    {"ENCODING_OEM866", ENCODING_OEM866},
    {"ENCODING_WIN1251", ENCODING_WIN1251},
    {"ENCODING_MACOS_ROMAN_WESTERN", ENCODING_MACOS_ROMAN_WESTERN},
    {"ENCODING_ISO_8859_1", ENCODING_ISO_8859_1},
    {"ENCODING_ISO_8859_2", ENCODING_ISO_8859_2},
    {"ENCODING_ISO_8859_3", ENCODING_ISO_8859_3},
    {"ENCODING_ISO_8859_4", ENCODING_ISO_8859_4},
    {"ENCODING_ISO_8859_5", ENCODING_ISO_8859_5},
    {"ENCODING_ISO_8859_6", ENCODING_ISO_8859_6},
    {"ENCODING_ISO_8859_7", ENCODING_ISO_8859_7},
    {"ENCODING_ISO_8859_8", ENCODING_ISO_8859_8},
    {"ENCODING_ISO_8859_9", ENCODING_ISO_8859_9},
    {"ENCODING_ISO_8859_10", ENCODING_ISO_8859_10},
    {"ENCODING_ISO_8859_11", ENCODING_ISO_8859_11},
    {"ENCODING_ISO_8859_13", ENCODING_ISO_8859_13},
    {"ENCODING_ISO_8859_14", ENCODING_ISO_8859_14},
    {"ENCODING_ISO_8859_15", ENCODING_ISO_8859_15},
    {"ENCODING_ISO_8859_16", ENCODING_ISO_8859_16},
    {"ENCODING_UTF8", ENCODING_UTF8},
    {"ENCODING_UTF16LE", ENCODING_UTF16LE},
    {"ENCODING_UTF16BE", ENCODING_UTF16BE}
};

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
            InterpretUTF8BufferAsIndexedUniChar(
                                                _input,
                                                _input_size,
                                                _output_buf,
                                                _indexes_buf,
                                                _output_sz,
                                                0xFFFD
                                                );
        else
            InterpretUTF8BufferAsUniChar(
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
