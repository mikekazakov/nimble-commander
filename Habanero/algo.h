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

template <typename C, typename T>
size_t linear_find_or_insert( C &_c, const T &_v )
{
    auto b = std::begin(_c), e = std::end(_c);
    auto it = std::find( b,  e, _v );
    if( it != e )
        return std::distance(b, it);
    
    _c.emplace_back( _v );
    return _c.size() - 1;
}
