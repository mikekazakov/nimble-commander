// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AnyHolder.h"

@implementation AnyHolder {
    std::any m_Object;
}

- (instancetype)initWithAny:(std::any)_any
{
    self = [super init];
    if( self ) {
        m_Object = std::move(_any);
    }
    return self;
}

- (const std::any &)any
{
    return m_Object;
}

@end
