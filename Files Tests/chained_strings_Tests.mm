//
//  chained_strings_Tests.m
//  Files
//
//  Created by Michael G. Kazakov on 26.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <random>
#include "tests_common.h"
#include "../Files/chained_strings.h"

@interface chained_strings_Tests : XCTestCase
@end

@implementation chained_strings_Tests

- (void)testBasic
{
    chained_strings strings;
    
    XCTAssert( strings.empty() == true );
    XCTAssert( strings.size() == 0 );
    XCTAssertCPPThrows( strings.front() );
    XCTAssertCPPThrows( strings.back() );
    XCTAssertCPPThrows( strings.push_back(nullptr, 0, nullptr) );
    XCTAssertCPPThrows( strings.push_back(nullptr, nullptr) );
    XCTAssert( strings.empty() == true );
    XCTAssert( strings.singleblock() == false );
    
    string str("hello");
    strings.push_back(str, nullptr);
    XCTAssert( strings.empty() == false);
    XCTAssert( strings.size() == 1);
    XCTAssert( str == strings.front().c_str() );
    XCTAssert( str == strings.back().c_str() );
    XCTAssert( strings.singleblock() == true );
    
    for(auto i: strings)
        XCTAssert( str == i.c_str() );
    
    string long_str("this is a very long string which will presumably never fit into built-in buffer");
    strings.push_back(long_str, nullptr);
    XCTAssert( strings.empty() == false);
    XCTAssert( strings.size() == 2);
    XCTAssert( str == strings.front().c_str() );
    XCTAssert( long_str == strings.back().c_str() );
    XCTAssert( str.size() == strings.front().size() );
    XCTAssert( long_str.size() == strings.back().size() );
    
    strings.swap(chained_strings());
    XCTAssert( strings.empty() == true );
    XCTAssert( strings.size() == 0 );
}

- (void)testBlocks
{
    const int amount = 1000000;
    
    string str("hello from the underworld of mallocs and frees");
    chained_strings strings;
    
    for(int i = 0; i < amount; ++i)
        strings.push_back(str, nullptr);
    
    XCTAssert( strings.singleblock() == false );    
    XCTAssert( strings.size() == amount );
    
    unsigned total_sz = 0;
    for(auto i: strings)
        total_sz += i.size();
    
    XCTAssert( total_sz == str.size()*amount );
}

- (void)testPrefix
{
    mt19937 mt((random_device())());
    uniform_int_distribution<int> dist(0, 100000);

    chained_strings strings;
    const chained_strings::node *pref = nullptr;
    string predicted_string;
    const int amount = 100;
    for(int i = 0; i < amount; ++i) {
        string rnd = to_string(dist(mt));
        
        predicted_string += rnd;
        strings.push_back(rnd, pref);
        pref = &strings.back();
    }
    
    char buffer[10000];
    strings.back().str_with_pref(buffer);
    
    XCTAssert( predicted_string == buffer);
    XCTAssert( predicted_string == strings.back().to_str_with_pref());
}

- (void)testRegressions
{
    chained_strings strings;
    XCTAssert( begin(strings) == end(strings) );
    XCTAssert( !(begin(strings) != end(strings)) );
    
}

@end
