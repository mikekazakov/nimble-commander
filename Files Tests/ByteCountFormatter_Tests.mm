//
//  ByteCountFormatter_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 08/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "tests_common.h"
#import "ByteCountFormatter.h"

@interface ByteCountFormatter_Tests : XCTestCase
@end

@implementation ByteCountFormatter_Tests

- (void)testAdaptive
{
    ByteCountFormatter f(false);
    XCTAssert( [f.Adaptive_NSString(0) isEqualToString:@"0 B"] );
    XCTAssert( [f.Adaptive_NSString(5) isEqualToString:@"5 B"] );
    XCTAssert( [f.Adaptive_NSString(20) isEqualToString:@"20 B"] );
    XCTAssert( [f.Adaptive_NSString(100) isEqualToString:@"100 B"] );
    XCTAssert( [f.Adaptive_NSString(999) isEqualToString:@"999 B"] );
    XCTAssert( [f.Adaptive_NSString(1000) isEqualToString:@"1000 B"] );
    XCTAssert( [f.Adaptive_NSString(1023) isEqualToString:@"1023 B"] );
    XCTAssert( [f.Adaptive_NSString(1024) isEqualToString:@"1.0 KB"] );
    XCTAssert( [f.Adaptive_NSString(1025) isEqualToString:@"1.0 KB"] );
    XCTAssert( [f.Adaptive_NSString(1050) isEqualToString:@"1.0 KB"] );
    XCTAssert( [f.Adaptive_NSString(1051) isEqualToString:@"1.0 KB"] );
    XCTAssert( [f.Adaptive_NSString(1099) isEqualToString:@"1.1 KB"] );
    XCTAssert( [f.Adaptive_NSString(6000) isEqualToString:@"5.9 KB"] );
    XCTAssert( [f.Adaptive_NSString(5949) isEqualToString:@"5.8 KB"] );
    XCTAssert( [f.Adaptive_NSString(1024*1024) isEqualToString:@"1.0 MB"] );
    XCTAssert( [f.Adaptive_NSString(1024*1024-10) isEqualToString:@"1.0 MB"] );
    XCTAssert( [f.Adaptive_NSString(1024*1024+10) isEqualToString:@"1.0 MB"] );
    XCTAssert( [f.Adaptive_NSString(1024*1024*1.5) isEqualToString:@"1.5 MB"] );
    XCTAssert( [f.Adaptive_NSString(1024*9.9) isEqualToString:@"9.9 KB"] );
    XCTAssert( [f.Adaptive_NSString(1024*9.97) isEqualToString:@"10 KB"] );
    XCTAssert( [f.Adaptive_NSString(1024*1024*9.97) isEqualToString:@"10 MB"] );
    XCTAssert( [f.Adaptive_NSString(1024*1024*5.97) isEqualToString:@"6.0 MB"] );
    XCTAssert( [f.Adaptive_NSString(1024*1024*5.90) isEqualToString:@"5.9 MB"] );
    XCTAssert( [f.Adaptive_NSString(1024ull*1024ull*1024ull*5.5) isEqualToString:@"5.5 GB"] );
    XCTAssert( [f.Adaptive_NSString(1024ull*1024ull*1024ull*10.5) isEqualToString:@"10 GB"] );
    XCTAssert( [f.Adaptive_NSString(1024ull*1024ull*1024ull*10.6) isEqualToString:@"11 GB"] );
    XCTAssert( [f.Adaptive_NSString(1024ull*1024ull*1024ull*156.6) isEqualToString:@"157 GB"] );
    XCTAssert( [f.Adaptive_NSString(10138681344ull) isEqualToString:@"9.5 GB"] );
    XCTAssert( [f.Adaptive_NSString(1024ull*1024ull*1024ull*1024ull*2.3) isEqualToString:@"2.3 TB"] );
    XCTAssert( [f.Adaptive_NSString(1055872262ull) isEqualToString:@"1.0 GB"] );
}


@end
