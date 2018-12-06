// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface AnyHolder : NSObject

- (instancetype)initWithAny:(std::any)_any;
@property (nonatomic, readonly) const std::any& any;

@end
