// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

#define private public

#import "ScreenBuffer.h"

using namespace nc::term;

@interface TermScreenBufferTests : XCTestCase

@end

@implementation TermScreenBufferTests

- (void)testInit
{
    {
        ScreenBuffer buffer(3,4);
        XCTAssert(buffer.Width() == 3);
        XCTAssert(buffer.Height() == 4);
        (buffer.LineFromNo(0).first)->l = 'A';
        (buffer.LineFromNo(3).second-1)->l = 'B';
        XCTAssert( buffer.DumpScreenAsANSI() == "A  "
                                                "   "
                                                "   "
                                                "  B"
                  );
        XCTAssert( buffer.LineWrapped(3) == false );
        buffer.SetLineWrapped(3, true);
        XCTAssert( buffer.LineWrapped(3) == true );
    }
    {
        ScreenBuffer buffer(0,0);
        XCTAssert(buffer.Width() == 0);
        XCTAssert(buffer.Height() == 0);
        auto l1 = buffer.LineFromNo(0);
        XCTAssert( l1.first == nullptr && l1.second == nullptr );
        auto l2 = buffer.LineFromNo(10);
        XCTAssert( l2.first == nullptr && l2.second == nullptr );
        auto l3 = buffer.LineFromNo(-1);
        XCTAssert( l3.first == nullptr && l3.second == nullptr );
    }
    {
        ScreenBuffer buffer(0,2);
        XCTAssert(buffer.Width() == 0);
        XCTAssert(buffer.Height() == 2);
        auto l1 = buffer.LineFromNo(0);
        auto l2 = buffer.LineFromNo(0);
        XCTAssert( l1.first == l1.second );
        XCTAssert( l2.first == l2.second );
        XCTAssert( l1.first == l2.first  );
    }
}

- (void)testComposeContinuousLines
{
    ScreenBuffer buffer(3,4);
    XCTAssert(buffer.Width() == 3);
    XCTAssert(buffer.Height() == 4);
    (buffer.LineFromNo(0).second-1)->l = 'A';
    (buffer.LineFromNo(2).second-1)->l = 'B';
    XCTAssert( buffer.DumpScreenAsANSI() == "  A"
                                            "   "
                                            "  B"
                                            "   "
              );
    
    auto cl1 = buffer.ComposeContinuousLines(0, 4);
    XCTAssert( cl1.size() == 4 && cl1[0].size() == 3 && cl1[0].at(2).l == 'A' );
    XCTAssert(                    cl1[2].size() == 3 && cl1[2].at(2).l == 'B' );
    
    buffer.SetLineWrapped(0, true);
    auto cl2 = buffer.ComposeContinuousLines(0, 4);
    XCTAssert( cl2.size() == 3 && cl2[0].size() == 3 && cl2[0].at(2).l == 'A');
    XCTAssert(                    cl2[1].size() == 3 && cl2[1].at(2).l == 'B' );
    
    buffer.SetLineWrapped(1, true);
    auto cl3 = buffer.ComposeContinuousLines(0, 4);
    XCTAssert( cl3.size() == 2 && cl3[0].size() == 6 && cl3[0].at(2).l == 'A' && cl3[0].at(4).l == 0 && cl3[0].at(5).l == 'B');
}




@end
