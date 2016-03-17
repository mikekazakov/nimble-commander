#pragma once

#include <Cocoa/Cocoa.h>

@interface NSMenu(Hierarchical)

- (NSMenuItem *)itemWithTagHierarchical:(NSInteger)tag;
- (NSMenuItem *)itemContainingItemWithTagHierarchical:(NSInteger)tag;
- (void)performActionForItemWithTagHierarchical:(NSInteger)tag;

@end
