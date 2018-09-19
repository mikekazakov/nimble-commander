//
//  variable_container_Tests.m
//  Habanero
//
//  Created by Michael G. Kazakov on 02/09/15.
//  Copyright (c) 2015 MIchael Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <string>
#import <iostream>
#import "variable_container.h"

using namespace std;

@interface variable_container_Tests : XCTestCase

@end

@implementation variable_container_Tests

- (void)test1
{
    variable_container< string > vc( variable_container<string>::type::common );
    vc.at(0) = "Abra!!!";
    XCTAssert( vc.at(0) == "Abra!!!" );
}

- (void)test2
{
    variable_container< string > vc( variable_container<string>::type::sparse );

    vc.insert(5, "abra");
    vc.insert(6, "kazam");
    XCTAssert( vc.at(5) == "abra" );
    XCTAssert( vc.at(6) == "kazam" );
    
    vc.insert(5, "abra!");
    XCTAssert( vc.at(5) == "abra!" );
    
    XCTAssert( vc.has(5) );
    XCTAssert( vc.has(6) );
    XCTAssert(!vc.has(7) );
}

- (void)test3
{
    variable_container< string > vc( variable_container<string>::type::dense );
    
    vc.insert(5, "abra");
    vc.insert(6, "kazam");
    XCTAssert( vc.at(5) == "abra" );
    XCTAssert( vc.at(6) == "kazam" );
    
    vc.insert(5, "abra!");
    XCTAssert( vc.at(5) == "abra!" );
    
    XCTAssert( vc.has(5) );
    XCTAssert( vc.has(6) );
    XCTAssert(!vc.has(7) );
    
    XCTAssert( vc.at(0) == "" );
    
    variable_container< string > vc2( vc );
    XCTAssert( vc2.at(5) == "abra!" );
    
    variable_container< string > vc3( move(vc2) );
    XCTAssert( vc3.at(6) == "kazam" );
    
}

@end
