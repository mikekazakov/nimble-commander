// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AnyHolder.h"

@implementation AnyHolder
{
    any m_Object;
}

- (instancetype)initWithAny:(any)_any
{
    if( self = [super init] ) {
        m_Object = move(_any);
    }
    return self;
}

- (const any&) any
{
    return m_Object;
}

@end
