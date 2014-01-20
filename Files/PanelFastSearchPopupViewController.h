//
//  PanelFastSearchPopupViewController.h
//  Files
//
//  Created by Michael G. Kazakov on 10.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PanelFastSearchPopupViewController : NSViewController

- (id) init;
- (void) PopUpWithView:(NSView*)_view; // will place itself above _view in the bottom-center
- (void) SetHandlers:(void (^)())_on_prev Next:(void (^)())_on_next;
- (void) PopOut;
@property (strong) IBOutlet NSTextField *TextField;
@property (strong) IBOutlet NSTextField *Label;
@property (strong) IBOutlet NSStepper *Stepper;

- (void) UpdateWithString:(NSString*)_string Matches:(int)_matches;
- (IBAction)OnStepper:(id)sender;

@property (strong) void (^OnAutoPopOut)();

@end
