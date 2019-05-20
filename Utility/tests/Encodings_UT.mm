// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include "Encodings.h"

#define PREFIX "Encodings " 

TEST_CASE(PREFIX"InterpretUnicharsAsUTF8")
{
    { // converting $¢€𤭢 into UTF8
        uint16_t input[5] = {0x0024, 0x00A2, 0x20AC, 0xD852, 0xDF62};
        unsigned char output[32];
        size_t output_sz;
        
        unsigned char output_should_be[32] = {0x24, 0xC2, 0xA2, 0xE2, 0x82, 0xAC, 0xF0, 0xA4, 0xAD, 0xA2, 0x0};
        size_t output_should_be_sz = strlen((char*)output_should_be);

        size_t input_eaten;
        
        InterpretUnicharsAsUTF8(input, 5, output, 32, output_sz, &input_eaten);
        CHECK( input_eaten == 5 );
        CHECK( output_sz == output_should_be_sz );
        CHECK( strlen((char*)output) == output_should_be_sz );
        for(int i = 0; i < output_sz; ++i)
            CHECK(output[i] == output_should_be[i]);
    }
    
    { // using nsstring->utf16->utf8 == nsstring->utf comparison
        NSString *input_ns = @"☕Hello world, Привет мир🌀😁🙀北京市🟔🜽𞸵𝄑𝁺🁰";
        const char *input_ns_utf8 = input_ns.UTF8String;
        uint16_t input[64];
        [input_ns getCharacters:input range:NSMakeRange(0, input_ns.length)];
        
        unsigned char output[128];
        size_t output_sz;
        size_t input_eaten;
        InterpretUnicharsAsUTF8(input, input_ns.length, output, 128, output_sz, &input_eaten);
        
        CHECK(input_eaten == input_ns.length);
        CHECK(output_sz == strlen(input_ns_utf8));
        for(int i = 0; i < output_sz; ++i)
            CHECK(output[i] == (unsigned char)input_ns_utf8[i]);
    }
}

TEST_CASE(PREFIX"InterpretUnicodeAsUTF8")
{
    { // using nsstring->utf32->utf8 == nsstring->utf comparison
        NSString *input_ns = @"☕Hello world, Привет мир🌀😁🙀北京市🟔🜽𞸵𝄑𝁺🁰";
        const char *input_ns_utf8 = input_ns.UTF8String;
        uint32_t input[64];
        unsigned long input_sz;
        [input_ns getBytes:input
                 maxLength:sizeof(input)
                usedLength:&input_sz
                  encoding:NSUTF32LittleEndianStringEncoding
                   options:0
                     range:NSMakeRange(0, input_ns.length)
            remainingRange:nullptr];
        input_sz /= sizeof(uint32_t);
        
        unsigned char output[128];
        size_t output_sz;
        size_t input_eaten;
        InterpretUnicodeAsUTF8(input, input_sz, output, 128, output_sz, &input_eaten);
        CHECK(input_eaten == input_sz);
        CHECK(output_sz == strlen(input_ns_utf8));
        for(int i = 0; i < output_sz; ++i)
            CHECK(output[i] == (unsigned char)input_ns_utf8[i]);
    }
}
