//
//  ByteCountFormatter_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 08/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <XCTest/XCTest.h>
#include <Utility/ByteCountFormatter.h>

@interface ByteCountFormatter_Tests : XCTestCase
@end

@implementation ByteCountFormatter_Tests

- (void)testAdaptive
{
    ByteCountFormatter f(false);
    auto t = ByteCountFormatter::Adaptive6;
    XCTAssert( [f.ToNSString(0, t) isEqualToString:@"0 B"] );
    XCTAssert( [f.ToNSString(5, t) isEqualToString:@"5 B"] );
    XCTAssert( [f.ToNSString(20, t) isEqualToString:@"20 B"] );
    XCTAssert( [f.ToNSString(100, t) isEqualToString:@"100 B"] );
    XCTAssert( [f.ToNSString(999, t) isEqualToString:@"999 B"] );
    XCTAssert( [f.ToNSString(1000, t) isEqualToString:@"1000 B"] );
    XCTAssert( [f.ToNSString(1023, t) isEqualToString:@"1023 B"] );
    XCTAssert( [f.ToNSString(1024, t) isEqualToString:@"1.0 KB"] );
    XCTAssert( [f.ToNSString(1025, t) isEqualToString:@"1.0 KB"] );
    XCTAssert( [f.ToNSString(1050, t) isEqualToString:@"1.0 KB"] );
    XCTAssert( [f.ToNSString(1051, t) isEqualToString:@"1.0 KB"] );
    XCTAssert( [f.ToNSString(1099, t) isEqualToString:@"1.1 KB"] );
    XCTAssert( [f.ToNSString(6000, t) isEqualToString:@"5.9 KB"] );
    XCTAssert( [f.ToNSString(5949, t) isEqualToString:@"5.8 KB"] );
    XCTAssert( [f.ToNSString(1024*1024, t) isEqualToString:@"1.0 MB"] );
    XCTAssert( [f.ToNSString(1024*1024-10, t) isEqualToString:@"1.0 MB"] );
    XCTAssert( [f.ToNSString(1024*1024+10, t) isEqualToString:@"1.0 MB"] );
    XCTAssert( [f.ToNSString(1024*1024*1.5, t) isEqualToString:@"1.5 MB"] );
    XCTAssert( [f.ToNSString(1024*9.9, t) isEqualToString:@"9.9 KB"] );
    XCTAssert( [f.ToNSString(1024*9.97, t) isEqualToString:@"10 KB"] );
    XCTAssert( [f.ToNSString(1024*1024*9.97, t) isEqualToString:@"10 MB"] );
    XCTAssert( [f.ToNSString(1024*1024*5.97, t) isEqualToString:@"6.0 MB"] );
    XCTAssert( [f.ToNSString(1024*1024*5.90, t) isEqualToString:@"5.9 MB"] );
    XCTAssert( [f.ToNSString(1024ull*1024ull*1024ull*5.5, t) isEqualToString:@"5.5 GB"] );
    XCTAssert( [f.ToNSString(1024ull*1024ull*1024ull*10.5, t) isEqualToString:@"10 GB"] );
    XCTAssert( [f.ToNSString(1024ull*1024ull*1024ull*10.6, t) isEqualToString:@"11 GB"] );
    XCTAssert( [f.ToNSString(1024ull*1024ull*1024ull*156.6, t) isEqualToString:@"157 GB"] );
    XCTAssert( [f.ToNSString(10138681344ull, t) isEqualToString:@"9.5 GB"] );
    XCTAssert( [f.ToNSString(1024ull*1024ull*1024ull*1024ull*2.3, t) isEqualToString:@"2.3 TB"] );
    XCTAssert( [f.ToNSString(1055872262ull, t) isEqualToString:@"1.0 GB"] );
}


@end
