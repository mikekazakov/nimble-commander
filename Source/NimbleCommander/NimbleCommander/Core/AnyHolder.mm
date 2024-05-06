// Copyright (C) 2017-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AnyHolder.h"

@implementation AnyHolder {
    std::any m_Object;
}

- (instancetype)initWithAny:(std::any)_any
{
    if( self = [super init] ) {
        m_Object = std::move(_any);
    }
    return self;
}

- (const std::any &)any
{
    return m_Object;
}

@end
