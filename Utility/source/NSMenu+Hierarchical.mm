// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/NSMenu+Hierarchical.h>

@implementation NSMenu(Hierarchical)

- (NSMenuItem *)itemWithTagHierarchical:(NSInteger)tag
{
    if(NSMenuItem *i = [self itemWithTag:tag])
        return i;
    for(NSMenuItem *it in self.itemArray)
        if(it.hasSubmenu)
            if(NSMenuItem *i = [it.submenu itemWithTagHierarchical:tag])
                return i;
    return nil;
}

- (NSMenuItem *)itemContainingItemWithTagHierarchicalRec:(NSInteger)tag withParent:(NSMenuItem*)_menu_item
{
    if([self itemWithTag:tag] != nil)
        return _menu_item;
    
    for(NSMenuItem *it in self.itemArray)
        if(it.hasSubmenu)
            if(NSMenuItem *i = [it.submenu itemContainingItemWithTagHierarchicalRec:tag withParent:it])
                return i;
    
    return nil;
}

- (NSMenuItem *)itemContainingItemWithTagHierarchical:(NSInteger)tag
{
    return [self itemContainingItemWithTagHierarchicalRec:tag withParent:nil];
}

- (void)performActionForItemWithTagHierarchical:(NSInteger)tag
{
    if( auto it = [self itemWithTagHierarchical:tag] )
        if( auto parent = it.menu ) {
            auto ind = [parent indexOfItem:it];
            if( ind > 0 )
                [parent performActionForItemAtIndex:ind];
        }
}

@end
