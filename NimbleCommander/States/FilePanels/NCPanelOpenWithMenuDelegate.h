#pragma once

@class PanelController;
class VFSListingItem;

@interface NCPanelOpenWithMenuDelegate : NSObject<NSMenuDelegate>

- (void) setContextSource:(const vector<VFSListingItem>)_items;

@property (weak, nonatomic) PanelController *target;

@property (class, readonly, nonatomic) NSString *regularMenuIdentifier;
@property (class, readonly, nonatomic) NSString *alwaysOpenWithMenuIdentifier;

@end
