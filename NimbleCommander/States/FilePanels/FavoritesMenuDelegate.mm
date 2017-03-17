#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include "PanelDataPersistency.h"
#include "Favorites.h"
#include "FavoritesMenuDelegate.h"

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


@interface FavoriteLocationsMenuDelegate()

@property (strong) IBOutlet NSMenuItem *manageMenuItem;

@end

@implementation FavoriteLocationsMenuDelegate
{
    vector<FavoriteLocationsStorage::Favorite> m_Favorites;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu*)menu
{
    m_Favorites = AppDelegate.me.favoriteLocationsStorage.Favorites();
    return m_Favorites.size() + 2;
}

- (BOOL)menu:(NSMenu*)menu
  updateItem:(NSMenuItem*)item
     atIndex:(NSInteger)index
shouldCancel:(BOOL)shouldCancel
{
    if( index == m_Favorites.size() ) {
        [menu removeItemAtIndex:index];
        [menu insertItem:NSMenuItem.separatorItem atIndex:index];
    }
    else if( index == m_Favorites.size() + 1 ) {
        [menu removeItemAtIndex:index];
        [menu insertItem:[self.manageMenuItem copy] atIndex:index];
    }
    else if( index >= 0 && index < m_Favorites.size() ) {
        static const auto attributes = @{NSFontAttributeName:[NSFont menuFontOfSize:0]};
        const auto &f = m_Favorites[index];
        NSMenuItem *it = [[NSMenuItem alloc] init];
        if( !f.title.empty() ) {
            if( auto title = [NSString stringWithUTF8StdString:f.title] )
                it.title = title;
        }
        else if( auto title = [NSString stringWithUTF8StdString:f.location->verbose_path] )
            it.title = StringByTruncatingToWidth(title, 600, kTruncateAtMiddle, attributes);
        if( auto tt = [NSString stringWithUTF8StdString:f.location->verbose_path] )
            it.toolTip = tt;
    
        it.target = nil;
        it.action = @selector(OnGoToFavoriteLocation:);
        it.representedObject = [[AnyHolder alloc] initWithAny:any(f.location->hosts_stack)];
        [menu removeItemAtIndex:index];
        [menu insertItem:it atIndex:index];
    }

    return true;
}

@end

@interface FrequentlyVisitedLocationsMenuDelegate()

@property (strong) IBOutlet NSMenuItem *clearMenuItem;

@end

@implementation FrequentlyVisitedLocationsMenuDelegate
{
    vector<shared_ptr<const FavoriteLocationsStorage::Location>> m_Locations;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu*)menu
{
    m_Locations =  AppDelegate.me.favoriteLocationsStorage.FrecentlyUsed(10);
    return m_Locations.size() + 2;
}

- (BOOL)menu:(NSMenu*)menu
  updateItem:(NSMenuItem*)item
     atIndex:(NSInteger)index
shouldCancel:(BOOL)shouldCancel
{
    if( index == m_Locations.size() ) {
        [menu removeItemAtIndex:index];
        [menu insertItem:NSMenuItem.separatorItem atIndex:index];
    }
    else if( index == m_Locations.size() + 1 ) {
        [menu removeItemAtIndex:index];
        [menu insertItem:[self.clearMenuItem copy] atIndex:index];
    }
    else if( index >= 0 && index < m_Locations.size() ) {
        static const auto attributes = @{NSFontAttributeName:[NSFont menuFontOfSize:0]};
        const auto &l = m_Locations[index];
        NSMenuItem *it = [[NSMenuItem alloc] init];
        if( auto title = [NSString stringWithUTF8StdString:l->verbose_path] )
            it.title = title;
        it.target = nil;
        it.action = @selector(OnGoToFavoriteLocation:);
        it.representedObject = [[AnyHolder alloc] initWithAny:any(l->hosts_stack)];
        [menu removeItemAtIndex:index];
        [menu insertItem:it atIndex:index];
    }

    return true;
}


@end
