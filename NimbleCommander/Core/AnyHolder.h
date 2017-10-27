// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface AnyHolder : NSObject

- (instancetype)initWithAny:(any)_any;
@property (nonatomic, readonly) const any& any;

@end
