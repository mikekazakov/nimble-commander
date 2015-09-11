//
//  algo.h
//  Habanero
//
//  Created by Michael G. Kazakov on 11/09/15.
//  Copyright (c) 2015 MIchael Kazakov. All rights reserved.
//

#pragma once

template <typename T>
auto linear_generator( T _base, T _step )
{
    return [=,value = _base] () mutable {
        auto v = value;
        value += _step;
        return v;
    };
}
