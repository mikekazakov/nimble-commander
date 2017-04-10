#pragma once

@interface AnyHolder : NSObject

- (instancetype)initWithAny:(any)_any;
@property (nonatomic, readonly) const any& any;

@end
