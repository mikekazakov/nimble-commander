/* Copyright (c) 2018 Michael G. Kazakov
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */
#include <Habanero/LRUCache.h>
#include <string>
#import <XCTest/XCTest.h>

using namespace nc::hbn;
using namespace std;

@interface LRUCache_Tests : XCTestCase
@end

@implementation LRUCache_Tests

- (void)testEmpty
{
    LRUCache<string, string, 32> cache;
    XCTAssert( cache.size() == 0 );
    XCTAssert( cache.max_size() == 32 );
    XCTAssert( cache.empty() == true );
}

- (void)testInsertion
{
    LRUCache<string, string, 5> cache;
    cache.insert( "a", "A" );
    cache.insert( "b", "B" );
    cache.insert( "c", "C" );
    cache.insert( "d", "D" );
    cache.insert( "e", "E" );
    XCTAssert( cache.size() == 5 );
    XCTAssert( cache.count("a") == 1 );
    XCTAssert( cache.count("b") == 1 );
    XCTAssert( cache.count("c") == 1 );
    XCTAssert( cache.count("d") == 1 );
    XCTAssert( cache.count("e") == 1 );
    
    XCTAssert( cache.at("a") == "A" );
    XCTAssert( cache.at("b") == "B" );
    XCTAssert( cache.at("c") == "C" );
    XCTAssert( cache.at("d") == "D" );
    XCTAssert( cache.at("e") == "E" );
}

- (void)testBracketInsertion
{
    LRUCache<string, string, 5> cache;
    cache["a"] = "A";
    cache["b"] = "B";
    cache["c"] = "C";
    cache["d"] = "D";
    cache["e"] = "E";
    XCTAssert( cache.size() == 5 );
 
    XCTAssert( cache["a"] == "A" );
    XCTAssert( cache["b"] == "B" );
    XCTAssert( cache["c"] == "C" );
    XCTAssert( cache["d"] == "D" );
    XCTAssert( cache["e"] == "E" );
}

- (void)testEviction
{
    LRUCache<string, string, 2> cache;
    cache["a"] = "A";
    cache["b"] = "B";
    cache["c"] = "C";
    XCTAssert( cache.count("a") == 0 );
    XCTAssert( cache.count("b") == 1 );
    XCTAssert( cache.count("c") == 1 );

    (void)cache["b"];
    cache["a"] = "A";
    XCTAssert( cache.count("a") == 1 );
    XCTAssert( cache.count("b") == 1 );
    XCTAssert( cache.count("c") == 0 );
}

- (void)testCopy
{
    LRUCache<string, string, 2> cache;
    cache["a"] = "A";
    cache["b"] = "B";

    LRUCache<string, string, 2> copy(cache);
    XCTAssert( cache.size() == 2 );
    XCTAssert( copy["a"] == "A" );
    XCTAssert( copy["b"] == "B" );
    
    LRUCache<string, string, 2> copy2(move(cache));
    XCTAssert( cache.empty() == true );
    XCTAssert( copy2["a"] == "A" );
    XCTAssert( copy2["b"] == "B" );
    
    cache = copy2;
    XCTAssert( copy2.size() == 2 );
    XCTAssert( cache["a"] == "A" );
    XCTAssert( cache["b"] == "B" );
    
    copy = move(copy2);
    XCTAssert( copy2.empty() == true );
    XCTAssert( copy["a"] == "A" );
    XCTAssert( copy["b"] == "B" );    
}

- (void)testBigCache
{
    const int limit = 1'000'000;
    LRUCache<int, int, limit> cache;
    for( int i = 0; i < limit; ++i )
        cache[i] = -1;
    for( int i = limit-1; i >= 0; --i )
        XCTAssert( cache[i] == -1 );
    
    cache[limit] = -1;
    XCTAssert( cache.count(limit-1) == 0 );
}

@end
