//
//  EncodingsAdditions.c
//  Files
//
//  Created by Michael G. Kazakov on 13.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "Encodings.h"
#import <assert.h>
#import <stdio.h>

namespace encodings
{
    
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

    
    
    
}