// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include "Encodings.h"
#include <string_view>
#include <Cocoa/Cocoa.h>

#define PREFIX "Encodings "

TEST_CASE(PREFIX "InterpretUnicharsAsUTF8")
{
    { // converting $¢€𤭢 into UTF8
        uint16_t input[5] = {0x0024, 0x00A2, 0x20AC, 0xD852, 0xDF62};
        unsigned char output[32];
        size_t output_sz;

        unsigned char output_should_be[32] = {0x24, 0xC2, 0xA2, 0xE2, 0x82, 0xAC, 0xF0, 0xA4, 0xAD, 0xA2, 0x0};
        const size_t output_should_be_sz = std::strlen(reinterpret_cast<char *>(output_should_be));

        size_t input_eaten;

        nc::utility::InterpretUnicharsAsUTF8(input, 5, output, 32, output_sz, &input_eaten);
        CHECK(input_eaten == 5);
        CHECK(output_sz == output_should_be_sz);
        CHECK(std::strlen(reinterpret_cast<char *>(output)) == output_should_be_sz);
        for( size_t i = 0; i < output_sz; ++i )
            CHECK(output[i] == output_should_be[i]);
    }

    { // using nsstring->utf16->utf8 == nsstring->utf comparison
        NSString *const input_ns = @"☕Hello world, Привет мир🌀😁🙀北京市🟔🜽𞸵𝄑𝁺🁰";
        const char *input_ns_utf8 = input_ns.UTF8String;
        uint16_t input[64];
        [input_ns getCharacters:input range:NSMakeRange(0, input_ns.length)];

        unsigned char output[128];
        size_t output_sz;
        size_t input_eaten;
        nc::utility::InterpretUnicharsAsUTF8(input, input_ns.length, output, 128, output_sz, &input_eaten);

        CHECK(input_eaten == input_ns.length);
        CHECK(output_sz == strlen(input_ns_utf8));
        for( size_t i = 0; i < output_sz; ++i )
            CHECK(output[i] == static_cast<unsigned char>(input_ns_utf8[i]));
    }
}

TEST_CASE(PREFIX "InterpretUnicodeAsUTF8")
{
    { // using nsstring->utf32->utf8 == nsstring->utf comparison
        NSString *const input_ns = @"☕Hello world, Привет мир🌀😁🙀北京市🟔🜽𞸵𝄑𝁺🁰";
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
        nc::utility::InterpretUnicodeAsUTF8(input, input_sz, output, 128, output_sz, &input_eaten);
        CHECK(input_eaten == input_sz);
        CHECK(output_sz == strlen(input_ns_utf8));
        for( size_t i = 0; i < output_sz; ++i )
            CHECK(output[i] == static_cast<unsigned char>(input_ns_utf8[i]));
    }
}

TEST_CASE(PREFIX "ScanUTF8ForValidSequenceLength")
{
    struct {
        size_t operator()(const char *s) noexcept
        {
            return nc::utility::ScanUTF8ForValidSequenceLength(reinterpret_cast<const unsigned char *>(s),
                                                               std::string_view(s).size());
        };
        size_t operator()(const char8_t *s) noexcept
        {
            return nc::utility::ScanUTF8ForValidSequenceLength(reinterpret_cast<const unsigned char *>(s),
                                                               std::u8string_view(s).size());
        };
    } len;
    CHECK(len("") == 0);
    CHECK(len("A") == 1);
    CHECK(len("AB") == 2);
    CHECK(len(u8"Ф") == 2);
    CHECK(len(u8"☕") == 3);
    CHECK(len(u8"🙀") == 4);
    CHECK(len(u8"🙀a") == 5);
    CHECK(len(u8"🙀a☕") == 8);
    CHECK(len("\xd0") == 0);
    CHECK(len("\xd0z") == 0);
    CHECK(len("\xf0\x9f\x99z") == 0);
    CHECK(len("x\xf0\x9f\x99z") == 1);
}
