#include "Encodings.h"

#include <assert.h>
#include <stdlib.h>

static const unsigned short g_CP_OEM866_To_UniChar[256] = {
    /*     00     01     02     03     04     05     06     07     08     09     0A     0B     0C     0D     0E     0F          */
    /*00*/ 0x0000,0x263A,0x263B,0x2665,0x2666,0x2663,0x2660,0x2022,0x25D8,0x25CB,0x25D9,0x2642,0x2640,0x266A,0x266B,0x263C, /*00*/
    /*10*/ 0x25BA,0x25C4,0x2195,0x203C,0x00B6,0x00A7,0x25AC,0x21A8,0x2191,0x2193,0x2192,0x2190,0x221F,0x2194,0x25B2,0x25BC, /*10*/
    /*20*/ 0x0020,0x0021,0x0022,0x0023,0x0024,0x0025,0x0026,0x0027,0x0028,0x0029,0x002A,0x002B,0x002C,0x002D,0x002E,0x002F, /*20*/
    /*30*/ 0x0030,0x0031,0x0032,0x0033,0x0034,0x0035,0x0036,0x0037,0x0038,0x0039,0x003A,0x003B,0x003C,0x003D,0x003E,0x003F, /*30*/
    /*40*/ 0x0040,0x0041,0x0042,0x0043,0x0044,0x0045,0x0046,0x0047,0x0048,0x0049,0x004A,0x004B,0x004C,0x004D,0x004E,0x004F, /*40*/
    /*50*/ 0x0050,0x0051,0x0052,0x0053,0x0054,0x0055,0x0056,0x0057,0x0058,0x0059,0x005A,0x005B,0x005C,0x005D,0x005E,0x005F, /*50*/
    /*60*/ 0x0060,0x0061,0x0062,0x0063,0x0064,0x0065,0x0066,0x0067,0x0068,0x0069,0x006A,0x006B,0x006C,0x006D,0x006E,0x006F, /*60*/
    /*70*/ 0x0070,0x0071,0x0072,0x0073,0x0074,0x0075,0x0076,0x0077,0x0078,0x0079,0x007A,0x007B,0x007C,0x007D,0x007E,0x007F, /*70*/
    /*80*/ 0x0410,0x0411,0x0412,0x0413,0x0414,0x0415,0x0416,0x0417,0x0418,0x0419,0x041A,0x041B,0x041C,0x041D,0x041E,0x041F, /*80*/
    /*90*/ 0x0420,0x0421,0x0422,0x0423,0x0424,0x0425,0x0426,0x0427,0x0428,0x0429,0x042A,0x042B,0x042C,0x042D,0x042E,0x042F, /*90*/
    /*A0*/ 0x0430,0x0431,0x0432,0x0433,0x0434,0x0435,0x0436,0x0437,0x0438,0x0439,0x043A,0x043B,0x043C,0x043D,0x043E,0x043F, /*A0*/
    /*B0*/ 0x2591,0x2592,0x2593,0x2502,0x2524,0x2561,0x2562,0x2556,0x2555,0x2563,0x2551,0x2557,0x255D,0x255C,0x255B,0x2510, /*B0*/
    /*C0*/ 0x2514,0x2534,0x252C,0x251C,0x2500,0x253C,0x255E,0x255F,0x255A,0x2554,0x2569,0x2566,0x2560,0x2550,0x256C,0x2567, /*C0*/
    /*D0*/ 0x2568,0x2564,0x2565,0x2559,0x2558,0x2552,0x2553,0x256B,0x256A,0x2518,0x250C,0x2588,0x2584,0x258C,0x2590,0x2580, /*D0*/
    /*E0*/ 0x0440,0x0441,0x0442,0x0443,0x0444,0x0445,0x0446,0x0447,0x0448,0x0449,0x044A,0x044B,0x044C,0x044D,0x044E,0x044F, /*E0*/
    /*F0*/ 0x0401,0x0451,0x0404,0x0454,0x0407,0x0457,0x040E,0x045E,0x00B0,0x2219,0x00B7,0x221A,0x2116,0x00A4,0x25A0,0x00A0  /*F0*/
    /*     00     01     02     03     04     05     06     07     08     09     0A     0B     0C     0D     0E     0F          */
};

static const unsigned short g_CP_WIN1251_To_UniChar[256] = {
    /*     00     01     02     03     04     05     06     07     08     09     0A     0B     0C     0D     0E     0F          */
    /*00*/ 0x0000,0x263A,0x263B,0x2665,0x2666,0x2663,0x2660,0x2022,0x25D8,0x25CB,0x25D9,0x2642,0x2640,0x266A,0x266B,0x263C, /*00*/
    /*10*/ 0x25BA,0x25C4,0x2195,0x203C,0x00B6,0x00A7,0x25AC,0x21A8,0x2191,0x2193,0x2192,0x2190,0x221F,0x2194,0x25B2,0x25BC, /*10*/
    /*20*/ 0x0020,0x0021,0x0022,0x0023,0x0024,0x0025,0x0026,0x0027,0x0028,0x0029,0x002A,0x002B,0x002C,0x002D,0x002E,0x002F, /*20*/
    /*30*/ 0x0030,0x0031,0x0032,0x0033,0x0034,0x0035,0x0036,0x0037,0x0038,0x0039,0x003A,0x003B,0x003C,0x003D,0x003E,0x003F, /*30*/
    /*40*/ 0x0040,0x0041,0x0042,0x0043,0x0044,0x0045,0x0046,0x0047,0x0048,0x0049,0x004A,0x004B,0x004C,0x004D,0x004E,0x004F, /*40*/
    /*50*/ 0x0050,0x0051,0x0052,0x0053,0x0054,0x0055,0x0056,0x0057,0x0058,0x0059,0x005A,0x005B,0x005C,0x005D,0x005E,0x005F, /*50*/
    /*60*/ 0x0060,0x0061,0x0062,0x0063,0x0064,0x0065,0x0066,0x0067,0x0068,0x0069,0x006A,0x006B,0x006C,0x006D,0x006E,0x006F, /*60*/
    /*70*/ 0x0070,0x0071,0x0072,0x0073,0x0074,0x0075,0x0076,0x0077,0x0078,0x0079,0x007A,0x007B,0x007C,0x007D,0x007E,0x007F, /*70*/
    /*80*/ 0x0402,0x0403,0x201A,0x0453,0x201F,0x2026,0x2020,0x2021,0x20AC,0x2030,0x0409,0x2039,0x040A,0x040C,0x040B,0x040F, /*80*/
    /*90*/ 0x0452,0x2018,0x2019,0x201C,0x201D,0x2022,0x2013,0x2014,0x0000,0x2122,0x0459,0x203A,0x045A,0x045C,0x045B,0x045F, /*90*/
    /*A0*/ 0x00A0,0x040E,0x045E,0x0408,0x00A4,0x0490,0x00A6,0x00A7,0x0401,0x00A9,0x0404,0x00AB,0x00AC,0x00AD,0x00AE,0x0407, /*A0*/
    /*B0*/ 0x00B0,0x00B1,0x0406,0x0456,0x0491,0x00B5,0x00B6,0x00B7,0x0451,0x2116,0x0454,0x00BB,0x0458,0x0405,0x0455,0x0457, /*B0*/    
    /*C0*/ 0x0410,0x0411,0x0412,0x0413,0x0414,0x0415,0x0416,0x0417,0x0418,0x0419,0x041A,0x041B,0x041C,0x041D,0x041E,0x041F, /*C0*/
    /*D0*/ 0x0420,0x0421,0x0422,0x0423,0x0424,0x0425,0x0426,0x0427,0x0428,0x0429,0x042A,0x042B,0x042C,0x042D,0x042E,0x042F, /*D0*/
    /*E0*/ 0x0430,0x0431,0x0432,0x0433,0x0434,0x0435,0x0436,0x0437,0x0438,0x0439,0x043A,0x043B,0x043C,0x043D,0x043E,0x043F, /*E0*/
    /*F0*/ 0x0440,0x0441,0x0442,0x0443,0x0444,0x0445,0x0446,0x0447,0x0448,0x0449,0x044A,0x044B,0x044C,0x044D,0x044E,0x044F, /*F0*/
    /*     00     01     02     03     04     05     06     07     08     09     0A     0B     0C     0D     0E     0F          */
};

static const unsigned short g_NonPrintedSymbsVisualization[32] = {
    /*     00     01     02     03     04     05     06     07     08     09     0A     0B     0C     0D     0E     0F          */
    /*00*/ 0x0000,0x263A,0x263B,0x2665,0x2666,0x2663,0x2660,0x2022,0x25D8,0x25CB,0x25D9,0x2642,0x2640,0x266A,0x266B,0x263C, /*00*/
    /*10*/ 0x25BA,0x25C4,0x2195,0x203C,0x00B6,0x00A7,0x25AC,0x21A8,0x2191,0x2193,0x2192,0x2190,0x221F,0x2194,0x25B2,0x25BC  /*10*/
    /*     00     01     02     03     04     05     06     07     08     09     0A     0B     0C     0D     0E     0F          */
};

static const unsigned short* g_SingleBytesTable[] = {
    0,
    g_CP_OEM866_To_UniChar,
    g_CP_WIN1251_To_UniChar
};

unsigned short SingleByteIntoUniCharUsingCodepage(unsigned char _input, int _codepage)
{
    if(_codepage < ENCODING_SINGLE_BYTES_FIRST__ || _codepage > ENCODING_SINGLE_BYTES_LAST__)
    {
        assert(0);
        exit(0);
    }
    
    return (g_SingleBytesTable[_codepage])[_input];
}

void InterpretSingleByteBufferAsUniCharPreservingBufferSize(
                                                            const unsigned char* _input,
                                                            size_t _input_size,
                                                            unsigned short *_output, // should be at least _input_size 16b words long
                                                            int _codepage
                                                            )
{
    if(_codepage < ENCODING_SINGLE_BYTES_FIRST__ || _codepage > ENCODING_SINGLE_BYTES_LAST__)
    {
        assert(0);
        exit(0);
    }
    
    const unsigned char *end = _input + _input_size;
    while(_input < end)
    {
        *_output = (g_SingleBytesTable[_codepage])[*_input];
        ++_input;
        ++_output;
    }
}

void InterpretUTF8BufferAsUniCharPreservingBufferSize(
                                                const unsigned char* _input,
                                                size_t _input_size,
                                                unsigned short *_output, // should be at least _input_size 16b words long,
                                                unsigned short _stuffing_symb,
                                                unsigned short _bad_symb
                                                )
{
    const unsigned char *end = _input + _input_size;
    
    while(_input < end)
    {
        unsigned char current = *_input;

        int sz = 0;
        
        // get symbol size in bytes
        if((current & 0x80) == 0)           sz = 1; // single-byte
        else if((current & 0xE0) == 0xC0)   sz = 2; // two-byte
        else if((current & 0xF0) == 0xE0)   sz = 3; // three-byte
        else if((current & 0xF8) == 0xF0)   sz = 4; // four-byte
        else
        {
            // malformed!
            
            //skip current character and move further
            *_output = _bad_symb;
            ++_input;
            ++_output;
            continue;
        }

        // TODO: ! invalid UTF8-sequence handling !
        
        if(sz == 1)
        {
            // just out current symbol
            if (current >= 32)  *_output = current;
            else                *_output = g_NonPrintedSymbsVisualization[current];
            ++_input;
            ++_output;
            continue;
        }
            
        // try to extract a sequence

        for(int i = 1; i < sz; ++i)
        {
            // check for an unexpected end of buffer
            if(_input + i == end)
            {
                // just fill output as bad 
                for(int z = 0; z < i; ++z)
                {
                    ++_input;
                    *_output = _bad_symb;
                    ++_output;
                }
                goto goon;                
            }
            
            current = *(_input+i);
            
            // check for malformed sequence
            if( (current & 0xC0) != 0x80 )
            {
                // bad, bad sequence!
                
                //skip the heading character and move further
                *_output = _bad_symb;
                ++_input;
                ++_output;
                goto goon;
            }
            
        }
        
        // seems that sequence is ok
        if(sz == 2)
        {
            unsigned short out;
            unsigned char high = *_input;
            unsigned char low = *(_input + 1);
            out = (((unsigned short)(high & 0x1F)) << 6) | (low & 0x3F);
            
            *_output = out;
            ++_output;
            *_output = _stuffing_symb;
            ++_output;
            _input += 2;
            continue;
        }
        else if(sz == 3)
        {
            unsigned short out;
            unsigned char _1 = *_input;
            unsigned char _2 = *(_input + 1);
            unsigned char _3 = *(_input + 2);
            out = (((unsigned short)(_1 & 0xF)) << 12) | (((unsigned short)(_2 & 0x3F)) << 6) | ((unsigned short)(_3 & 0x3F));
            *_output = out;
            ++_output;
            *_output = _stuffing_symb;
            ++_output;
            *_output = _stuffing_symb;
            ++_output;
            _input += 3;
            continue;
        }
        else
        {
            // toooooo long for current implementation

            *_output = _bad_symb; // symbols that didn't fit into 16bits
            ++_output;
            ++_input;
            for(int i = 1; i < sz; ++i)
            {
                *_output = _stuffing_symb;
                ++_output;
                ++_input;
            }
            continue;
        }
        goon:;
    }
}

void InterpretUTF8BufferAsUniChar(
                                  const unsigned char* _input,
                                  size_t _input_size,
                                  unsigned short *_output_buf, // should be at least _input_size 16b words long
                                  size_t *_output_sz, // size of an output
                                  unsigned short _bad_symb // something like '?' or U+FFFD
                                  )
{
    const unsigned char *end = _input + _input_size;
    
    size_t total = 0;
    
    while(_input < end)
    {
        unsigned char current = *_input;
        
        int sz = 0;
        
        // get symbol size in bytes
        if((current & 0x80) == 0)           sz = 1; // single-byte
        else if((current & 0xE0) == 0xC0)   sz = 2; // two-byte
        else if((current & 0xF0) == 0xE0)   sz = 3; // three-byte
        else if((current & 0xF8) == 0xF0)   sz = 4; // four-byte
        else
        {
            // malformed!
            
            //skip current character and move further
            *_output_buf = _bad_symb;
            ++_input;
            ++_output_buf;
            ++total;
            continue;
        }
        
        if(sz == 1)
        {
            // just out current symbol
//            if (current >= 32)  *_output = current;
  //          else                *_output = g_NonPrintedSymbsVisualization[current];
            *_output_buf = current;
            ++_input;
            ++_output_buf;
            ++total;
            
            continue;
        }
        
        // try to extract a sequence
        
        for(int i = 1; i < sz; ++i)
        {
            // check for an unexpected end of buffer
            if(_input + i == end)
            {
                // just fill output as bad
                for(int z = 0; z < i; ++z)
                {
                    ++_input;
                    *_output_buf = _bad_symb;
                    ++_output_buf;
                    ++total;
                }
                goto goon;
            }
            
            current = *(_input+i);
            
            // check for malformed sequence
            if( (current & 0xC0) != 0x80 )
            {
                // bad, bad sequence!
                
                //skip the heading character and move further
                *_output_buf = _bad_symb;
                ++_input;
                ++_output_buf;
                ++total;
                goto goon;
            }
            
        }
        
        // seems that sequence is ok
        if(sz == 2)
        {
            unsigned short out;
            unsigned char high = *_input;
            unsigned char low = *(_input + 1);
            out = (((unsigned short)(high & 0x1F)) << 6) | (low & 0x3F);
            
            *_output_buf = out;
            ++_output_buf;
//            *_output = _stuffing_symb;
//            ++_output;
            ++total;
            _input += 2;
            continue;
        }
        else if(sz == 3)
        {
            unsigned short out;
            unsigned char _1 = *_input;
            unsigned char _2 = *(_input + 1);
            unsigned char _3 = *(_input + 2);
            out = (((unsigned short)(_1 & 0xF)) << 12) | (((unsigned short)(_2 & 0x3F)) << 6) | ((unsigned short)(_3 & 0x3F));
            *_output_buf = out;
            ++_output_buf;
            ++total;
//            *_output = _stuffing_symb;
//            ++_output;
//            *_output = _stuffing_symb;
//            ++_output;
            _input += 3;
            continue;
        }
        else
        {
            // toooooo long for current implementation
            
            *_output_buf = _bad_symb; // symbols that didn't fit into 16bits
            ++_output_buf;
            ++total;
            ++_input;
            for(int i = 1; i < sz; ++i)
            {
//                *_output = _stuffing_symb;
//                ++_output;
                ++_input;
            }
            continue;
        }
    goon:;
    }
    
    *_output_sz = total;
    *_output_buf = 0;
}


void InterpretUTF8BufferAsIndexedUniChar(
                                         const unsigned char* _input,
                                         size_t _input_size,
                                         unsigned short *_output_buf, // should be at least _input_size 16b words long
                                         uint32_t       *_indexes_buf, // should be at least _input_size 32b words long
                                         size_t *_output_sz, // size of an output
                                         unsigned short _bad_symb // something like '?' or U+FFFD
                                         )
{
    const unsigned char *end = _input + _input_size, *start = _input;
    
    size_t total = 0;
    
    while(_input < end)
    {
        unsigned char current = *_input;
        
        int sz = 0;
        
        // get symbol size in bytes
        if((current & 0x80) == 0)           sz = 1; // single-byte
        else if((current & 0xE0) == 0xC0)   sz = 2; // two-byte
        else if((current & 0xF0) == 0xE0)   sz = 3; // three-byte
        else if((current & 0xF8) == 0xF0)   sz = 4; // four-byte
        else
        {
            // malformed!
            
            //skip current character and move further
            *_output_buf = _bad_symb;
            *_indexes_buf = (uint32_t)(_input - start);
            ++_indexes_buf;
            ++_input;
            ++_output_buf;
            ++total;
            continue;
        }
        
        if(sz == 1)
        {
            // just out current symbol
            *_output_buf = current;
            *_indexes_buf = (uint32_t)(_input - start);
            ++_indexes_buf;
            ++_input;
            ++_output_buf;
            ++total;
            
            continue;
        }
        
        // try to extract a sequence
        
        for(int i = 1; i < sz; ++i)
        {
            // check for an unexpected end of buffer
            if(_input + i == end)
            {
                // just fill output as bad
                for(int z = 0; z < i; ++z)
                {
                    *_output_buf = _bad_symb;
                    *_indexes_buf = (uint32_t)(_input - start);
                    ++_indexes_buf;
                    ++_input;
                    ++_output_buf;
                    ++total;
                }
                goto goon;
            }
            
            current = *(_input+i);
            
            // check for malformed sequence
            if( (current & 0xC0) != 0x80 )
            {
                // bad, bad sequence!
                
                //skip the heading character and move further
                *_output_buf = _bad_symb;
                *_indexes_buf = (uint32_t)(_input - start);
                ++_indexes_buf;
                ++_input;
                ++_output_buf;
                ++total;
                goto goon;
            }
            
        }
        
        // seems that sequence is ok
        if(sz == 2)
        {
            unsigned short out;
            unsigned char high = *_input;
            unsigned char low = *(_input + 1);
            out = (((unsigned short)(high & 0x1F)) << 6) | (low & 0x3F);
            
            *_output_buf = out;
            *_indexes_buf = (uint32_t)(_input - start);
            ++_indexes_buf;
            ++_output_buf;
            ++total;
            _input += 2;
            continue;
        }
        else if(sz == 3)
        {
            unsigned short out;
            unsigned char _1 = *_input;
            unsigned char _2 = *(_input + 1);
            unsigned char _3 = *(_input + 2);
            out = (((unsigned short)(_1 & 0xF)) << 12) | (((unsigned short)(_2 & 0x3F)) << 6) | ((unsigned short)(_3 & 0x3F));
            *_output_buf = out;
            *_indexes_buf = (uint32_t)(_input - start);
            ++_indexes_buf;
            ++_output_buf;
            ++total;
            _input += 3;
            continue;
        }
        else
        {
            // toooooo long for current implementation
            *_output_buf = _bad_symb; // symbols that didn't fit into 16bits
            *_indexes_buf = (uint32_t)(_input - start);
            ++_indexes_buf;
            ++_output_buf;
            ++total;
            ++_input;
            for(int i = 1; i < sz; ++i)
            {
                ++_input;
            }
            continue;
        }
    goon:;
    }
    
    *_output_sz = total;
    *_output_buf = 0;
}
