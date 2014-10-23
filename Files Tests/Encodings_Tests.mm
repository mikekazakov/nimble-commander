//
//  Encodings_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 23/10/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "tests_common.h"
#import "Encodings.h"


@interface Encodings_Tests : XCTestCase

@end

@implementation Encodings_Tests


- (void)testInterpretUnicharsAsUTF8
{
    { // converting $¢€𤭢 into UTF8
        uint16_t input[5] = {0x0024, 0x00A2, 0x20AC, 0xD852, 0xDF62};
        unsigned char output[32];
        size_t output_sz;
        
        unsigned char output_should_be[32] = {0x24, 0xC2, 0xA2, 0xE2, 0x82, 0xAC, 0xF0, 0xA4, 0xAD, 0xA2, 0x0};
        size_t output_should_be_sz = strlen((char*)output_should_be);

        size_t input_eaten;
        
        InterpretUnicharsAsUTF8(input, 5, output, 32, output_sz, &input_eaten);
        XCTAssert( input_eaten == 5 );
        XCTAssert( output_sz == output_should_be_sz );
        XCTAssert( strlen((char*)output) == output_should_be_sz );
        for(int i = 0; i < output_sz; ++i)
            XCTAssert(output[i] == output_should_be[i]);
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
        
        XCTAssert(input_eaten == input_ns.length);
        XCTAssert(output_sz == strlen(input_ns_utf8));
        for(int i = 0; i < output_sz; ++i)
            XCTAssert(output[i] == (unsigned char)input_ns_utf8[i]);
    }
}

@end
