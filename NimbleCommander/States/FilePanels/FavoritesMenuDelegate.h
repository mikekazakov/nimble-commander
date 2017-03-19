#pragma once

// TODO: move is somewhere
@interface AnyHolder : NSObject
- (instancetype)initWithAny:(any)_any;
@property (nonatomic, readonly) const any& any;
@end

@interface FavoriteLocationsMenuDelegate : NSObject<NSMenuDelegate>
@end

@interface FrequentlyVisitedLocationsMenuDelegate : NSObject<NSMenuDelegate>
@end
