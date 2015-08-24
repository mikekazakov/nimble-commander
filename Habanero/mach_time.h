//
//  mach_time.h
//  Habanero
//
//  Created by Michael G. Kazakov on 24/08/15.
//  Copyright (c) 2015 MIchael Kazakov. All rights reserved.
//

#pragma once

#include <chrono>

/** returns relative Mach time in nanoseconds using mach_absolute_time. */
std::chrono::nanoseconds machtime() noexcept;
