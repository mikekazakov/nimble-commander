//
//  SelectionWithMaskPopupViewController.h
//  Files
//
//  Created by Michael G. Kazakov on 23/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

@interface SelectionWithMaskPopupViewController : NSViewController<NSPopoverDelegate>

- (instancetype) initForWindow:(NSWindow*)_wnd doesSelect:(bool)_select;

@property (nonatomic) function<void(NSString *mask)> handler;

@end
