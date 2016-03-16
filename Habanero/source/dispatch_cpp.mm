//
//  dispatch_cpp1.cpp
//  Habanero
//
//  Created by Michael G. Kazakov on 24/08/15.
//  Copyright (c) 2015 MIchael Kazakov. All rights reserved.
//

#include <Foundation/Foundation.h>
#include <Habanero/dispatch_cpp.h>

bool dispatch_is_main_queue() noexcept
{
    return NSThread.isMainThread;
}
