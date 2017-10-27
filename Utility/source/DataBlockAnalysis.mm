// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <stdlib.h>
#include <memory.h>
#include "../include/Utility/DataBlockAnalysis.h"

#ifndef Endian16_Swap
#define Endian16_Swap(value) \
((((uint16_t)((value) & 0x00FF)) << 8) | \
(((uint16_t)((value) & 0xFF00)) >> 8))
#endif

static int UTF8Errors(const unsigned char *_bytes, size_t _n)
{
    int errors = 0;
    
    for(size_t i = 0, e = _n, n = 0; i < e; ++i) // check UTF-8 sequence
    {
        unsigned char b = _bytes[i];
        if(n == 0)
        {
            if((b & 0x80) == 0)
            {
                continue;
            }
            else if((b & 0xE0) == 0xC0)
            {
                n = 1;
                continue;
            }
            else if((b & 0xF0) == 0xE0)
            {
                n = 2;
                continue;
            }
            else if((b & 0xF8) == 0xF0)
            {
                n = 3;
                continue;
            }
            else
            {
                errors++;
                continue;
            }
        }
        else
        {
            if((b & 0xC0) != 0x80)
            {
                errors++;
                n = 0;
            }
            else
            {
                --n;
            }
        }
    }
    // we DO NOT check trail issues, since data window can be cut from original big data with fixed size without respect to format
    return errors;
}

static int UTF16LEErrors(const unsigned char *_bytes, size_t _n)
{
    uint16_t *cur = (uint16_t *) _bytes;
    uint16_t *end   = cur + _n / sizeof(uint16_t);
    
    int errors = 0;
    
    while(cur < end)
    {
        uint16_t val = *cur;
        
        if(val <= 0xD7FF || val >= 0xE000)
        { // BMP - ok
            cur++;
        }
        else
        { // need to check suggorate pair
            if(val >= 0xD800 && val <= 0xDBFF)
            { // leading surrogate
                if(cur + 1 < end && *(cur+1) >= 0xDC00 && *(cur+1) <= 0xDFFF)
                { // ok, normal surrogate
                    cur+=2;
                }
                else
                { // corrupted surrogate
                    cur++;
                    errors++;
                }
            }
            else
            { // trailing surrogate found - invalid situation
                cur++;
                errors++;
            }
        }
    }
    
    return errors;
}

static int UTF16BEErrors(const unsigned char *_bytes, size_t _n)
{
    uint16_t *cur = (uint16_t *) _bytes;
    uint16_t *end = cur + _n / sizeof(uint16_t);
    
    int errors = 0;
    
    while(cur < end)
    {
        uint16_t val = Endian16_Swap(*cur);
        
        if(val <= 0xD7FF || val >= 0xE000)
        { // BMP - just ok
            cur++;
        }
        else
        { // need to check suggorate pair
            if(val >= 0xD800 && val <= 0xDBFF)
            { // leading surrogate
                if(cur + 1 < end)
                {
                    uint16_t next = Endian16_Swap(*(cur+1));
                    if(next >= 0xDC00 && next <= 0xDFFF)
                    { // ok, normal surrogate
                        cur += 2;
                    }
                    else
                    { // corrupted surrogate
                        cur++;
                        errors++;
                    }
                }
                else
                { // torn surrogate - we reached the end. don't signal as an error
                    cur++;
                }
            }
            else
            { // trailing surrogate found - invalid situation
                cur++;
                errors++;
            }
        }
    }

    return errors;
}

static void SpacesForUTF16(const unsigned char *_bytes, size_t _n, int *_le_spaces, int *_be_spaces)
{
    const uint16_t *words = (const uint16_t*) _bytes;
    int le_spaces = 0;
    int be_spaces = 0;
    
    for(size_t i = 0, e = _n/2; i < e; ++i)
    {
        le_spaces += words[i] == 0x0020 ? 1 : 0;
        be_spaces += words[i] == 0x2000 ? 1 : 0;
    }
    *_le_spaces = le_spaces;
    *_be_spaces = be_spaces;
    
}

static int ByteZeros(const unsigned char *_bytes, size_t _n)
{
    int count = 0;
    
    for(size_t i = 0, e = _n; i < e; ++i)
        count += _bytes[i] == 0 ? 1 : 0; // check for null presence
    
    return count;
}

static int WordZeros(const unsigned char *_bytes, size_t _n)
{
    int count = 0;
    const uint16_t *words = (const uint16_t*) _bytes;
    
    for(size_t i = 0, e = _n/2; i < e; ++i)
        count += words[i] == 0 ? 1 : 0; // check for null presence
    
    return count;
}


// a very few checks implemented now, will be expanding later
// here we assume that _data is taken without odd dword offset (1, 2, 3 bytes offset)
// TODO: check for UTF16 BOM. nobody use it, but we should
// TODO: UTF-7 & UTF-32
int DoStaticDataBlockAnalysis(const void *_data,
                              size_t _bytes_amount,
                              StaticDataBlockAnalysis *_output
                              )
{    
    if(_bytes_amount < 4) // we need some reasonable data amount to do any prediction
    {
        memset(_output, 0, sizeof(*_output));
        _output->is_binary = true; // the most harmless way is to treat tiny files as binary ones
        return -1;
    }
    
    const unsigned char *bytes = (const unsigned char*) _data;
    
    int byte_zeros_count = ByteZeros(bytes, _bytes_amount); // zeros count in a file
    int word_zeros_count = WordZeros(bytes, _bytes_amount); // zeros count in a file
    int inv_utf8 = UTF8Errors(bytes, _bytes_amount); // invalid utf-8 sequences appearances
    int inv_utf16le = UTF16LEErrors(bytes, _bytes_amount); // invalid utf-16 le sequences appearances
    int inv_utf16be = UTF16BEErrors(bytes, _bytes_amount); // invalid utf-16 be sequences appearances
    int utf16le_spaces, utf16be_spaces;
    SpacesForUTF16(bytes, _bytes_amount, &utf16le_spaces, &utf16be_spaces);

    _output->can_be_utf8 = inv_utf8 == 0;
    _output->can_be_utf16_le = inv_utf16le == 0;
    _output->likely_utf16_le = _output->can_be_utf16_le && utf16le_spaces > utf16be_spaces * 100;
    _output->can_be_utf16_be = inv_utf16be == 0;
    _output->likely_utf16_be = _output->can_be_utf16_be && utf16be_spaces > utf16le_spaces * 100;
    
    _output->is_binary = (_output->likely_utf16_le || _output->likely_utf16_be) ?
        word_zeros_count != 0 :
        byte_zeros_count != 0 ;

    return 0;
}

bool IsValidUTF8String( const void *_data, size_t _bytes_amount )
{
    return UTF8Errors((const unsigned char*)_data, _bytes_amount) == 0;
}
