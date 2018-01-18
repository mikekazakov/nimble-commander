// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#import <XCTest/XCTest.h>
#include "FilenameTextNavigation.h"
@interface FilenameTextNavigation_Tests : XCTestCase
@end

@implementation FilenameTextNavigation_Tests

- (void)testForward1
{
    const auto text = @"filename.txt";
                      //0123456789012
    const auto test = [](NSString *test, unsigned long pos){
        return FilenameTextNavigation::NavigateToNextWord(test, pos);
    };
    XCTAssert( test(text, 0) == 8 );
    XCTAssert( test(text, 7) == 8 );
    XCTAssert( test(text, 8) == 12 );
    XCTAssert( test(text, 9) == 12 );
    XCTAssert( test(text, 12) == 12 );
}

- (void)testForward2
{
    const auto text = @"file-name   with.a,many_many/parts.txt";
                      //012345678901234567890123456789012345678
    const auto test = [](NSString *test, unsigned long pos){
        return FilenameTextNavigation::NavigateToNextWord(test, pos);
    };
    XCTAssert( test(text, 0) == 4 );
    XCTAssert( test(text, 4) == 9 );
    XCTAssert( test(text, 9) == 16 );
    XCTAssert( test(text, 16) == 18 );
    XCTAssert( test(text, 18) == 23 );
    XCTAssert( test(text, 23) == 28 );
    XCTAssert( test(text, 28) == 34 );
    XCTAssert( test(text, 34) == 38 );
    XCTAssert( test(text, 38) == 38 );
}

- (void)testForward3
{
    const auto text = @"________";
                      //012345678
    const auto test = [](NSString *test, unsigned long pos){
        return FilenameTextNavigation::NavigateToNextWord(test, pos);
    };
    XCTAssert( test(text, 0) == 8 );
    XCTAssert( test(text, 1) == 8 );
    XCTAssert( test(text, 7) == 8 );
    XCTAssert( test(text, 8) == 8 );
}

- (void)testForward4
{
    const auto text = @"abcdefg";
                      //01234567
    const auto test = [](NSString *test, unsigned long pos){
        return FilenameTextNavigation::NavigateToNextWord(test, pos);
    };
    XCTAssert( test(text, 0) == 7 );
    XCTAssert( test(text, 1) == 7 );
    XCTAssert( test(text, 6) == 7 );
    XCTAssert( test(text, 7) == 7 );
}

- (void)testBackward1
{
    const auto text = @"filename.txt";
                      //0123456789012
    const auto test = [](NSString *test, unsigned long pos){
        return FilenameTextNavigation::NavigateToPreviousWord(test, pos);
    };
    XCTAssert( test(text, 0) == 0 );
    XCTAssert( test(text, 7) == 0 );
    XCTAssert( test(text, 8) == 0 );
    XCTAssert( test(text, 9) == 0 );
    XCTAssert( test(text, 11) == 9 );
    XCTAssert( test(text, 12) == 9 );
}

- (void)testBackward2
{
    const auto text = @"file-name   with.a,many_many/parts.txt";
                      //012345678901234567890123456789012345678
    const auto test = [](NSString *test, unsigned long pos){
        return FilenameTextNavigation::NavigateToPreviousWord(test, pos);
    };
    XCTAssert( test(text, 0) == 0 );
    XCTAssert( test(text, 5) == 0 );
    XCTAssert( test(text, 12) == 5 );
    XCTAssert( test(text, 16) == 12 );
    XCTAssert( test(text, 17) == 12 );
    XCTAssert( test(text, 24) == 19 );
    XCTAssert( test(text, 29) == 24 );
    XCTAssert( test(text, 35) == 29 );
    XCTAssert( test(text, 38) == 35 );
}

- (void)testBackward3
{
    const auto text = @"________";
                      //012345678
    const auto test = [](NSString *test, unsigned long pos){
        return FilenameTextNavigation::NavigateToPreviousWord(test, pos);
    };
    XCTAssert( test(text, 0) == 0 );
    XCTAssert( test(text, 1) == 0 );
    XCTAssert( test(text, 7) == 0 );
    XCTAssert( test(text, 8) == 0 );
}

- (void)testBackward4
{
    const auto text = @"abcdefg";
                      //01234567
    const auto test = [](NSString *test, unsigned long pos){
        return FilenameTextNavigation::NavigateToPreviousWord(test, pos);
    };
    XCTAssert( test(text, 0) == 0 );
    XCTAssert( test(text, 1) == 0 );
    XCTAssert( test(text, 6) == 0 );
    XCTAssert( test(text, 7) == 0 );
}

- (void)testEmpty
{
    XCTAssert( FilenameTextNavigation::NavigateToNextWord(@"", 0) == 0 );
    XCTAssert( FilenameTextNavigation::NavigateToPreviousWord(@"", 0) == 0 );
}

@end
