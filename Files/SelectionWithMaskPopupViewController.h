//
//  SelectionWithMaskPopupViewController.h
//  Files
//
//  Created by Michael G. Kazakov on 23/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SelectionWithMaskPopupViewController : NSViewController<NSPopoverDelegate>
@property (strong) IBOutlet NSComboBox *comboBox;
@property (strong) IBOutlet NSTextField *titleLabel;
@property (strong) void (^handler)(NSString *mask);

- (void) setupForWindow:(NSWindow*)_window;

@end
