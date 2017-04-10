#pragma once

class FavoriteLocationsStorage;

@interface FavoriteLocationsMenuDelegate : NSObject<NSMenuDelegate>
- (instancetype) initWithStorage:(FavoriteLocationsStorage&)_storage
               andManageMenuItem:(NSMenuItem *)_item;
@end

@interface FrequentlyVisitedLocationsMenuDelegate : NSObject<NSMenuDelegate>
- (instancetype) initWithStorage:(FavoriteLocationsStorage&)_storage
               andClearMenuItem:(NSMenuItem *)_item;
@end
