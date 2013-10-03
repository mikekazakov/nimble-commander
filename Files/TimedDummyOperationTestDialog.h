//
//  TimedDummyOperationTestDialog.h
//  Directories
//
//  Created by Pavel Dogurevich on 30.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationDialogController.h"

@interface TimedDummyOperationTestDialog : OperationDialogController

@property int NewTime;

@property (weak) IBOutlet NSTextField *Label;
@property (weak) IBOutlet NSTextField *TimeField;

- (IBAction)OkButtonAction:(NSButton *)sender;
- (IBAction)CancelButtonAction:(NSButton *)sender;
- (IBAction)PostponeButtonAction:(NSButton *)sender;
- (IBAction)SetTimeButtonAction:(NSButton *)sender;

- (void)SetTime:(int)_optime;

@end
