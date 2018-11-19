// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/spinlock.h>
#include <string>
#include <thread>
#include <atomic>
#import <XCTest/XCTest.h>

@interface spinlock_Tests : XCTestCase
@end

@implementation spinlock_Tests


- (void)testNonContestedPassage
{
    bool flag = false;
 
    spinlock lock;
    {
        auto guard = std::lock_guard{lock};
        flag = true;
    }
    XCTAssert( flag == true );
}

- (void)testContestedPassage
{
    std::atomic_int value = 0;
    spinlock lock;
    
    auto th1 = std::thread{ [&]{
        auto guard = std::lock_guard{lock};
        XCTAssert( value == 0 );
        std::this_thread::sleep_for( std::chrono::milliseconds{10} );    
        value = 1;
    }};
    std::this_thread::sleep_for( std::chrono::milliseconds{1} );
    auto th2 = std::thread{ [&]{
        auto guard = std::lock_guard{lock};
        XCTAssert( value == 1 );
        value = 2;
    }};
    
    th1.join();
    th2.join();
    XCTAssert( value == 2 );
}

@end
