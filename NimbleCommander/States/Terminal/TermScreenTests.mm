//
//  TermScreenTests.m
//  Files
//
//  Created by Michael G. Kazakov on 05/07/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#import "TermScreen.h"

@interface TermScreenTests : XCTestCase

@end

@implementation TermScreenTests



- (void)testEraseInLine
{
    TermScreen scr(10, 1);
    scr.GoTo(0, 0);
    scr.PutString("ABCDE");
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "ABCDE     ");
    
    scr.GoTo(3, 0);
    scr.EraseInLine(0);
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "ABC       ");

    scr.GoTo(1, 0);
    scr.EraseInLine(1);
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "  C       ");

    scr.EraseInLine(2);
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "          ");
}

- (void)testEraseInLineCount
{
    TermScreen scr(10, 1);
    scr.GoTo(0, 0);
    scr.PutString("ABCDE");
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "ABCDE     ");

    scr.GoTo(2, 0);
    scr.EraseInLineCount(2);
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "AB  E     ");

    scr.GoTo(2, 0);
    scr.EraseInLineCount(1000);
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "AB        ");
    
    scr.GoTo(0, 0);
    scr.EraseInLineCount(1000);
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "          ");
}

- (void)testScrollDown
{
    TermScreen scr(10, 3);
    scr.GoTo(0, 0);
    scr.PutString("ABCDE");
    scr.GoTo(0, 1);
    scr.PutString("12345");
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "ABCDE     "
                                                 "12345     "
                                                 "          ");
    scr.ScrollDown(0, 3, 1);
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "          "
                                                 "ABCDE     "
                                                 "12345     ");
    scr.ScrollDown(0, 3, 10);
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "          "
                                                 "          "
                                                 "          ");
    
    scr.GoTo(0, 0);
    scr.PutString("ABCDE");
    scr.GoTo(0, 1);
    scr.PutString("12345");
    scr.ScrollDown(0, 3, 2);
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "          "
                                                 "          "
                                                 "ABCDE     ");
    scr.ScrollDown(0, 2, 2);
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "          "
                                                 "          "
                                                 "ABCDE     ");
    scr.ScrollDown(0, 2, 100);
    XCTAssert(scr.Buffer().DumpScreenAsANSI() == "          "
                                                 "          "
                                                 "ABCDE     ");
}



@end
