/* Copyright (c) 2017 Michael G. Kazakov
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
#include <Habanero/StringsBulk.h>
#import <XCTest/XCTest.h>

using namespace hbn;
using namespace std;

@interface StringsBulk_Tests : XCTestCase
@end

@implementation StringsBulk_Tests

- (void)testEmpty
{
    StringsBulk sb1;
    XCTAssert( sb1.size() == 0 );
    XCTAssert( sb1.empty() == true );
    
    StringsBulk sb2 = StringsBulkBuilder{}.Build();
    XCTAssert( sb2.size() == 0 );
    XCTAssert( sb2.empty() == true );
}

- (void)testBasic
{
    StringsBulkBuilder sbb;
    sbb.Add("Hello");
    sbb.Add(", ");
    sbb.Add("World!");
    const auto sb = sbb.Build();
    XCTAssert( sb.size() == 3 );
    
    XCTAssert( sb[0] == "Hello"s );
    XCTAssert( sb[1] == ", "s );
    XCTAssert( sb[2] == "World!"s );
}

- (void)testEmptyStrings
{
    const auto s = ""s;
    const auto n = 1000000;
    StringsBulkBuilder sbb;
    for( int i = 0; i < n; ++i )
        sbb.Add(s);
    const auto sb = sbb.Build();
    for( int i = 0; i < n; ++i )
        XCTAssert( sb[i] == s );
}

- (void)testInvalidAt
{
    StringsBulk sb;
    try {
        sb.at(1);
        XCTAssert(false);
    }
    catch(...){
    }
}

- (void)testRandomStrings
{
    const auto n = 10000;
    vector<string> v;
    for( int i = 0; i < n; ++i) {
        const auto l = rand() % 1000;
        string s(l, ' ');
        for( int j = 0; j < l; ++j)
            s[j] = (unsigned char)( j % 255 + 1 );
        v.emplace_back(s);
    }
    StringsBulkBuilder sbb;
    for( int i = 0; i < n; ++i )
        sbb.Add(v[i]);
    
    const auto sb = sbb.Build();
    for( int i = 0; i < n; ++i ) {
        XCTAssert( sb[i] == v[i] );
        XCTAssert( sb.at(i) == v[i] );
    }
    
    int index = 0;
    for( auto s: sb )
        XCTAssert( s == v[index++] );
}

- (void)testEquality
{
    StringsBulkBuilder sbb;
    sbb.Add("Hello");
    sbb.Add(", ");
    sbb.Add("World!");
    
    auto a = sbb.Build();
    auto b = sbb.Build();
    XCTAssert( a == b );
    XCTAssert( !(a != b) );
    
    sbb.Add("Da Capo");
    auto c = sbb.Build();
    XCTAssert( a != c );
    XCTAssert( !(a == c) );
    XCTAssert( b != c );
    XCTAssert( !(b == c) );
    
    b = c;
    XCTAssert( b == c );
    XCTAssert( b != a );
    
    StringsBulk d{c};
    XCTAssert( d == c );
    XCTAssert( d == b );
    XCTAssert( d != a );
    
    StringsBulk e;
    e = move(d);
    XCTAssert( e == c );
    XCTAssert( d.empty() );
}

@end
