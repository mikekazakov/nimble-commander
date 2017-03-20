#pragma once

class FavoriteLocationsStorage;

// TODO: move is somewhere
@interface AnyHolder : NSObject
- (instancetype)initWithAny:(any)_any;
@property (nonatomic, readonly) const any& any;
@end


@interface FavoriteLocationsMenuDelegate : NSObject<NSMenuDelegate>
- (instancetype) initWithStorage:(FavoriteLocationsStorage&)_storage
               andManageMenuItem:(NSMenuItem *)_item;
@end

@interface FrequentlyVisitedLocationsMenuDelegate : NSObject<NSMenuDelegate>
- (instancetype) initWithStorage:(FavoriteLocationsStorage&)_storage
               andClearMenuItem:(NSMenuItem *)_item;
@end
