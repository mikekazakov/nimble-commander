#pragma once

@interface SelectionWithMaskPopupViewController : NSViewController<NSPopoverDelegate>

- (instancetype) initForWindow:(NSWindow*)_wnd doesSelect:(bool)_select;

@property (nonatomic) function<void(NSString *mask)> handler;

@end
