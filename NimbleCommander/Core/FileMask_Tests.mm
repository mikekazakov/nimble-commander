// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include "FileMask.h"

@interface FileMask_Tests : XCTestCase

@end

@implementation FileMask_Tests

- (void)testBasic {
    FileMask m1("*.jpg");
    XCTAssert( m1.MatchName("1.jpg") == true );
    XCTAssert( m1.MatchName("11.jpg") == true );
    XCTAssert( m1.MatchName("1.png") == false );
    XCTAssert( m1.MatchName("1png") == false );
    XCTAssert( m1.MatchName(".jpg") == true );
    XCTAssert( m1.MatchName("русский текст.jpg") == true );
    XCTAssert( m1.MatchName("1.JPG") == true );
    XCTAssert( m1.MatchName("1.jPg") == true );
    XCTAssert( m1.MatchName("1.jpg1.jpg1.jpg1.jpg1.jpg1.jpg") == true );
    XCTAssert( m1.MatchName("1.jpg1") == false );
    XCTAssert( m1.MatchName("") == false );
    XCTAssert( m1.MatchName((char*)nullptr) == false );
    XCTAssert( m1.MatchName("1") == false );
    XCTAssert( m1.MatchName("jpg") == false );
    
    FileMask m2("*.jpg, *.png");
    XCTAssert( m2.MatchName("1.png") == true );
    XCTAssert( m2.MatchName("1.jpg") == true );
    XCTAssert( m2.MatchName("jpg.png") == true );

    FileMask m3("?.jpg");
    XCTAssert( m3.MatchName("1.png") == false );
    XCTAssert( m3.MatchName("1.jpg") == true );
    XCTAssert( m3.MatchName("11.jpg") == false );
    XCTAssert( m3.MatchName(".jpg") == false );
    XCTAssert( m3.MatchName("png.jpg") == false );

    FileMask m4("*2?.jpg");
    XCTAssert( m4.MatchName("1.png") == false );
    XCTAssert( m4.MatchName("1.jpg") == false );
    XCTAssert( m4.MatchName("2&.jpg") == true );
    XCTAssert( m4.MatchName(".jpg") == false );
    XCTAssert( m4.MatchName("png.jpg") == false );
    XCTAssert( m4.MatchName("672g97d6g237fg23f2*.jpg") == true );
    
    FileMask m5("name*");
    XCTAssert( m5.MatchName("name.png") == true );
    XCTAssert( m5.MatchName("name.") == true );
    XCTAssert( m5.MatchName("name") == true );
    XCTAssert( m5.MatchName("1.png") == false );
    XCTAssert( m5.MatchName("NAME1") == true );
    XCTAssert( m5.MatchName("namename") == true );

    FileMask m6("*abra*");
    XCTAssert( m6.MatchName("abra.png") == true );
    XCTAssert( m6.MatchName("abra.") == true );
    XCTAssert( m6.MatchName("abra") == true );
    XCTAssert( m6.MatchName("1.png") == false );
    XCTAssert( m6.MatchName("ABRA1") == true );
    XCTAssert( m6.MatchName("1ABRA1") == true );
    XCTAssert( m6.MatchName("ABRAABRAABRA") == true );

    FileMask m7("?abra?");
    XCTAssert( m7.MatchName("abra.png") == false );
    XCTAssert( m7.MatchName("abra.") == false );
    XCTAssert( m7.MatchName("abra") == false );
    XCTAssert( m7.MatchName("1.png") == false );
    XCTAssert( m7.MatchName("ABRA1") == false );
    XCTAssert( m7.MatchName("1ABRA1") == true );
    XCTAssert( m7.MatchName("ABRAABRAABRA") == false );
    
    FileMask m8("jpg");
    XCTAssert( m8.MatchName("abra.jpg") == false );
    XCTAssert( m8.MatchName(".jpg") == false );
    XCTAssert( m8.MatchName("jpg") == true );
    XCTAssert( m8.MatchName("jpg1") == false );
    XCTAssert( m8.MatchName("JPG") == true );
    
    FileMask m9("*.*");
    XCTAssert( m9.MatchName("abra.jpg") == true );
    XCTAssert( m9.MatchName(".") == true );
    XCTAssert( m9.MatchName("128736812763.137128736.987391273") == true );
    XCTAssert( m9.MatchName("13123") == false );
    
    FileMask m10(@"*.йй".UTF8String);
    XCTAssert( m10.MatchName(@"abra.йй".UTF8String) == true );
    XCTAssert( m10.MatchName(@"abra.ЙЙ".UTF8String) == true );
    XCTAssert( m10.MatchName(@"abra.йЙ".UTF8String) == true );
    XCTAssert( m10.MatchName(@"abra.Йй".UTF8String) == true );    
    
    XCTAssert( FileMask::IsWildCard("*.jpg") == true );
    XCTAssert( FileMask::IsWildCard("*") == true );
    XCTAssert( FileMask::IsWildCard("jpg") == false );
    
    XCTAssert( FileMask::ToExtensionWildCard("jpg") == "*.jpg" );
    XCTAssert( FileMask::ToExtensionWildCard("jpg,png") == "*.jpg, *.png" );
}

- (void)testWildCards {
    XCTAssert( FileMask::IsWildCard("*.jpg") == true );
    XCTAssert( FileMask::IsWildCard("*") == true );
    XCTAssert( FileMask::IsWildCard("jpg") == false );
    
    XCTAssert( FileMask::ToExtensionWildCard("jpg") == "*.jpg" );
    XCTAssert( FileMask::ToExtensionWildCard("jpg,png") == "*.jpg, *.png" );
    XCTAssert( FileMask::ToFilenameWildCard("jpg") == "*jpg*" );
    XCTAssert( FileMask::ToFilenameWildCard("jpg,png") == "*jpg*, *png*" );
}

- (void)testCases {
    FileMask m1("a");
    XCTAssert( m1.MatchName("a") == true );
    XCTAssert( m1.MatchName("A") == true );

    FileMask m2("A");
    XCTAssert( m2.MatchName("a") == true );
    XCTAssert( m2.MatchName("A") == true );

}

@end
