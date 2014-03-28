//
//  ProcessSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 28.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ProcessSheetController : NSWindowController
- (IBAction)OnCancel:(id)sender;
- (void)Show;
- (void)Close;

@property (strong) IBOutlet NSProgressIndicator *Progress;
@property (nonatomic, strong) void (^OnCancelOperation)();
@property (nonatomic, readonly) bool UserCancelled;
@end
